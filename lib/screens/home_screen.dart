// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/header.dart';
import '../styles/styles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 20;
  int _currentPage = 1;
  int _totalModels = 0;
  bool _isLoading = false;

  Future<List<Map<String, dynamic>>> _fetchModels(int page) async {
    final int from = (page - 1) * _pageSize;
    final int to = from + _pageSize - 1;

    try {
      final response = await Supabase.instance.client
          .from('models')
          .select()
          .order('created_at', ascending: false)
          .range(from, to);

      // Fetch total count only on first page load
      if (page == 1 && _totalModels == 0) {
        final countResponse = await Supabase.instance.client
            .from('models')
            .count(CountOption.exact);
        _totalModels = countResponse;
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching models: $e');
      return [];
    }
  }

  Future<bool> _isCurrentUserAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('userid', user.id)
          .single();
      return response['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  String getThumbnailUrl(String thumbnailPath) {
    return Supabase.instance.client.storage
        .from('3d-models')
        .getPublicUrl(thumbnailPath);
  }

  int get _totalPages => (_totalModels / _pageSize).ceil();

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() {
      _currentPage = page;
      _isLoading = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    if (screenWidth < 1200) crossAxisCount = 3;
    if (screenWidth < 900) crossAxisCount = 2;
    if (screenWidth < 600) crossAxisCount = 1;

    return Scaffold(
      appBar: const Header(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to the 3D Model Hub',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.hkmuGreen,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse, view, and share high-quality 3D models created by the HKMU community.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Models',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_totalModels > _pageSize)
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchModels(_currentPage),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) => Card(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    );
                  }

                  final models = snapshot.data ?? [];

                  if (models.isEmpty && _currentPage == 1) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.view_in_ar_outlined, size: 100, color: Colors.grey[400]),
                          const SizedBox(height: 24),
                          Text(
                            'No models uploaded yet',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text('Be the first to upload!', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      final thumbnailUrl = getThumbnailUrl(model['thumbnail_path']);

                      return InkWell(
                        onTap: () => context.go('/model/${model['id']}'),
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Image.network(
                                  thumbnailUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null ? child : Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model['name'] ?? 'Untitled',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      model['category'] ?? 'Other',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      model['file_type'] ?? '',
                                      style: TextStyle(
                                        color: AppTheme.hkmuGreen,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Pagination
            if (_totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                      color: _currentPage > 1 ? AppTheme.hkmuGreen : Colors.grey,
                    ),
                    ...List.generate(_totalPages, (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: () => _goToPage(index + 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentPage == index + 1 ? AppTheme.hkmuGreen : Colors.grey[200],
                              foregroundColor: _currentPage == index + 1 ? Colors.white : Colors.black,
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('${index + 1}'),
                          ),
                        )),
                    IconButton(
                      onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
                      icon: const Icon(Icons.chevron_right),
                      color: _currentPage < _totalPages ? AppTheme.hkmuGreen : Colors.grey,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),

      floatingActionButton: FutureBuilder<bool>(
        future: _isCurrentUserAdmin(),
        builder: (context, snapshot) {
          if (snapshot.data != true) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => context.go('/upload'),
            backgroundColor: AppTheme.hkmuGreen,
            icon: const Icon(Icons.upload),
            label: const Text('Upload Model'),
          );
        },
      ),
    );
  }
}