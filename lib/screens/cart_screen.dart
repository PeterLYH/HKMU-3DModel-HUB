// lib/screens/cart_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/cart_provider.dart';
import '../styles/styles.dart';
import '../core/widgets/header.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<List<Map<String, dynamic>>>? _modelsFuture;

  @override
  void initState() {
    super.initState();
    _loadCartModels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (!cartProvider.isLoading) {
      _loadCartModels();
    }
  }

  Future<void> _loadCartModels() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.isLoading) {
      return;
    }

    if (cartProvider.cartModelIds.isEmpty) {
      setState(() => _modelsFuture = Future.value([]));
      return;
    }

    setState(() {
      _modelsFuture = Supabase.instance.client
          .from('models')
          .select('id, name, thumbnail_path, category, file_type')
          .inFilter('id', cartProvider.cartModelIds)
          .order('created_at', ascending: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const Header(),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: cartProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.hkmuGreen))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _modelsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.hkmuGreen));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Error loading cart items\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                final models = snapshot.data ?? [];

                if (models.isEmpty && !cartProvider.isLoading) {
                  return _buildEmptyCart(context, theme);
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final model = models[index];
                          return _buildModelCard(context, model, cartProvider, theme);
                        },
                      ),
                    ),
                    _buildRequestButton(context, cartProvider, theme),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 120,
              color: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 32),
            Text(
              'Your request cart is empty',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Browse and add 3D models you would like to request',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Models'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                side: const BorderSide(color: AppTheme.hkmuGreen, width: 2),
                foregroundColor: AppTheme.hkmuGreen,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(
    BuildContext context,
    Map<String, dynamic> model,
    CartProvider cartProvider,
    ThemeData theme,
  ) {
    final thumbnailPath = model['thumbnail_path'] as String?;

    final thumbnailUrl = thumbnailPath != null && thumbnailPath.isNotEmpty
        ? Supabase.instance.client.storage
            .from('3d-models')
            .getPublicUrl(thumbnailPath)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: theme.cardTheme.elevation ?? 4,
      shape: theme.cardTheme.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 90,
                height: 90,
                child: thumbnailUrl != null
                    ? Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _placeholderIcon(theme),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                      )
                    : _placeholderIcon(theme),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model['name'] ?? 'Unnamed Model',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${model['category'] ?? '—'} • ${model['file_type'] ?? '—'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Remove from cart',
              onPressed: () {
                cartProvider.removeFromCart(model['id'] as String);
                _loadCartModels();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Container(
      color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
      child: const Icon(Icons.model_training_outlined, size: 40, color: Colors.grey),
    );
  }

  Widget _buildRequestButton(
    BuildContext context,
    CartProvider cartProvider,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: cartProvider.itemCount == 0 || cartProvider.isLoading
              ? null
              : () async {
                  final confirmed = await _showConfirmDialog(context, theme);
                  if (!confirmed || !mounted) return;

                  // Capture router before any await/rebuild
                  final router = GoRouter.of(context);

                  final result = await cartProvider.submitDownloadRequest();

                  if (!mounted) return;

                  if (result['success'] == true) {
                    // Safe navigation in next frame
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        router.go('/request-success');
                      }
                    });
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] as String),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.send),
          label: const Text('Submit Download Request'),
          style: theme.elevatedButtonTheme.style?.copyWith(
            minimumSize: WidgetStateProperty.all(const Size(double.infinity, 56)),
          ),
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, ThemeData theme) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Request Download Links', style: theme.textTheme.titleLarge),
            content: Text(
              'We will prepare download links for the selected models.\n\n'
              'The links will be sent to your registered email address.',
              style: theme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Submit Request', style: TextStyle(color: AppTheme.hkmuGreen)),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ) ??
        false;
  }
}