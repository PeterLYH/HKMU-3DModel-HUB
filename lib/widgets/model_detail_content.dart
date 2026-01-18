import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
// ignore: avoid_web_libraries_in_flutter
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_model == null) {
      return const Center(child: Text('Model not found', style: TextStyle(fontSize: 20)));
    }

    final model = _model!;
    final thumbnailUrl = getThumbnailUrl(model['thumbnail_path']);
    final cats = (model['categories'] as List<dynamic>?)?.cast<String>() ?? [];
    final displayCategories = cats.isEmpty ? '—' : cats.join(', ');
    final source = model['source'] as String? ?? 'Unknown';
    final license = model['license_type'] as String? ?? '—';
    final ack = model['acknowledgement'] as String? ?? '—';
    final description = model['description'] as String? ?? 'No description provided.';
    final name = model['name'] ?? 'Untitled Model';
    final fileType = model['file_type'] ?? '';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(48, 0, 48, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 900),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        thumbnailUrl,
                        height: 680,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) =>
                            loadingProgress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 680,
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.broken_image_rounded, size: 160, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, height: 1.1),
                        ),
                        const SizedBox(height: 40),
                        _buildInfoRow('Categories', displayCategories),
                        _buildInfoRow('File Type', fileType),
                        _buildInfoRow('Source', source),
                        _buildInfoRow('License / Usage', license),
                        _buildInfoRow('Acknowledgement / Credits', ack),
                        const SizedBox(height: 48),
                        const Text('Description', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 18, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            child: IconButton(
              icon: SvgPicture.asset(
                'assets/icons/close.svg',
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(Colors.lightGreen, BlendMode.srcIn),
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: 480,
              child: _isAdmin
                  ? ElevatedButton.icon(
                      onPressed: _isDownloading || model['file_path'] == null
                          ? null
                          : () => _downloadModel(model['file_path'], model['name']?.toString()),
                      icon: _isDownloading
                          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : const Icon(Icons.download, size: 28),
                      label: Text(_isDownloading ? 'Preparing Download...' : 'Download Model', style: const TextStyle(fontSize: 20)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.hkmuGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: isInCart || _isAddingToCart ? null : _addToCart,
                      icon: _isAddingToCart
                          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, size: 28),
                      label: Text(
                        isInCart ? 'Already in Cart' : (_isAddingToCart ? 'Adding...' : 'Add to Cart'),
                        style: const TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.hkmuGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}