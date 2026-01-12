// lib/providers/cart_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartProvider extends ChangeNotifier {
  List<String> _cartModelIds = [];
  bool _isLoading = true;

  List<String> get cartModelIds => List.unmodifiable(_cartModelIds);
  int get itemCount => _cartModelIds.length;
  bool isInCart(String modelId) => _cartModelIds.contains(modelId);
  bool get isLoading => _isLoading;

  CartProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadCart();
    _listenToAuthChanges();
  }

  Future<void> _loadCart() async {
    _isLoading = true;
    notifyListeners();

    final user = Supabase.instance.client.auth.currentUser;

    try {
      if (user != null) {
        final response = await Supabase.instance.client
            .from('user_cart')
            .select('model_ids')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null && response['model_ids'] != null) {
          _cartModelIds = List<String>.from(response['model_ids'] as List);
        } else {
          await _loadFromLocal();
        }
      } else {
        await _loadFromLocal();
      }
    } catch (e) {
      debugPrint('Cart load error: $e');
      await _loadFromLocal();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _cartModelIds = prefs.getStringList('guest_cart') ?? [];
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('guest_cart', _cartModelIds);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('user_cart')
            .upsert({
              'user_id': user.id,
              'model_ids': _cartModelIds,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'user_id');
      } catch (e) {
        debugPrint('Supabase save failed: $e');
      }
    }
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn) {
        await _handleLoginMerge();
      } else if (event == AuthChangeEvent.signedOut) {
        _cartModelIds.clear();
        await _saveCart();
        notifyListeners();
      }
    });
  }

  Future<void> _handleLoginMerge() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final guestCart = prefs.getStringList('guest_cart') ?? [];

      if (guestCart.isNotEmpty) {
        final newItems = guestCart.where((id) => !_cartModelIds.contains(id)).toList();
        if (newItems.isNotEmpty) {
          _cartModelIds.addAll(newItems);
          await _saveCart();
        }
        await prefs.remove('guest_cart');
      }

      await _loadCart();
    } catch (e) {
      debugPrint('Login merge error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToCart(String modelId) async {
    if (modelId.isEmpty || _cartModelIds.contains(modelId)) return;
    _cartModelIds.add(modelId);
    await _saveCart();
    notifyListeners();
  }

  Future<void> removeFromCart(String modelId) async {
    if (_cartModelIds.remove(modelId)) {
      await _saveCart();
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _cartModelIds.clear();
    await _saveCart();
    notifyListeners();
  }

  Future<Map<String, dynamic>> submitDownloadRequest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Please login first'};
    }
    if (_cartModelIds.isEmpty) {
      return {'success': false, 'message': 'Cart is empty'};
    }

    _isLoading = true;
    notifyListeners();

    try {
      await Supabase.instance.client.from('download_requests').insert({
        'user_id': user.id,
        'email': user.email ?? 'unknown',
        'model_ids': _cartModelIds,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      await clearCart();

      return {'success': true, 'message': 'Request submitted successfully!'};
    } catch (e) {
      debugPrint('Request failed: $e');
      return {'success': false, 'message': 'Failed to submit request'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}