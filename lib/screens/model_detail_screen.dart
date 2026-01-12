// lib/screens/model_detail_screen.dart

// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/header.dart';
import '../providers/cart_provider.dart';
import '../styles/styles.dart';

class ModelDetailScreen extends StatefulWidget {
  final String modelId;

  const ModelDetailScreen({super.key, required this.modelId});

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  bool _isDownloading = false;
  bool _isAddingToCart = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isAdmin = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('userid', user.id)
          .single();

      setState(() {
        _isAdmin = response['role'] == 'admin';
      });
    } catch (e) {
      debugPrint('Role check error: $e');
      setState(() => _isAdmin = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchModel() async {
    try {
      final response = await Supabase.instance.client
          .from('models')
          .select()
          .eq('id', widget.modelId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching model: $e');
      return null;
    }
  }

  Future<String?> _getSignedDownloadUrl(String filePath) async {
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('3d-models')
          .createSignedUrl(filePath, 3600);
      return signedUrl;
    } catch (e) {
      debugPrint('Error generating signed URL: $e');
      return null;
    }
  }

  Future<void> _downloadModel(String filePath, String? modelName) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final signedUrl = await _getSignedDownloadUrl(filePath);
      if (signedUrl == null) throw 'Failed to generate download link';

      final fileName = modelName != null && modelName.isNotEmpty
          ? '$modelName${filePath.substring(filePath.lastIndexOf('.'))}'
          : 'model_${widget.modelId}${filePath.substring(filePath.lastIndexOf('.'))}';

      final _ = html.AnchorElement(href: signedUrl)
        ..setAttribute('download', fileName)
        ..style.display = 'none'
        ..click()
        ..remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $fileName...'),
            backgroundColor: AppTheme.hkmuGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _addToCart(String modelId) async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      cart.addToCart(modelId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart!'),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to cart: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  String getThumbnailUrl(String thumbnailPath) {
    return Supabase.instance.client.storage.from('3d-models').getPublicUrl(thumbnailPath);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final isInCart = cartProvider.isInCart(widget.modelId);

    return Scaffold(
      appBar: const Header(),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchModel(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final model = snapshot.data;

          if (model == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text('Model not found', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            );
          }

          final thumbnailUrl = getThumbnailUrl(model['thumbnail_path']);
          final filePath = model['file_path'] as String?;
          final modelName = model['name'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 128.0, 24.0, 32.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 800;

                    return isWideScreen
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    thumbnailUrl,
                                    height: 500,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 500,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image, size: 120),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                              // Right column: Info + Actions
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      modelName ?? 'Untitled Model',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.hkmuGreen,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text(model['category'] ?? 'Other'),
                                          backgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.2),
                                          labelStyle: TextStyle(color: AppTheme.hkmuGreen),
                                        ),
                                        const SizedBox(width: 12),
                                        Chip(
                                          label: Text(model['file_type'] ?? 'Unknown'),
                                          backgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.2),
                                          labelStyle: TextStyle(color: AppTheme.hkmuGreen),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    if (model['description']?.toString().isNotEmpty == true)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Description',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            model['description'],
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                          const SizedBox(height: 40),
                                        ],
                                      ),
                                    _buildActionButton(isInCart, filePath, modelName),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mobile layout
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  thumbnailUrl,
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 300,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image, size: 100),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                modelName ?? 'Untitled Model',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.hkmuGreen,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(model['category'] ?? 'Other'),
                                    backgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.2),
                                    labelStyle: TextStyle(color: AppTheme.hkmuGreen),
                                  ),
                                  const SizedBox(width: 12),
                                  Chip(
                                    label: Text(model['file_type'] ?? 'Unknown'),
                                    backgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.2),
                                    labelStyle: TextStyle(color: AppTheme.hkmuGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              if (model['description']?.toString().isNotEmpty == true)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Description',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(model['description'], style: Theme.of(context).textTheme.bodyLarge),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              _buildActionButton(isInCart, filePath, modelName),
                            ],
                          );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(bool isInCart, String? filePath, String? modelName) {
    return Center(
      child: _isAdmin
          ? ElevatedButton.icon(
              onPressed: filePath != null && !_isDownloading
                  ? () => _downloadModel(filePath, modelName)
                  : null,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isDownloading ? 'Preparing...' : 'Download Model File',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hkmuGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                disabledBackgroundColor: Colors.grey,
              ),
            )
          : ElevatedButton.icon(
              onPressed: filePath != null && !isInCart && !_isAddingToCart
                  ? () => _addToCart(widget.modelId)
                  : null,
              icon: _isAddingToCart
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isInCart ? Icons.check : Icons.add_shopping_cart,
                      color: Colors.white,
                    ),
              label: Text(
                isInCart ? 'In Cart' : (_isAddingToCart ? 'Adding...' : 'Add to Cart'),
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hkmuGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.65),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
            ),
    );
  }
}