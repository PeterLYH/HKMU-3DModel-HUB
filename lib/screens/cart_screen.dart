// lib/screens/cart_screen.dart

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emailjs/emailjs.dart' as emailjs;

import '../providers/cart_provider.dart';
import '../styles/styles.dart';
import '../core/widgets/header.dart';

const String confirmationServiceId = 'service_81tie0k';
const String confirmationTemplateId = 'template_alvxwce';
const String emailjsPublicKey = 'gYEQnNnjea-qVcEVe';
const String emailjsPrivateKey = 'ny3v8WRBmB9XW7UWCvXf0';

Future<bool> sendRequestConfirmationEmail({
  required String toEmail,
  required String userName,
  required List<String> modelNames,
  required String description,
}) async {
  try {
    final templateParams = {
      'user_name': userName.isNotEmpty ? userName : 'User',
      'email': toEmail,
      'model_list': modelNames.isEmpty ? '—' : '• ${modelNames.join('\n• ')}',
      'model_count': modelNames.length.toString(),
      'description': description.isNotEmpty ? description : 'No description provided',
      'request_date': DateTime.now().toString().substring(0, 16),
    };

    await emailjs.send(
      confirmationServiceId,
      confirmationTemplateId,
      templateParams,
      emailjs.Options(
        publicKey: emailjsPublicKey,
        privateKey: emailjsPrivateKey,
      ),
    );

    debugPrint('Confirmation email sent successfully to $toEmail');
    return true;
  } catch (error) {
    debugPrint('Confirmation email send failed: $error');
    if (error is emailjs.EmailJSResponseStatus) {
      debugPrint('→ Status: ${error.status}, Text: ${error.text}');
    }
    return false;
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<List<Map<String, dynamic>>>? _modelsFuture;

  final _descriptionController = TextEditingController();
  String? _descriptionError;

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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCartModels() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.isLoading) return;

    if (cartProvider.cartModelIds.isEmpty) {
      setState(() => _modelsFuture = Future.value([]));
      return;
    }

    setState(() {
      _modelsFuture = Supabase.instance.client
          .from('models')
          .select('id, name, thumbnail_path, categories, file_type')
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
                    _buildBottomSection(context, cartProvider, theme, models),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    CartProvider cartProvider,
    ThemeData theme,
    List<Map<String, dynamic>> models,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Request Reason',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Reason for requesting these models...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _descriptionError,
              filled: true,
              fillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 76,
            child: ElevatedButton.icon(
              onPressed: cartProvider.itemCount == 0 || cartProvider.isLoading
                  ? null
                  : () async {
                      setState(() => _descriptionError = null);
                      final desc = _descriptionController.text.trim();

                      if (desc.isEmpty) {
                        setState(() {
                          _descriptionError = 'Please add a short description';
                        });
                        return;
                      }

                      final confirmed = await _showConfirmDialog(context, theme);
                      if (!confirmed || !mounted) return;

                      final router = GoRouter.of(context);

                      final result = await cartProvider.submitDownloadRequest(
                        description: desc,
                      );

                      if (!mounted) return;

                      if (result['success'] == true) {
                        // Send confirmation email using loaded models
                        final user = Supabase.instance.client.auth.currentUser;
                        final userEmail = user?.email ?? '';
                        final userName = userEmail.split('@').first.trim();

                        final modelNames = models
                            .map((m) => (m['name'] as String?)?.trim() ?? 'Untitled Model')
                            .toList();

                        final emailSent = await sendRequestConfirmationEmail(
                          toEmail: userEmail,
                          userName: userName,
                          modelNames: modelNames,
                          description: desc,
                        );

                        if (!emailSent && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Request submitted, but confirmation email could not be sent',
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }

                        // Navigate to success screen
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            router.go('/request-success');
                          }
                        });

                        // Clean up
                        cartProvider.clearCart();
                        _descriptionController.clear();
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
              label: const Text(
                'Submit Request',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ],
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
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
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
                    '${model['categories'] ?? '—'} • ${model['file_type'] ?? '—'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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