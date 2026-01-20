import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/header.dart';
import '../styles/styles.dart';
import 'model_detail_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 20;
  int _currentPage = 1;
  int _totalModels = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _models = [];

  String _searchTerm = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadPage(_currentPage);
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('models')
          .select('categories')
          .not('categories', 'is', null);

      final allCats = response
          .expand((e) => (e['categories'] as List<dynamic>?) ?? [])
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _categories = ['All', ...allCats];
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  List<String> get _displayCategories {
    if (_selectedCategory == 'All' || !_categories.contains(_selectedCategory)) {
      return List.from(_categories);
    }

    final list = List<String>.from(_categories);
    list.remove(_selectedCategory);
    return [_selectedCategory, 'All', ...list.where((c) => c != 'All' && c != _selectedCategory)];
  }

  Future<void> _loadPage(int page) async {
    if (page < 1) return;

    setState(() => _isLoading = true);

    final from = (page - 1) * _pageSize;
    final to = from + _pageSize - 1;

    try {
      var query = Supabase.instance.client.from('models').select();

      if (_searchTerm.trim().isNotEmpty) {
        query = query.ilike('name', '%${_searchTerm.trim()}%');
      }

      if (_selectedCategory != 'All') {
        query = query.contains('categories', _selectedCategory);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);

      var countQuery = Supabase.instance.client
          .from('models')
          .count(CountOption.exact);

      if (_searchTerm.trim().isNotEmpty) {
        countQuery = countQuery.ilike('name', '%${_searchTerm.trim()}%');
      }

      if (_selectedCategory != 'All') {
        countQuery = countQuery.contains('categories', _selectedCategory);
      }

      final count = await countQuery;

      setState(() {
        _models = List<Map<String, dynamic>>.from(response);
        _totalModels = count;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching models: $e');
      setState(() => _isLoading = false);
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
          .maybeSingle();

      return response != null && response['role'] == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  String getThumbnailUrl(String? thumbnailPath) {
    if (thumbnailPath == null || thumbnailPath.isEmpty) return '';
    return Supabase.instance.client.storage
        .from('3d-models')
        .getPublicUrl(thumbnailPath);
  }

  int get _totalPages => (_totalModels / _pageSize).ceil();

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    _loadPage(page);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchTerm = value;
      _currentPage = 1;
    });
    _loadPage(1);
  }

  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value ?? 'All';
      _currentPage = 1;
    });
    _loadPage(1);
  }

  void showModelDetailDialog(BuildContext context, String modelId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bool isSmallScreen = screenWidth < 700;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          insetPadding: isSmallScreen
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 32)  // margin on mobile
              : EdgeInsets.symmetric(
                  horizontal: screenWidth > 1200 ? 120 : 32,
                  vertical: 24,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          ),
          child: ConstrainedBox(
            constraints: isSmallScreen
                ? BoxConstraints(
                    maxWidth: screenWidth - 32,
                    maxHeight: screenHeight - 64,
                  )
                : const BoxConstraints(
                    maxWidth: 1400,
                    maxHeight: 900,
                  ),
            child: ModelDetailContent(modelId: modelId),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    int crossAxisCount = 4;
    if (screenWidth < 1200) crossAxisCount = 3;
    if (screenWidth < 900) crossAxisCount = 2;
    if (screenWidth < 600) crossAxisCount = 1;

    return Scaffold(
      appBar: const Header(),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to the 3D Model Hub',
              style: (isMobile
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.hkmuGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse, view, and share high-quality 3D models created by the HKMU community.',
              style: (isMobile
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isMobile ? 24 : 40),

            // Search + Filter - stacked on mobile
            isMobile
                ? Column(
                    children: [
                      _buildSearchField(theme, isDark),
                      const SizedBox(height: 16),
                      _buildCategoryDropdown(theme, isDark),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildSearchField(theme, isDark)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 240,
                        child: _buildCategoryDropdown(theme, isDark),
                      ),
                    ],
                  ),
            SizedBox(height: isMobile ? 20 : 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Models',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_totalModels > _pageSize && !_isLoading)
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _buildModelGrid(crossAxisCount),
            ),

            if (_totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _currentPage > 1 && !_isLoading
                          ? () => _goToPage(_currentPage - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      color: _currentPage > 1
                          ? AppTheme.hkmuGreen
                          : theme.colorScheme.onSurfaceVariant,
                      iconSize: isMobile ? 28 : 32,
                    ),
                    ...List.generate(
                      _totalPages,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: !_isLoading
                              ? () => _goToPage(index + 1)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage == (index + 1)
                                ? AppTheme.hkmuGreen
                                : theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: _currentPage == (index + 1)
                                ? Colors.black
                                : theme.colorScheme.onSurface,
                            minimumSize: Size(isMobile ? 36 : 40, isMobile ? 36 : 40),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _currentPage < _totalPages && !_isLoading
                          ? () => _goToPage(_currentPage + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      color: _currentPage < _totalPages
                          ? AppTheme.hkmuGreen
                          : theme.colorScheme.onSurfaceVariant,
                      iconSize: isMobile ? 28 : 32,
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
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data != true) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () => context.go('/upload'),
            backgroundColor: AppTheme.hkmuGreen,
            icon: const Icon(Icons.upload),
            label: Text(
              isMobile ? 'Upload' : 'Upload Model',
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
            heroTag: 'upload_fab',
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearchField(ThemeData theme, bool isDark) {
    return TextField(
      onChanged: _onSearchChanged,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Search by name...',
        prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.hkmuGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildCategoryDropdown(ThemeData theme, bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.filter_list),
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.hkmuGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: _displayCategories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: _onCategoryChanged,
      isExpanded: true,
      style: TextStyle(color: theme.colorScheme.onSurface),
    );
  }

  Widget _buildModelGrid(int crossAxisCount) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: 12,
        itemBuilder: (context, index) => Card(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_models.isEmpty && _currentPage == 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.view_in_ar_outlined,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                _searchTerm.trim().isEmpty && _selectedCategory == 'All'
                    ? 'No models uploaded yet'
                    : 'No models found',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _searchTerm.trim().isEmpty && _selectedCategory == 'All'
                    ? 'Be the first to upload!'
                    : 'Try adjusting your search or filter',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _models.length,
      itemBuilder: (context, index) {
        final model = _models[index];
        final thumbnailUrl = getThumbnailUrl(model['thumbnail_path']);
        final cats = (model['categories'] as List<dynamic>?)?.cast<String>() ?? [];
        final displayCat = cats.isEmpty ? 'Other' : cats.join(', ');

        return InkWell(
          onTap: () => showModelDetailDialog(context, model['id'] as String),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Image.network(
                    thumbnailUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
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
                        model['name'] ?? 'Untitled Model',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayCat,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
  }
}