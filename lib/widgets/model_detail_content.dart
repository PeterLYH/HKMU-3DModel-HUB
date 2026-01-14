// lib/widgets/model_detail_content.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../providers/cart_provider.dart';
import '../styles/styles.dart';

class ModelDetailContent extends StatefulWidget {
  final String modelId;

  const ModelDetailContent({
    super.key,
    required this.modelId,
  });

  @override
  State<ModelDetailContent> createState() => _ModelDetailContentState();
}

class _ModelDetailContentState extends State<ModelDetailContent> {
  Map<String, dynamic>? _model;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isAddingToCart = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _checkIfAdmin();
  }

  Future<void> _loadModel() async {
    try {
      final response = await Supabase.instance.client
          .from('models')
          .select()
          .eq('id', widget.modelId)
          .single();

      if (mounted) {
        setState(() {
          _model = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIfAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('userid', user.id)
          .maybeSingle();

      if (mounted && res != null) {
        setState(() => _isAdmin = res['role'] == 'admin');
      }
    } catch (_) {}
  }

  String getThumbnailUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return Supabase.instance.client.storage.from('3d-models').getPublicUrl(path);
  }

  Future<String?> _getSignedDownloadUrl(String filePath) async {
    try {
      return await Supabase.instance.client.storage
          .from('3d-models')
          .createSignedUrl(filePath, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadModel(String filePath, String? modelName) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final signedUrl = await _getSignedDownloadUrl(filePath);
      if (signedUrl == null) throw 'Failed to generate link';

      final ext = filePath.contains('.') ? filePath.substring(filePath.lastIndexOf('.')) : '';
      final fileName = (modelName?.trim().isNotEmpty == true)
          ? '$modelName$ext'
          : 'model_${widget.modelId}$ext';

      final anchor = html.AnchorElement(href: signedUrl)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $fileName...'),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);

    try {
      Provider.of<CartProvider>(context, listen: false).addToCart(widget.modelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = Provider.of<CartProvider>(context);
    final isInCart = cart.isInCart(widget.modelId);

    return Stack(
      children: [
        // Scrollable content
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_model == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Text('Model not found', style: TextStyle(fontSize: 18)),
                  ),
                )
              else ...[
                // Thumbnail – show FULL image without forced cropping
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: Image.network(
                      getThumbnailUrl(_model!['thumbnail_path']),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 280,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  _model!['name']?.toString() ?? 'Untitled Model',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 32),

                // description:
                if (_model!['description']?.toString().trim().isNotEmpty == true) ...[
                  const Text(
                    'description:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _model!['description'].toString().trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'category: ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _model!['category']?.toString() ?? '—',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'file_type: ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _model!['file_type']?.toString() ?? '—',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: _isAdmin
                        ? ElevatedButton.icon(
                            onPressed: _isDownloading || _model!['file_path'] == null
                                ? null
                                : () => _downloadModel(
                                      _model!['file_path'],
                                      _model!['name']?.toString(),
                                    ),
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Icon(Icons.download),
                            label: Text(_isDownloading ? 'Preparing...' : 'Download Model'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.hkmuGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: isInCart || _isAddingToCart ? null : _addToCart,
                            icon: _isAddingToCart
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Icon(isInCart ? Icons.check : Icons.add_shopping_cart),
                            label: Text(
                              isInCart ? 'In Cart' : (_isAddingToCart ? 'Adding...' : 'Add to Cart'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.hkmuGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 26),
              color: theme.colorScheme.onSurface,
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            ),
          ),
        ),
      ],
    );
  }
}