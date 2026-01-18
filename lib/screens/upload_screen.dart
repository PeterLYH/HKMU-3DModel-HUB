// upload_screen.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/widgets/header.dart';
import '../styles/styles.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isUploading = false;

  String _uploadMode = 'single';

  // Single mode
  PlatformFile? _modelFile;
  PlatformFile? _thumbnailFile;
  String? _modelFileName;
  String? _thumbnailFileName;
  bool _hasPickedModel = false;

  // Multi mode
  List<PlatformFile> _modelFiles = [];
  List<PlatformFile?> _thumbnails = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _acknowledgementController = TextEditingController();

  String _selectedSource = 'HKMU';
  String _selectedLicense = 'Non-commercial';

  final List<String> _sources = ['HKMU', 'Purchased', 'Vendor'];
  final List<String> _licenses = ['Non-commercial', 'Commercial'];

  List<Map<String, dynamic>> _categoryList = [];
  final Set<String> _selectedCategories = {};

  String get _fileType {
    if (_modelFileName == null) return '-';
    return '.${_modelFileName!.split('.').last.toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');
      if (mounted) {
        setState(() {
          _categoryList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _pickSingleModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf', 'obj', 'fbx', 'stl', 'blend', 'zip'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      setState(() {
        _modelFile = file;
        _modelFileName = file.name;
        _hasPickedModel = true;
        final nameWithoutExt = file.name.split('.').first;
        _nameController.text = nameWithoutExt;
      });
    }
  }

  Future<void> _pickMultipleModels() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf', 'obj', 'fbx', 'stl', 'blend', 'zip'],
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _modelFiles = result.files;
        _thumbnails = List<PlatformFile?>.filled(result.files.length, null);
      });
    }
  }

  Future<void> _pickSingleThumbnail() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _thumbnailFile = result.files.single;
        _thumbnailFileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickThumbnailForMulti(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _thumbnails[index] = result.files.single;
      });
    }
  }

  Future<void> _uploadSingleModel() async {
    if (_modelFile?.bytes == null || _thumbnailFile?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model file and thumbnail are required')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a model name')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Not authenticated';

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final modelUniqueName = '${timestamp}_model_$_modelFileName';
      final modelPath = 'models/${user.id}/$modelUniqueName';
      await Supabase.instance.client.storage
          .from('3d-models')
          .uploadBinary(modelPath, _modelFile!.bytes!);

      final thumbUniqueName = '${timestamp}_thumb_$_thumbnailFileName';
      final thumbPath = 'models/${user.id}/$thumbUniqueName';
      await Supabase.instance.client.storage
          .from('3d-models')
          .uploadBinary(thumbPath, _thumbnailFile!.bytes!);

      await Supabase.instance.client.from('models').insert({
        'user_id': user.id,
        'file_path': modelPath,
        'thumbnail_path': thumbPath,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'source': _selectedSource,
        'license_type': _selectedLicense,
        'acknowledgement': _acknowledgementController.text.trim(),
        'file_type': _fileType,
        'categories': _selectedCategories.toList(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Model uploaded successfully!'),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadMultipleModels() async {
    if (_modelFiles.isEmpty) return;

    setState(() => _isUploading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isUploading = false);
      return;
    }

    int successCount = 0;
    List<String> errors = [];

    for (int i = 0; i < _modelFiles.length; i++) {
      final model = _modelFiles[i];
      final thumb = _thumbnails[i];

      if (thumb == null) {
        errors.add('${model.name}: Missing thumbnail');
        continue;
      }

      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final modelPath = 'models/${user.id}/${timestamp}_${model.name}';
        await Supabase.instance.client.storage
            .from('3d-models')
            .uploadBinary(modelPath, model.bytes!);

        final thumbPath = 'models/${user.id}/${timestamp}_thumb_${thumb.name}';
        await Supabase.instance.client.storage
            .from('3d-models')
            .uploadBinary(thumbPath, thumb.bytes!);

        await Supabase.instance.client.from('models').insert({
          'user_id': user.id,
          'file_path': modelPath,
          'thumbnail_path': thumbPath,
          'name': model.name.split('.').first,
          'source': _selectedSource,
          'license_type': _selectedLicense,
          'file_type': '.${model.name.split('.').last.toUpperCase()}',
          'created_at': DateTime.now().toIso8601String(),
          // You can add description, categories, acknowledgement later in edit screen
        });

        successCount++;
      } catch (e) {
        errors.add('${model.name}: $e');
        debugPrint('Error uploading ${model.name}: $e');
      }
    }

    setState(() => _isUploading = false);

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount model(s) uploaded successfully'),
          backgroundColor: AppTheme.hkmuGreen,
        ),
      );
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${errors.length} upload(s) failed'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    if (successCount == _modelFiles.length && mounted) {
      context.go('/');
    }
  }

  void _removeMultiModel(int index) {
    setState(() {
      _modelFiles.removeAt(index);
      _thumbnails.removeAt(index);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _acknowledgementController.dispose();
    super.dispose();
  }

  Widget _buildSingleUploadContent() {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return AnimatedOpacity(
      opacity: _hasPickedModel ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: AnimatedScale(
        scale: _hasPickedModel ? 1.0 : 0.8,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: _hasPickedModel
            ? isWideScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isUploading ? null : _pickSingleThumbnail,
                              icon: const Icon(Icons.image),
                              label: Text(
                                _thumbnailFileName == null
                                    ? 'Upload Preview Image *'
                                    : 'Change Preview Image',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.hkmuGreen,
                                side: const BorderSide(color: AppTheme.hkmuGreen, width: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_thumbnailFile?.bytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  _thumbnailFile!.bytes!,
                                  height: 400,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                height: 400,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No preview image yet\nUpload one using the button above',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Model Name *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Categories (select multiple)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            if (_categoryList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categoryList.map((catMap) {
                                  final category = catMap['name'] as String;
                                  final isSelected = _selectedCategories.contains(category);
                                  return FilterChip(
                                    label: Text(category),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedCategories.add(category);
                                        } else {
                                          _selectedCategories.remove(category);
                                        }
                                      });
                                    },
                                    selectedColor: AppTheme.hkmuGreen.withOpacity(0.25),
                                    checkmarkColor: AppTheme.hkmuGreen,
                                    backgroundColor: Colors.grey[200],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedSource,
                              decoration: const InputDecoration(
                                labelText: 'Source *',
                                border: OutlineInputBorder(),
                              ),
                              items: _sources
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => v != null ? setState(() => _selectedSource = v) : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedLicense,
                              decoration: const InputDecoration(
                                labelText: 'Usage / License *',
                                border: OutlineInputBorder(),
                              ),
                              items: _licenses
                                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                                  .toList(),
                              onChanged: (v) => v != null ? setState(() => _selectedLicense = v) : null,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _acknowledgementController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Acknowledgement / Credits',
                                hintText: 'e.g. Model from Sketchfab, textures by Poly Haven, ...',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 24),
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'File Type',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _fileType,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isUploading || _thumbnailFile == null ? null : _uploadSingleModel,
                                icon: _isUploading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.upload),
                                label: Text(_isUploading ? 'Uploading...' : 'Upload Model'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.hkmuGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  minimumSize: const Size(double.infinity, 56),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isUploading ? null : _pickSingleThumbnail,
                        icon: const Icon(Icons.image),
                        label: Text(
                          _thumbnailFileName == null ? 'Upload Preview Image *' : 'Change Preview Image',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.hkmuGreen,
                          side: const BorderSide(color: AppTheme.hkmuGreen, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_thumbnailFile?.bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _thumbnailFile!.bytes!,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Model Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_categoryList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categoryList.map((catMap) {
                            final category = catMap['name'] as String;
                            final isSelected = _selectedCategories.contains(category);
                            return FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) _selectedCategories.add(category);
                                  else _selectedCategories.remove(category);
                                });
                              },
                              selectedColor: AppTheme.hkmuGreen.withOpacity(0.25),
                              checkmarkColor: AppTheme.hkmuGreen,
                              backgroundColor: Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedSource,
                        decoration: const InputDecoration(
                          labelText: 'Source *',
                          border: OutlineInputBorder(),
                        ),
                        items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => v != null ? setState(() => _selectedSource = v) : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedLicense,
                        decoration: const InputDecoration(
                          labelText: 'Usage / License *',
                          border: OutlineInputBorder(),
                        ),
                        items: _licenses.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (v) => v != null ? setState(() => _selectedLicense = v) : null,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _acknowledgementController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Acknowledgement / Credits',
                          hintText: 'e.g. Model from Sketchfab, textures by Poly Haven',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'File Type',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _fileType,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading || _thumbnailFile == null ? null : _uploadSingleModel,
                          icon: _isUploading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Icon(Icons.upload),
                          label: Text(_isUploading ? 'Uploading...' : 'Upload Model'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hkmuGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildMultiUploadContent() {
    if (_modelFiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No models selected yet.\nPlease choose model files to upload.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Models',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _modelFiles.length,
          itemBuilder: (context, index) {
            final file = _modelFiles[index];
            final thumb = _thumbnails[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: thumb != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          thumb.bytes!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, size: 28),
                      ),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(thumb != null ? 'Preview added' : 'No preview yet'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate, color: AppTheme.hkmuGreen),
                      onPressed: _isUploading ? null : () => _pickThumbnailForMulti(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isUploading ? null : () => _removeMultiModel(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Common settings (applied to all models)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedSource,
          decoration: const InputDecoration(
            labelText: 'Source *',
            border: OutlineInputBorder(),
          ),
          items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: _isUploading ? null : (v) => v != null ? setState(() => _selectedSource = v) : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedLicense,
          decoration: const InputDecoration(
            labelText: 'Usage / License *',
            border: OutlineInputBorder(),
          ),
          items: _licenses.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: _isUploading ? null : (v) => v != null ? setState(() => _selectedLicense = v) : null,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUploading || _modelFiles.isEmpty ? null : _uploadMultipleModels,
            icon: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.upload),
            label: Text(
              _isUploading
                  ? 'Uploading ${_modelFiles.length} models...'
                  : 'Upload All Models',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.hkmuGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload, size: 80, color: AppTheme.hkmuGreen),
                      const SizedBox(height: 24),
                      Text(
                        'Upload Your 3D Model',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.hkmuGreen,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported formats: .glb, .gltf, .obj, .fbx, .stl, .blend, .zip\nThumbnail: JPG, PNG, WebP',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'single', label: Text('Single Model')),
                          ButtonSegment(value: 'multi', label: Text('Multiple Models')),
                        ],
                        selected: {_uploadMode},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _uploadMode = newSelection.first;
                            if (_uploadMode == 'single') {
                              _modelFiles = [];
                              _thumbnails = [];
                            } else {
                              _modelFile = null;
                              _thumbnailFile = null;
                              _hasPickedModel = false;
                              _nameController.clear();
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 32),

                      if (_uploadMode == 'single')
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickSingleModel,
                          icon: const Icon(Icons.folder_open),
                          label: Text(
                            _hasPickedModel ? 'Change Model File' : 'Choose 3D Model File',
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hkmuGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickMultipleModels,
                          icon: const Icon(Icons.folder_copy),
                          label: const Text(
                            'Choose Multiple 3D Models',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hkmuGreen.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                      const SizedBox(height: 32),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: KeyedSubtree(
                          key: ValueKey(_uploadMode),
                          child: _uploadMode == 'single'
                              ? _buildSingleUploadContent()
                              : _buildMultiUploadContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}