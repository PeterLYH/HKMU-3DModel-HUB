// lib/screens/admin_panel_screen.dart

import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../styles/styles.dart';
import '../core/widgets/header.dart';

// ==================== MAIN ADMIN PANEL ====================

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
    _tabController = TabController(length: 3, vsync: this);
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
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Users Management'),
                    Tab(text: 'Models Management'),
                    Tab(text: 'Download Requests',)
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
                DownloadRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== USERS MANAGEMENT TAB ====================

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

  // Batch selection
  final Set<String> _selectedUserIds = {};
  bool _selectAllUsers = false;

  static const String _createUserFunctionUrl =
      'https://mygplwghoudapvhdcrke.supabase.co/functions/v1/admin-create-user';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _selectedUserIds.clear();
      _selectAllUsers = false;
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
          const SnackBar(content: Text('Failed to load users.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleSelectAllUsers(bool? value) {
    setState(() {
      _selectAllUsers = value ?? false;
      if (_selectAllUsers) {
        _selectedUserIds.addAll(_filteredUsers.map((u) => u['userid'] as String));
      } else {
        _selectedUserIds.clear();
      }
    });
  }

  void _toggleUserSelection(String userid, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedUserIds.add(userid);
      } else {
        _selectedUserIds.remove(userid);
      }
      _selectAllUsers = _selectedUserIds.length == _filteredUsers.length && _filteredUsers.isNotEmpty;
    });
  }

  Future<void> _createUser() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final usernameController = TextEditingController();
    final nicknameController = TextEditingController();
    String selectedRole = 'user';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New User'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (HKMU Email)*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password * (min 6 chars)',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: ['user', 'admin']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) selectedRole = val;
                  },
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
            child: const Text('Create User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();
    final nickname = nicknameController.text.trim();

    if (email.isEmpty || password.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valid email and password (min 6 characters) required'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse(_createUserFunctionUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': username.isEmpty ? null : username,
          'nickname': nickname.isEmpty ? null : nickname,
          'role': selectedRole,
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed (HTTP ${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      final newUserId = data['userId'] as String?;

      if (newUserId == null) throw Exception('No user ID returned');

      final newUser = {
        'userid': newUserId,
        'email': email,
        'username': username.isEmpty ? null : username,
        'nickname': nickname.isEmpty ? null : nickname,
        'role': selectedRole,
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _users.insert(0, newUser);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $email created successfully!'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      debugPrint('Error creating user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: ${e.toString().split('\n').first}'), backgroundColor: Colors.red),
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
                items: ['user', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                onChanged: (val) {
                  if (val != null) selectedRole = val;
                },
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

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final newPasswordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMessage;

    final _ = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset User Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'User: ${user['email']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPass = newPasswordCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();

                if (newPass.isEmpty) {
                  setDialogState(() => errorMessage = 'Password is required');
                  return;
                }

                if (newPass != confirm) {
                  setDialogState(() => errorMessage = 'Passwords do not match');
                  return;
                }

                if (newPass.length < 6) {
                  setDialogState(() => errorMessage = 'Password must be at least 6 characters');
                  return;
                }

                try {
                  final res = await Supabase.instance.client.rpc(
                    'admin_reset_user_password',
                    params: {
                      'p_user_id': user['userid'],
                      'p_new_password': newPass,
                    },
                  );

                  if (res == 'success') {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(ctx, true);
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Password reset successfully for ${user['email']}'),
                          backgroundColor: AppTheme.hkmuGreen,
                        ),
                      );
                    }
                  } else if (res == 'password_too_short') {
                    setDialogState(() => errorMessage = 'Password too short');
                  } else if (res == 'user_not_found') {
                    setDialogState(() => errorMessage = 'User not found');
                  } else {
                    setDialogState(() => errorMessage = 'Failed: $res');
                  }
                } catch (e) {
                  setDialogState(() => errorMessage = 'Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.hkmuGreen),
              child: const Text('Reset Password', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    newPasswordCtrl.dispose();
    confirmCtrl.dispose();
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
        _selectedUserIds.remove(userid);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete user.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _batchDeleteUsers() async {
    if (_selectedUserIds.isEmpty) return;

    final count = _selectedUserIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Users'),
        content: Text('Are you sure you want to permanently delete $count user(s)?\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      for (final userid in List.from(_selectedUserIds)) {
        await Supabase.instance.client.rpc('delete_user', params: {'user_id': userid});
        await Supabase.instance.client.from('users').delete().eq('userid', userid);
      }

      setState(() {
        _users.removeWhere((u) => _selectedUserIds.contains(u['userid']));
        _selectedUserIds.clear();
        _selectAllUsers = false;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count user(s) deleted successfully'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      debugPrint('Batch delete error: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete selected users'), backgroundColor: Colors.red),
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
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                onPressed: _createUser,
                icon: const Icon(Icons.person_add, size: 28),
                label: const Text('Create User', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hkmuGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  elevation: 2,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh, size: 36),
                tooltip: 'Refresh users',
                onPressed: _loadUsers,
                color: AppTheme.hkmuGreen,
                padding: const EdgeInsets.all(16),
              ),
            ],
          ),

          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedUserIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever, size: 24),
                    label: const Text('Delete Selected', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: _batchDeleteUsers,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedUserIds.clear();
                      _selectAllUsers = false;
                    }),
                    child: const Text('Clear selection', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
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
                            ElevatedButton(
                              onPressed: _loadUsers,
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                              child: const Text('Retry', style: TextStyle(fontSize: 18)),
                            ),
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
                                columns: [
                                  DataColumn(
                                    label: Checkbox(
                                      value: _selectAllUsers,
                                      onChanged: _toggleSelectAllUsers,
                                    ),
                                  ),
                                  const DataColumn(label: Text('Email')),
                                  const DataColumn(label: Text('Username')),
                                  const DataColumn(label: Text('Nickname')),
                                  const DataColumn(label: Text('Role')),
                                  const DataColumn(label: Text('Joined')),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: _filteredUsers.map((user) {
                                  final userid = user['userid'] as String;
                                  final email = user['email'] as String;
                                  final role = user['role'] as String? ?? 'user';
                                  final createdAt = DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();
                                  final isSelected = _selectedUserIds.contains(userid);

                                  return DataRow(
                                    color: WidgetStateProperty.resolveWith<Color?>(
                                      (states) => isSelected ? Colors.blue.withValues(alpha: 0.08) : null,
                                    ),
                                    cells: [
                                      DataCell(
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (v) => _toggleUserSelection(userid, v),
                                        ),
                                      ),
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
                                            backgroundColor: role == 'admin'
                                                ? AppTheme.hkmuGreen.withValues(alpha: 0.2)
                                                : Colors.grey[200],
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
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 36, color: Colors.blue),
                                              tooltip: 'Edit user',
                                              onPressed: () => _editUser(user),
                                              padding: const EdgeInsets.all(12),
                                            ),
                                              IconButton(
                                                      icon: SvgPicture.asset(
                                                        'assets/icons/password.svg',
                                                        width: 36,
                                                        height: 36,
                                                        colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                                                      ),
                                                      tooltip: 'Reset Password',
                                                      onPressed: () => _resetPassword(user),
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
                                    ],
                                  );
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

// ==================== MODELS MANAGEMENT TAB ====================

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

  final Set<dynamic> _selectedModelIds = {};
  bool _selectAllModels = false;

  static const String _zipFunctionUrl = 'https://mygplwghoudapvhdcrke.supabase.co/functions/v1/zip-models';

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _selectedModelIds.clear();
      _selectAllModels = false;
    });

    try {
      final modelResponse = await Supabase.instance.client
          .from('models')
          .select()
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> models = List.from(modelResponse);

      final Set<String> userIds =
          models.map((m) => m['user_id'] as String?).whereType<String>().toSet();
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

  // Toggle select all checkbox
  void _toggleSelectAllModels(bool? value) {
    setState(() {
      _selectAllModels = value ?? false;
      if (_selectAllModels) {
        _selectedModelIds.addAll(_filteredModels.map((m) => m['id']));
      } else {
        _selectedModelIds.clear();
      }
    });
  }

  // Toggle individual row selection
  void _toggleModelSelection(dynamic id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedModelIds.add(id);
      } else {
        _selectedModelIds.remove(id);
      }
      _selectAllModels = _selectedModelIds.length == _filteredModels.length && _filteredModels.isNotEmpty;
    });
  }

  // Batch delete selected models
  Future<void> _batchDeleteModels() async {
    if (_selectedModelIds.isEmpty) return;

    final count = _selectedModelIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Models'),
        content: Text(
          'Are you sure you want to permanently delete $count model(s)?\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      for (final id in List.from(_selectedModelIds)) {
        final model = _models.firstWhere((m) => m['id'] == id);
        await Supabase.instance.client.storage
            .from('3d-models')
            .remove([model['file_path'], model['thumbnail_path']]);
        await Supabase.instance.client.from('models').delete().eq('id', id);
      }

      setState(() {
        _models.removeWhere((m) => _selectedModelIds.contains(m['id']));
        _selectedModelIds.clear();
        _selectAllModels = false;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count model(s) deleted successfully'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      debugPrint('Batch delete error: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete selected models'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Batch download selected models as ZIP (via Edge Function)
  Future<void> _batchDownloadAsZip() async {
    if (_selectedModelIds.isEmpty) return;

    final selected = _models.where((m) => _selectedModelIds.contains(m['id'])).toList();
    final filePaths = selected.map((m) => m['file_path'] as String?).whereType<String>().toList();

    if (filePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No downloadable files found')),
      );
      return;
    }

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw 'Not authenticated';

      final response = await http.post(
        Uri.parse(_zipFunctionUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'filePaths': filePaths}),
      );

      if (response.statusCode != 200) {
        throw 'Server error: ${response.statusCode} - ${response.body}';
      }

      // Trigger browser download of ZIP
      final blob = html.Blob([response.bodyBytes], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final _ = html.AnchorElement(href: url)
        ..setAttribute('download', 'models_${DateTime.now().toIso8601String().substring(0, 10)}.zip')
        ..click();
      html.Url.revokeObjectUrl(url);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${filePaths.length} models as ZIP file'),
          backgroundColor: AppTheme.hkmuGreen,
        ),
      );

      // Optional: clear selection after successful download
      setState(() {
        _selectedModelIds.clear();
        _selectAllModels = false;
      });
    } catch (e) {
      debugPrint('ZIP download error: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create ZIP: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ===================== SINGLE MODEL OPERATIONS =====================

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
                    onChanged: (val) {
                      if (val != null) selectedCategory = val;
                    },
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
        content: Text(
            'Delete "${model['name']}"?\nThis will permanently remove the file and thumbnail.'),
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
        _selectedModelIds.remove(model['id']);
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

  Future<void> _downloadModel(Map<String, dynamic> model) async {
    try {
      final filePath = model['file_path'] as String?;
      if (filePath == null || filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file available for download'), backgroundColor: Colors.orange),
        );
        return;
      }

      final signedUrl = await Supabase.instance.client.storage
          .from('3d-models')
          .createSignedUrl(filePath, 3600);

      final suggestedName = model['name'] != null
          ? '${model['name']}${model['file_type'] ?? ''}'
          : 'model${model['file_type'] ?? ''}';

      final _ = html.AnchorElement(href: signedUrl)
        ..setAttribute('download', suggestedName)
        ..style.display = 'none'
        ..click()
        ..remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading $suggestedName...'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start download: $e'), backgroundColor: Colors.red),
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
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/upload'),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload New Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hkmuGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  elevation: 2,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh, size: 36),
                tooltip: 'Refresh models',
                onPressed: _loadModels,
                color: AppTheme.hkmuGreen,
                padding: const EdgeInsets.all(16),
              ),
            ],
          ),

          // Batch actions bar
          if (_selectedModelIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedModelIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.archive),
                    label: const Text('Download as ZIP'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: _batchDownloadAsZip,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Selected'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _batchDeleteModels,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedModelIds.clear();
                      _selectAllModels = false;
                    }),
                    child: const Text('Clear selection'),
                  ),
                ],
              ),
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
                                columns: [
                                  DataColumn(
                                    label: Checkbox(
                                      value: _selectAllModels,
                                      onChanged: _toggleSelectAllModels,
                                    ),
                                  ),
                                  const DataColumn(label: Text('Thumbnail')),
                                  const DataColumn(label: Text('Name')),
                                  const DataColumn(label: Text('Category')),
                                  const DataColumn(label: Text('File Type')),
                                  const DataColumn(label: Text('Uploader')),
                                  const DataColumn(label: Text('Uploaded')),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: _filteredModels.map((model) {
                                  final id = model['id'];
                                  final createdAt = DateTime.tryParse(model['created_at'] ?? '') ?? DateTime.now();
                                  final uploaderEmail = model['uploader_email'] ?? 'Unknown';
                                  final isSelected = _selectedModelIds.contains(id);

                                  return DataRow(
                                    color: WidgetStateProperty.resolveWith<Color?>(
                                      (states) => isSelected ? Colors.blue.withValues(alpha: 0.08) : null,
                                    ),
                                    cells: [
                                      DataCell(
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (val) => _toggleModelSelection(id, val),
                                        ),
                                      ),
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
                                      DataCell(Text(
                                        model['file_type'] ?? '',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                      )),
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
                                              icon: const Icon(Icons.download, size: 36, color: Colors.green),
                                              tooltip: 'Download single model',
                                              onPressed: () => _downloadModel(model),
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
                                    ],
                                  );
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

// ==================== DOWNLOAD REQUESTS MANAGEMENT TAB ====================
class DownloadRequestsTab extends StatefulWidget {
  const DownloadRequestsTab({super.key});

  @override
  State<DownloadRequestsTab> createState() => _DownloadRequestsTabState();
}

class _DownloadRequestsTabState extends State<DownloadRequestsTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _hasError = false;
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _selectedIds.clear();
      _selectAll = false;
    });

    try {
      final requestsResp = await Supabase.instance.client
          .from('download_requests')
          .select('id, user_id, email, model_ids, status, created_at, updated_at')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> requests = List.from(requestsResp);

      final Set<String> allModelIds = {};
      for (final req in requests) {
        final ids = (req['model_ids'] as List?)?.cast<String>() ?? [];
        allModelIds.addAll(ids);
      }

      Map<String, String> modelNameMap = {};
      if (allModelIds.isNotEmpty) {
        final modelsResp = await Supabase.instance.client
            .from('models')
            .select('id, name')
            .inFilter('id', allModelIds.toList());

        modelNameMap = {
          for (final m in modelsResp) m['id'] as String: (m['name'] as String? ?? 'Untitled').trim(),
        };
      }

      for (final req in requests) {
        final ids = (req['model_ids'] as List?)?.cast<String>() ?? [];
        req['model_names'] = ids.map((id) => modelNameMap[id] ?? 'Model-$id').toList();
      }

      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading download requests: $e');
      setState(() {
        _hasError = true;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load requests'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_searchQuery.isEmpty) return _requests;
    final q = _searchQuery.toLowerCase();
    return _requests.where((r) {
      return (r['email']?.toString().toLowerCase() ?? '').contains(q) ||
          (r['status']?.toString().toLowerCase() ?? '').contains(q);
    }).toList();
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedIds.addAll(_filteredRequests.map((r) => r['id'] as String));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      _selectAll = _selectedIds.length == _filteredRequests.length && _filteredRequests.isNotEmpty;
    });
  }

  // ────────────────────────────────────────────────
  // Get file paths for all models in a request
  // ────────────────────────────────────────────────
  Future<List<String>> _getModelFilePaths(String requestId) async {
    try {
      final req = _requests.firstWhere((r) => r['id'] == requestId, orElse: () => {});
      final modelIds = (req['model_ids'] as List<dynamic>?)?.cast<String>() ?? [];

      if (modelIds.isEmpty) return [];

      final modelsData = await Supabase.instance.client
          .from('models')
          .select('file_path')
          .inFilter('id', modelIds);

      return modelsData
          .map((m) => m['file_path'] as String?)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error fetching file paths: $e');
      return [];
    }
  }

