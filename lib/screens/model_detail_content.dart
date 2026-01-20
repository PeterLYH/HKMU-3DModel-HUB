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
    final currentUser = Supabase.instance.client.auth.currentUser;
    final bool isLoggedIn = currentUser != null;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_model == null) {
      return const Center(child: Text('Model not found', style: TextStyle(fontSize: 20)));
    }

    final model = _model!;
    final thumbnailUrl = getThumbnailUrl(model['thumbnail_path']);
    final cats = (model['categories'] as List<dynamic>?)?.cast<String>() ?? [];
    final displayCategories = cats.isEmpty ? 'N/A' : cats.join(', ');
    final source = model['source'] as String? ?? 'N/A';
    final license = model['license_type'] as String? ?? 'N/A';
    final ack = model['acknowledgement'] as String? ?? 'N/A';
    final description = (model['description'] as String? ?? '').trim().isEmpty ? 'No description provided.' : model['description'] as String;
    final name = model['name'] ?? 'Untitled Model';
    final fileType = model['file_type'] ?? 'N/A';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final bool isWide = availableWidth > 900;

        const double referenceWidth = 1200.0;
        final double textScale = (availableWidth / referenceWidth).clamp(0.65, 1.35);

        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 48 * textScale : 24 * textScale,
                isWide ? 80 * textScale : 100 * textScale,
                isWide ? 48 * textScale : 24 * textScale,
                isWide ? 200 * textScale : 160 * textScale,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 1400 : double.infinity,
                  ),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildImageSection(thumbnailUrl, theme, textScale),
                            ),
                            SizedBox(width: 72 * textScale),
                            Expanded(
                              flex: 5,
                              child: _buildInfoSection(
                                name,
                                displayCategories,
                                fileType,
                                source,
                                license,
                                ack,
                                description,
                                theme,
                                textScale,
                                isWide,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageSection(thumbnailUrl, theme, textScale),
                            SizedBox(height: 32 * textScale),
                            _buildInfoSection(
                              name,
                              displayCategories,
                              fileType,
                              source,
                              license,
                              ack,
                              description,
                              theme,
                              textScale,
                              isWide,
                            ),
                          ],
                        ),
                ),
              ),
            ),

            Positioned(
              top: 16 * textScale,
              right: 16 * textScale,
              child: _buildCloseButton(theme, textScale),
            ),

            Positioned(
              bottom: 24 * textScale,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: isWide ? 480 * textScale : double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * textScale),
                    child: _isAdmin
                        ? _buildDownloadButton(model, theme, textScale)
                        : (isLoggedIn
                            ? _buildAddToCartButton(isInCart, theme, textScale)
                            : Padding(
                                padding: EdgeInsets.symmetric(vertical: 16 * textScale),
                                child: Text(
                                  'Please login to add this model to your cart.',
                                  style: TextStyle(
                                    fontSize: 16 * textScale,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageSection(String thumbnailUrl, ThemeData theme, double textScale) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24 * textScale),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) =>
              loadingProgress == null ? child : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade300,
            child: Center(child: Icon(Icons.broken_image_rounded, size: 100 * textScale, color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String name,
    String displayCategories,
    String fileType,
    String source,
    String license,
    String ack,
    String description,
    ThemeData theme,
    double textScale,
    bool isWide,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: isWide ? 42 * textScale : 32 * textScale,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        SizedBox(height: 32 * textScale),

        _buildInfoRow('Categories', displayCategories, textScale),
        _buildInfoRow('File Type', fileType, textScale),
        _buildInfoRow('Source', source, textScale),
        _buildInfoRow('License', license, textScale),
        _buildInfoRow('Credits', ack, textScale),

        SizedBox(height: 40 * textScale),
        Text(
          'Description',
          style: TextStyle(
            fontSize: 26 * textScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16 * textScale),
        Text(
          description,
          style: TextStyle(
            fontSize: 18 * textScale,
            height: 1.6,
          ),
        ),
        SizedBox(height: 40 * textScale),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value, double textScale) {
    final displayValue = (value == null || value.trim().isEmpty) ? 'N/A' : value.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: 20 * textScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 20 * textScale,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 20 * textScale,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(ThemeData theme, double textScale) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14 * textScale, offset: Offset(0, 5 * textScale)),
        ],
      ),
      child: IconButton(
        icon: SvgPicture.asset(
          'assets/icons/close.svg',
          width: 32 * textScale,
          height: 32 * textScale,
          colorFilter: const ColorFilter.mode(Colors.lightGreen, BlendMode.srcIn),
        ),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Close',
      ),
    );
  }

  Widget _buildDownloadButton(Map<String, dynamic> model, ThemeData theme, double textScale) {
    return ElevatedButton.icon(
      onPressed: _isDownloading || model['file_path'] == null ? null : () => _downloadModel(model['file_path'], model['name']?.toString()),
      icon: _isDownloading
          ? SizedBox(width: 28 * textScale, height: 28 * textScale, child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
          : Icon(Icons.download, size: 28 * textScale),
      label: Text(
        _isDownloading ? 'Preparing Download...' : 'Download Model',
        style: TextStyle(fontSize: 20 * textScale),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.hkmuGreen,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 20 * textScale, horizontal: 36 * textScale),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * textScale)),
        elevation: 8,
        minimumSize: Size(double.infinity, 72 * textScale),
      ),
    );
  }

  Widget _buildAddToCartButton(bool isInCart, ThemeData theme, double textScale) {
    return ElevatedButton.icon(
      onPressed: isInCart || _isAddingToCart ? null : _addToCart,
      icon: _isAddingToCart
          ? SizedBox(width: 28 * textScale, height: 28 * textScale, child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
          : Icon(isInCart ? Icons.check : Icons.add_shopping_cart, size: 28 * textScale),
      label: Text(
        isInCart ? 'Already in Cart' : (_isAddingToCart ? 'Adding...' : 'Add to Cart'),
        style: TextStyle(fontSize: 20 * textScale),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.hkmuGreen,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 20 * textScale, horizontal: 36 * textScale),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * textScale)),
        elevation: 8,
        minimumSize: Size(double.infinity, 72 * textScale),
      ),
    );
  }
}