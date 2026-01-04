// lib/screens/upload_screen.dart

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
  bool _hasPickedModel = false;

  // 3D Model file
  String? _modelFileName;
  PlatformFile? _modelFile;

  // Thumbnail image
  String? _thumbnailFileName;
  PlatformFile? _thumbnailFile;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'Architecture';

  final List<String> _categories = [
    'Architecture',
    'Characters',
    'Vehicles',
    'Nature',
    'Props',
    'Other',
  ];

  String get _fileType {
    if (_modelFileName == null) return '-';
    return '.${_modelFileName!.split('.').last.toUpperCase()}';
  }

  Future<void> _pickModelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf', 'obj', 'fbx', 'stl', 'blend'],
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

  Future<void> _pickThumbnail() async {
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

  Future<void> _uploadModel() async {
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
        'category': _selectedCategory,
        'file_type': _fileType,
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

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
                      const SizedBox(height: 16),
                      Text(
                        'Supported formats: .glb, .gltf, .obj, .fbx, .stl, .blend\nThumbnail: JPG, PNG, WebP',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Main Choose Model Button
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickModelFile,
                        icon: const Icon(Icons.folder_open),
                        label: Text(
                          _hasPickedModel ? 'Upload a Model' : 'Choose 3D Model File *',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.hkmuGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Animated 2-Column Form
                      AnimatedOpacity(
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
                                        // Left Column: Preview + Upload Preview button
                                        Expanded(
                                          child: Column(
                                            children: [
                                              // Outlined "Upload a Preview" button with visible icon
                                              OutlinedButton.icon(
                                                onPressed: _isUploading ? null : _pickThumbnail,
                                                icon: const Icon(Icons.image),
                                                label: Text(
                                                  _thumbnailFileName == null ? 'Upload Preview *' : 'Change Preview',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppTheme.hkmuGreen,
                                                  side: BorderSide(color: AppTheme.hkmuGreen, width: 2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                                  minimumSize: const Size(double.infinity, 60),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  alignment: Alignment.center,
                                                ).copyWith(
                                                  overlayColor: WidgetStateProperty.all(AppTheme.hkmuGreen.withValues(alpha: 0.08)),
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
                                                      'No preview yet\nSelect an image above',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontSize: 18, color: Colors.grey),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 40),

                                        // Right Column: Form fields (File Type at the end)
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

                                              DropdownButtonFormField<String>(
                                                initialValue: _selectedCategory,
                                                decoration: const InputDecoration(
                                                  labelText: 'Category',
                                                  border: OutlineInputBorder(),
                                                ),
                                                items: _categories.map((cat) {
                                                  return DropdownMenuItem(value: cat, child: Text(cat));
                                                }).toList(),
                                                onChanged: (value) {
                                                  if (value != null) setState(() => _selectedCategory = value);
                                                },
                                              ),
                                              const SizedBox(height: 24),

                                              // File Type - LAST, smaller extension
                                              InputDecorator(
                                                decoration: const InputDecoration(
                                                  labelText: 'File Type',
                                                  border: OutlineInputBorder(),
                                                ),
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: Theme.of(context).textTheme.bodyLarge,
                                                    children: [
                                                      const TextSpan(text: 'File Type: '),
                                                      TextSpan(
                                                        text: _fileType,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey[600],
                                                          fontWeight: FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 40),

                                              // Final Upload Button
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: _isUploading || _thumbnailFile == null ? null : _uploadModel,
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
                                          onPressed: _isUploading ? null : _pickThumbnail,
                                          icon: const Icon(Icons.image),
                                          label: Text(
                                            _thumbnailFileName == null ? 'Upload Preview *' : 'Change Preview',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.hkmuGreen,
                                            side: BorderSide(color: AppTheme.hkmuGreen, width: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                            minimumSize: const Size(double.infinity, 60),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            alignment: Alignment.center,
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
                                        DropdownButtonFormField<String>(
                                          initialValue: _selectedCategory,
                                          decoration: const InputDecoration(
                                            labelText: 'Category',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                                          onChanged: (value) => setState(() => _selectedCategory = value!),
                                        ),
                                        const SizedBox(height: 24),
                                        InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'File Type',
                                            border: OutlineInputBorder(),
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: Theme.of(context).textTheme.bodyLarge,
                                              children: [
                                                const TextSpan(text: 'File Type: '),
                                                TextSpan(
                                                  text: _fileType,
                                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 40),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _isUploading || _thumbnailFile == null ? null : _uploadModel,
                                            icon: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.upload),
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