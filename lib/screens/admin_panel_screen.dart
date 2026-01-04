// lib/screens/admin_panel_screen.dart


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../styles/styles.dart';
import '../core/widgets/header.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.hkmuGreen,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  child: Text(
                    'Admin Panel',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Users Management'),
                    Tab(text: 'Models Management'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                UsersManagementTab(),
                ModelsManagementTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// USERS MANAGEMENT TAB

class UsersManagementTab extends StatefulWidget {
  const UsersManagementTab({super.key});

  @override
  State<UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _hasError = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('userid, username, nickname, email, role, created_at')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() {
        _hasError = true;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load users. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final usernameController = TextEditingController(text: user['username'] ?? '');
    final nicknameController = TextEditingController(text: user['nickname'] ?? '');
    final emailController = TextEditingController(text: user['email']);
    String selectedRole = user['role'] ?? 'user';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit User'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                enabled: false,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Role *', border: OutlineInputBorder()),
                items: ['user', 'admin']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                    .toList(),
                onChanged: (val) => selectedRole = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hkmuGreen),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await Supabase.instance.client.from('users').update({
        'username': usernameController.text.trim().isEmpty ? null : usernameController.text.trim(),
        'nickname': nicknameController.text.trim().isEmpty ? null : nicknameController.text.trim(),
        'role': selectedRole,
      }).eq('userid', user['userid']);

      setState(() {
        user['username'] = usernameController.text.trim().isEmpty ? null : usernameController.text.trim();
        user['nickname'] = nicknameController.text.trim().isEmpty ? null : nicknameController.text.trim();
        user['role'] = selectedRole;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update user'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(String userid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete $email?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.rpc('delete_user', params: {'user_id': userid});
      await Supabase.instance.client.from('users').delete().eq('userid', userid);

      setState(() {
        _users.removeWhere((u) => u['userid'] == userid);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete user.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      return (user['email']?.toString().toLowerCase() ?? '').contains(query) ||
          (user['username']?.toString().toLowerCase() ?? '').contains(query) ||
          (user['nickname']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by email, username or nickname...',
                    prefixIcon: const Icon(Icons.search, size: 28),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.refresh, size: 36),
                tooltip: 'Refresh users',
                onPressed: _loadUsers,
                color: AppTheme.hkmuGreen,
                padding: const EdgeInsets.all(16),
              ),
            ],
          ),
          const SizedBox(height: 40),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 100, color: Colors.red),
                            const SizedBox(height: 32),
                            const Text('Failed to load users', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry', style: TextStyle(fontSize: 18))),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(child: Text('No users found yet.', style: TextStyle(fontSize: 24)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 60,
                                headingRowHeight: 80,
                                // ignore: deprecated_member_use
                                dataRowHeight: 100,
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                dataTextStyle: const TextStyle(fontSize: 18),
                                columns: const [
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Username')),
                                  DataColumn(label: Text('Nickname')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Joined')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _filteredUsers.map((user) {
                                  final userid = user['userid'] as String;
                                  final email = user['email'] as String;
                                  final role = user['role'] as String? ?? 'user';
                                  final createdAt = DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();

                                  return DataRow(cells: [
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text(email, style: const TextStyle(fontFamily: 'monospace', fontSize: 18)),
                                      ),
                                    ),
                                    DataCell(Text(user['username']?.toString() ?? '-', style: const TextStyle(fontSize: 18))),
                                    DataCell(Text(user['nickname']?.toString() ?? '-', style: const TextStyle(fontSize: 18))),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Chip(
                                          label: Text(role.toUpperCase()),
                                          backgroundColor: role == 'admin' ? AppTheme.hkmuGreen.withValues(alpha: 0.2) : Colors.grey[200],
                                          labelStyle: TextStyle(
                                            color: role == 'admin' ? AppTheme.hkmuGreen : Colors.grey[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(DateFormat('dd/MM/yyyy').format(createdAt), style: const TextStyle(fontSize: 18))),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 36, color: Colors.blue),
                                            tooltip: 'Edit user',
                                            onPressed: () => _editUser(user),
                                            padding: const EdgeInsets.all(12),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_forever, size: 36, color: Colors.red),
                                            tooltip: 'Delete user',
                                            onPressed: () => _deleteUser(userid, email),
                                            padding: const EdgeInsets.all(12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

//MODELS MANAGEMENT TAB

class ModelsManagementTab extends StatefulWidget {
  const ModelsManagementTab({super.key});

  @override
  State<ModelsManagementTab> createState() => _ModelsManagementTabState();
}

class _ModelsManagementTabState extends State<ModelsManagementTab> {
  List<Map<String, dynamic>> _models = [];
  bool _loading = true;
  bool _hasError = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final modelResponse = await Supabase.instance.client
          .from('models')
          .select()
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> models = List.from(modelResponse);

      final Set<String> userIds = models.map((m) => m['user_id'] as String?).whereType<String>().toSet();
      Map<String, String> emailMap = {};
      if (userIds.isNotEmpty) {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('userid, email')
            .inFilter('userid', userIds.toList());

        emailMap = {for (var u in userResponse) u['userid'] as String: u['email'] as String};
      }

      for (var model in models) {
        model['uploader_email'] = emailMap[model['user_id']] ?? 'Unknown';
      }

      setState(() {
        _models = models;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading models: $e');
      setState(() {
        _hasError = true;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load models.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editModel(Map<String, dynamic> model) async {
    final nameController = TextEditingController(text: model['name']);
    final descController = TextEditingController(text: model['description'] ?? '');
    String selectedCategory = model['category'] ?? 'Other';

    PlatformFile? newModelFile;
    String? newModelFileName;
    PlatformFile? newThumbnailFile;
    String? newThumbnailFileName;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Model'),
          content: SizedBox(
            width: double.maxFinite,
            height: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['glb', 'gltf', 'obj', 'fbx', 'stl', 'blend'],
                        withData: true,
                      );
                      if (result != null && result.files.single.bytes != null) {
                        setDialogState(() {
                          newModelFile = result.files.single;
                          newModelFileName = result.files.single.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.folder_open),
                    label: Text(newModelFileName ?? 'Replace 3D Model File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.hkmuGreen,
                      side: BorderSide(color: AppTheme.hkmuGreen, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (result != null && result.files.single.bytes != null) {
                        setDialogState(() {
                          newThumbnailFile = result.files.single;
                          newThumbnailFileName = result.files.single.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(newThumbnailFileName ?? 'Replace Thumbnail *'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.hkmuGreen,
                      side: BorderSide(color: AppTheme.hkmuGreen, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (newThumbnailFile?.bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(newThumbnailFile!.bytes!, height: 200, fit: BoxFit.cover),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        Supabase.instance.client.storage.from('3d-models').getPublicUrl(model['thumbnail_path']),
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 80),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: ['Architecture', 'Characters', 'Vehicles', 'Nature', 'Props', 'Other']
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) => selectedCategory = val!,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hkmuGreen),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      Map<String, dynamic> updates = {
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
        'category': selectedCategory,
      };

      String? newModelPath;
      String? newThumbPath;

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (newModelFile != null) {
        final uniqueName = '${timestamp}_model_$newModelFileName';
        newModelPath = 'models/${model['user_id']}/$uniqueName';
        await Supabase.instance.client.storage
            .from('3d-models')
            .uploadBinary(newModelPath, newModelFile!.bytes!);
        updates['file_path'] = newModelPath;
        updates['file_type'] = '.${newModelFileName!.split('.').last.toUpperCase()}';
      }

      if (newThumbnailFile != null) {
        final uniqueName = '${timestamp}_thumb_$newThumbnailFileName';
        newThumbPath = 'models/${model['user_id']}/$uniqueName';
        await Supabase.instance.client.storage
            .from('3d-models')
            .uploadBinary(newThumbPath, newThumbnailFile!.bytes!);
        updates['thumbnail_path'] = newThumbPath;
      }

      await Supabase.instance.client.from('models').update(updates).eq('id', model['id']);

      setState(() {
        model.addAll(updates);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model updated successfully'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update model'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteModel(Map<String, dynamic> model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Delete "${model['name']}"?\nThis will permanently remove the file and thumbnail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.storage
          .from('3d-models')
          .remove([model['file_path'], model['thumbnail_path']]);

      await Supabase.instance.client.from('models').delete().eq('id', model['id']);

      setState(() {
        _models.remove(model);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model deleted successfully'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete model'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredModels {
    if (_searchQuery.isEmpty) return _models;
    final query = _searchQuery.toLowerCase();
    return _models.where((model) {
      return (model['name']?.toString().toLowerCase() ?? '').contains(query) ||
          (model['category']?.toString().toLowerCase() ?? '').contains(query) ||
          (model['file_type']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();
  }

  String getThumbnailUrl(String path) {
    return Supabase.instance.client.storage.from('3d-models').getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, category, or file type...',
                    prefixIcon: const Icon(Icons.search, size: 28),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.refresh, size: 36),
                tooltip: 'Refresh models',
                onPressed: _loadModels,
                color: AppTheme.hkmuGreen,
                padding: const EdgeInsets.all(16),
              ),
            ],
          ),
          const SizedBox(height: 40),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 100, color: Colors.red),
                            const SizedBox(height: 32),
                            const Text('Failed to load models', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadModels, child: const Text('Retry', style: TextStyle(fontSize: 18))),
                          ],
                        ),
                      )
                    : _models.isEmpty
                        ? const Center(child: Text('No models uploaded yet.', style: TextStyle(fontSize: 24)))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 60,
                                headingRowHeight: 80,
                                // ignore: deprecated_member_use
                                dataRowHeight: 120,
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                dataTextStyle: const TextStyle(fontSize: 18),
                                columns: const [
                                  DataColumn(label: Text('Thumbnail')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('File Type')),
                                  DataColumn(label: Text('Uploader')),
                                  DataColumn(label: Text('Uploaded')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _filteredModels.map((model) {
                                  final createdAt = DateTime.tryParse(model['created_at'] ?? '') ?? DateTime.now();
                                  final uploaderEmail = model['uploader_email'] ?? 'Unknown';

                                  return DataRow(cells: [
                                    DataCell(
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(
                                          getThumbnailUrl(model['thumbnail_path']),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image_not_supported, size: 50),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          model['name'] ?? 'Untitled',
                                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(model['category'] ?? 'Other', style: const TextStyle(fontSize: 18))),
                                    DataCell(Text(model['file_type'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                                    DataCell(Text(uploaderEmail, style: const TextStyle(fontSize: 17))),
                                    DataCell(Text(DateFormat('dd/MM/yyyy').format(createdAt), style: const TextStyle(fontSize: 18))),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 36, color: Colors.blue),
                                            tooltip: 'Edit model',
                                            onPressed: () => _editModel(model),
                                            padding: const EdgeInsets.all(12),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_forever, size: 36, color: Colors.red),
                                            tooltip: 'Delete model',
                                            onPressed: () => _deleteModel(model),
                                            padding: const EdgeInsets.all(12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}