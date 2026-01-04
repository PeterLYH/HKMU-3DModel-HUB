// lib/screens/model_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/header.dart';
import '../styles/styles.dart';

class ModelDetailScreen extends StatelessWidget {
  final String modelId;

  const ModelDetailScreen({super.key, required this.modelId});

  Future<Map<String, dynamic>?> _fetchModel() async {
    try {
      final response = await Supabase.instance.client
          .from('models')
          .select()
          .eq('id', modelId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching model: $e');
      return null;
    }
  }

  String getFileUrl(String filePath) {
    return Supabase.instance.client.storage
        .from('3d-models')
        .getPublicUrl(filePath);
  }

  String getThumbnailUrl(String thumbnailPath) {
    return Supabase.instance.client.storage
        .from('3d-models')
        .getPublicUrl(thumbnailPath);
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    'Model not found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            );
          }

          final thumbnailUrl = getThumbnailUrl(model['thumbnail_path']);
          final downloadUrl = getFileUrl(model['file_path']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        thumbnailUrl,
                        height: 400,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 400,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      model['name'] ?? 'Untitled Model',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.hkmuGreen,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Metadata Row
                    Row(
                      children: [
                        Chip(
                          label: Text(model['category'] ?? 'Other'),
                          backgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.2),
                          labelStyle: TextStyle(color: AppTheme.hkmuGreen),
                        ),
                        const SizedBox(width: 12),
                        Chip(
                          label: Text(model['file_type'] ?? ''),
                          backgroundColor: AppTheme.hkmuGreen.withValues(alpha: 0.2),
                          labelStyle: TextStyle(color: AppTheme.hkmuGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description
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
                          const SizedBox(height: 32),
                        ],
                      ),

                    // Download Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Launch URL in browser (for web)
                          // You can use url_launcher package for better handling
                          // For now, just show a snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Download link: $downloadUrl'),
                              action: SnackBarAction(
                                label: 'Copy',
                                onPressed: () {
                                  // Copy to clipboard (use clipboard package if needed)
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download Model File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.hkmuGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}