Future<void> _downloadRequestAsZip(String requestId) async {
  final filePaths = await _getModelFilePaths(requestId);

  if (filePaths.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No downloadable files found in this request'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  try {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw 'Not authenticated';

    final response = await http.post(
      Uri.parse('https://mygplwghoudapvhdcrke.supabase.co/functions/v1/zip-models'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'filePaths': filePaths}),
    );

    if (response.statusCode != 200) {
      throw 'Server error: ${response.statusCode} - ${response.body}';
    }

    // Trigger browser download — same pattern as Models tab
    final blob = html.Blob([response.bodyBytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final _ = html.AnchorElement(href: url)
      ..setAttribute('download', 'request_${requestId}_${DateTime.now().toIso8601String().substring(0, 10)}.zip')
      ..click();
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${filePaths.length} model${filePaths.length == 1 ? "" : "s"} as ZIP file'),
          backgroundColor: AppTheme.hkmuGreen,
        ),
      );
    }
  } catch (e) {
    debugPrint('ZIP download error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create ZIP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      // 1. Update status in database
      await Supabase.instance.client
          .from('download_requests')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      // 2. If processed → automatically download ZIP
      if (newStatus == 'processed') {
        await _downloadRequestAsZip(id);
      }

      // 3. Update local UI state
      final req = _requests.firstWhere((r) => r['id'] == id);
      setState(() {
        req['status'] = newStatus;
        req['updated_at'] = DateTime.now().toIso8601String();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'processed'
                  ? 'Request processed & ZIP downloaded'
                  : 'Request marked as $newStatus',
            ),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Status update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _batchDeleteProcessedOrRejected() async {
    final toDelete = _requests
        .where((r) =>
            (r['status'] == 'processed' || r['status'] == 'rejected') &&
            _selectedIds.contains(r['id']))
        .map((r) => r['id'] as String)
        .toList();

    if (toDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No processed/rejected requests selected')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Processed/Rejected Requests'),
        content: Text('Delete ${toDelete.length} request(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('download_requests')
          .delete()
          .inFilter('id', toDelete);

      setState(() {
        _requests.removeWhere((r) => toDelete.contains(r['id']));
        _selectedIds.removeAll(toDelete.toSet());
        _selectAll = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toDelete.length} requests deleted'), backgroundColor: AppTheme.hkmuGreen),
        );
      }
    } catch (e) {
      debugPrint('Batch delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete requests'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    hintText: 'Search by email or status...',
                    prefixIcon: const Icon(Icons.search, size: 28),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.refresh, size: 36),
                tooltip: 'Refresh',
                color: AppTheme.hkmuGreen,
                padding: const EdgeInsets.all(16),
                onPressed: _loadRequests,
              ),
            ],
          ),

          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever, size: 24),
                    label: const Text('Delete Selected', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: _batchDeleteProcessedOrRejected,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIds.clear();
                      _selectAll = false;
                    }),
                    child: const Text('Clear selection', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
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
                            const Text('Failed to load requests', style: TextStyle(fontSize: 24)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadRequests,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              child: const Text('Retry', style: TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                      )
                    : _requests.isEmpty
                        ? const Center(child: Text('No download requests yet.', style: TextStyle(fontSize: 24)))
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
                                columns: [
                                  DataColumn(
                                    label: Checkbox(
                                      value: _selectAll,
                                      onChanged: _toggleSelectAll,
                                    ),
                                  ),
                                  const DataColumn(label: Text('User Email')),
                                  const DataColumn(label: Text('Models')),
                                  const DataColumn(label: Text('Status')),
                                  const DataColumn(label: Text('Created At')),
                                  const DataColumn(label: Text('Updated At')),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: _filteredRequests.map((req) {
                                  final id = req['id'] as String;
                                  final status = req['status'] as String? ?? 'pending';
                                  final created = DateTime.tryParse(req['created_at'] ?? '') ?? DateTime.now();
                                  final updated = DateTime.tryParse(req['updated_at'] ?? '') ?? DateTime.now();
                                  final isSelected = _selectedIds.contains(id);

                                  Color statusColor;
                                  if (status == 'processed') {
                                    statusColor = Colors.green[700]!;
                                  } else if (status == 'rejected') {
                                    statusColor = Colors.red[700]!;
                                  } else {
                                    statusColor = Colors.orange[800]!;
                                  }

                                  final modelNames = req['model_names'] as List<String>? ?? [];

                                  return DataRow(
                                    color: WidgetStateProperty.resolveWith<Color?>(
                                      (states) => isSelected ? Colors.blue.withValues(alpha: 0.08) : null,
                                    ),
                                    cells: [
                                      DataCell(
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (v) => _toggleSelection(id, v),
                                        ),
                                      ),
                                      DataCell(
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text(req['email'] ?? 'Unknown', style: const TextStyle(fontSize: 18)),
                                        ),
                                      ),
                                      DataCell(
                                        modelNames.isEmpty
                                            ? const Text('—', style: TextStyle(fontSize: 18, color: Colors.grey))
                                            : modelNames.length <= 3
                                                ? Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: modelNames.map((name) {
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                                        child: Text(
                                                          '• $name',
                                                          style: const TextStyle(fontSize: 16.5),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      );
                                                    }).toList(),
                                                  )
                                                : Tooltip(
                                                    message: modelNames.join('\n'),
                                                    child: Text(
                                                      '${modelNames.length} models',
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontStyle: FontStyle.italic,
                                                        color: Colors.blueGrey,
                                                      ),
                                                    ),
                                                  ),
                                      ),
                                      DataCell(
                                        Chip(
                                          label: Text(status.toUpperCase()),
                                          backgroundColor: statusColor,
                                          labelStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                      ),
                                      DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(created), style: const TextStyle(fontSize: 18))),
                                      DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(updated), style: const TextStyle(fontSize: 18))),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (status == 'pending') ...[
                                              IconButton(
                                                icon: SvgPicture.asset(
                                                  'assets/icons/check_circle.svg',
                                                  width: 36,
                                                  height: 36,
                                                  colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                                                ),
                                                tooltip: 'Mark as Processed (downloads ZIP)',
                                                onPressed: () => _updateStatus(id, 'processed'),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.cancel, color: Colors.red, size: 36),
                                                tooltip: 'Reject',
                                                onPressed: () => _updateStatus(id, 'rejected'),
                                              ),
                                            ],
                                            if (status == 'processed' || status == 'rejected')
                                              IconButton(
                                                icon: SvgPicture.asset(
                                                  'assets/icons/delete.svg',
                                                  width: 36,
                                                  height: 36,
                                                  colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                                                ),
                                                tooltip: 'Delete this request',
                                                onPressed: () async {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Delete Request'),
                                                      content: const Text('Are you sure you want to delete this request? This cannot be undone.'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                        TextButton(
                                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmed != true) return;

                                                  try {
                                                    await Supabase.instance.client
                                                        .from('download_requests')
                                                        .delete()
                                                        .eq('id', id);

                                                    setState(() {
                                                      _requests.removeWhere((r) => r['id'] == id);
                                                      _selectedIds.remove(id);
                                                    });

                                                    if (mounted) {
                                                      // ignore: use_build_context_synchronously
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Request deleted successfully'),
                                                          backgroundColor: AppTheme.hkmuGreen,
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      // ignore: use_build_context_synchronously
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Failed to delete request'),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
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