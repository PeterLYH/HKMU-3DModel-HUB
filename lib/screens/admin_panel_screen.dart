// lib/screens/admin_panel_screen.dart

// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures

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
    final bool isMobile = MediaQuery.of(context).size.width < 800;

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
                  isScrollable: isMobile,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight:3,
                  labelPadding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 0,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: isMobile
                      ? const [
                          Tab(text: 'Users'),
                          Tab(text: 'Models'),
                          Tab(text: 'Downloads'),
                        ]
                      : const [
                          Tab(text: 'Users Management'),
                          Tab(text: 'Models Management'),
                          Tab(text: 'Download Requests'),
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
          width: 520,
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
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    border: OutlineInputBorder(),
                  ),
                  items: ['user', 'admin']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                      .toList(),
                  onChanged: (val) => selectedRole = val!,
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
          width: 520,
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
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role *', border: OutlineInputBorder()),
                items: ['user', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
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

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final newPasswordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMessage;
    await showDialog<bool>(
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
                    params: {'p_user_id': user['userid'], 'p_new_password': newPass},
                  );
                  if (res == 'success') {
                    Navigator.pop(ctx, true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Password reset successfully for ${user['email']}'),
                          backgroundColor: AppTheme.hkmuGreen,
                        ),
                      );
                    }
                  } else {
                    setDialogState(() => errorMessage = res.toString());
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
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete selected users'), backgroundColor: Colors.red),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by email, username or nickname...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.person_add, color: Colors.green),
                tooltip: 'Create User',
                onPressed: _createUser,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadUsers,
                color: AppTheme.hkmuGreen,
              ),
            ],
          ),
          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Text('${_selectedUserIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('Delete Selected', style: TextStyle(color: Colors.red)),
                    onPressed: _batchDeleteUsers,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedUserIds.clear();
                      _selectAllUsers = false;
                    }),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(value: _selectAllUsers, onChanged: _toggleSelectAllUsers),
              const Text('Select all'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 80, color: Colors.red),
                            const SizedBox(height: 24),
                            const Text('Failed to load users', style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _loadUsers, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? const Center(child: Text('No users found', style: TextStyle(fontSize: 18)))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              int crossAxisCount = 1;
                              double childAspectRatio = 3.0;

                              if (width > 1600) {
                                crossAxisCount = 4;
                                childAspectRatio = 3.4;
                              } else if (width > 1200) {
                                crossAxisCount = 3;
                                childAspectRatio = 3.1;
                              } else if (width > 800) {
                                crossAxisCount = 2;
                                childAspectRatio = 2.8;
                              }

                              return GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: childAspectRatio,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  final userid = user['userid'] as String;
                                  final email = user['email'] as String;
                                  final username = user['username'] as String?;
                                  final nickname = user['nickname'] as String?;
                                  final role = (user['role'] as String?) ?? 'user';
                                  final createdAt = DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();
                                  final isSelected = _selectedUserIds.contains(userid);

                                  return LayoutBuilder(
                                    builder: (context, cardConstraints) {
                                      final double fontScale = cardConstraints.maxWidth / 380;

                                      return Card(
                                        color: isSelected ? AppTheme.hkmuGreen.withOpacity(0.08) : null,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (v) => _toggleUserSelection(userid, v),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      email,
                                                      style: TextStyle(
                                                        fontSize: 13.5 * fontScale,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (username != null && username.isNotEmpty)
                                                      Text(
                                                        'Username: $username',
                                                        style: TextStyle(fontSize: 11.5 * fontScale),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    if (nickname != null && nickname.isNotEmpty)
                                                      Text(
                                                        'Nickname: $nickname',
                                                        style: TextStyle(fontSize: 11.5 * fontScale),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Chip(
                                                          label: Text(
                                                            role.toUpperCase(),
                                                            style: TextStyle(fontSize: 10 * fontScale),
                                                          ),
                                                          backgroundColor: role == 'admin'
                                                              ? AppTheme.hkmuGreen.withOpacity(0.15)
                                                              : null,
                                                          padding: EdgeInsets.symmetric(horizontal: 6 * fontScale),
                                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          DateFormat('dd/MM/yyyy').format(createdAt),
                                                          style: TextStyle(
                                                            fontSize: 11 * fontScale,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                                    iconSize: 20 * fontScale,
                                                    onPressed: () => _editUser(user),
                                                  ),
                                                  IconButton(
                                                    icon: SvgPicture.asset(
                                                    'assets/icons/lock_reset.svg',
                                                    colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                                                    width: 20 * fontScale,
                                                    height: 20 * fontScale,
                                                  ),
                                                    onPressed: () => _resetPassword(user),
                                                  ),
                                                  IconButton(
                                                    icon: SvgPicture.asset(
                                                    'assets/icons/delete.svg',
                                                    colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                                                    width: 20 * fontScale,
                                                    height: 20 * fontScale,
                                                  ),
                                                    iconSize: 20 * fontScale,
                                                    onPressed: () => _deleteUser(userid, email),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
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
  final Set<String> _selectedModelIds = {};
  bool _selectAllModels = false;
  bool _isCreatingZip = false;
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

  void _toggleSelectAllModels(bool? value) {
    setState(() {
      _selectAllModels = value ?? false;
      if (_selectAllModels) {
        _selectedModelIds.addAll(_filteredModels.map((m) => m['id'] as String));
      } else {
        _selectedModelIds.clear();
      }
    });
  }

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

  Future<void> _batchDeleteModels() async {
    if (_selectedModelIds.isEmpty) return;
    final count = _selectedModelIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Models'),
        content: Text('Are you sure you want to permanently delete $count model(s)?\nThis action cannot be undone.'),
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
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete selected models'), backgroundColor: Colors.red),
        );
      }
    }
  }

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

    setState(() => _isCreatingZip = true);

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

      final bytes = response.bodyBytes;
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B || bytes[2] != 0x03 || bytes[3] != 0x04) {
        throw 'Response does not appear to be a valid ZIP file';
      }

      final blob = html.Blob([bytes], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'models-${DateTime.now().toIso8601String().substring(0, 10)}.zip')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded ${filePaths.length} models as ZIP file'),
          backgroundColor: AppTheme.hkmuGreen,
        ),
      );

      setState(() {
        _selectedModelIds.clear();
        _selectAllModels = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create ZIP: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingZip = false);
      }
    }
  }

  Future<void> _editModel(Map<String, dynamic> model) async {
    final nameController = TextEditingController(text: model['name']);
    final descController = TextEditingController(text: model['description'] ?? '');
    final sourceController = TextEditingController(text: model['source'] ?? 'HKMU');
    final licenseController = TextEditingController(text: model['license_type'] ?? 'Non-commercial');
    final ackController = TextEditingController(text: model['acknowledgement'] ?? '');

    List<Map<String, dynamic>> allCategories = [];
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name', ascending: true);
      allCategories = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e'), backgroundColor: Colors.red),
        );
      }
    }

    final currentCats = (model['categories'] as List<dynamic>?)?.cast<String>() ?? [];
    final Set<int> selectedCategoryIds = {};
    for (final cat in allCategories) {
      final catName = cat['name'] as String;
      final catId = cat['id'] as int;
      if (currentCats.contains(catName)) {
        selectedCategoryIds.add(catId);
      }
    }

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
            width: 600,
            height: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['glb', 'gltf', 'obj', 'fbx', 'stl', 'blend', 'zip'],
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
                    label: Text(newThumbnailFileName ?? 'Replace Thumbnail'),
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
                      child: Image.memory(newThumbnailFile!.bytes!, height: 220, fit: BoxFit.cover),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        Supabase.instance.client.storage.from('3d-models').getPublicUrl(model['thumbnail_path']),
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 220,
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
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: sourceController.text.isEmpty ? 'HKMU' : sourceController.text,
                    decoration: const InputDecoration(labelText: 'Source', border: OutlineInputBorder()),
                    items: const ['HKMU', 'Purchased', 'Vendor']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) sourceController.text = v;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: licenseController.text.isEmpty ? 'Non-commercial' : licenseController.text,
                    decoration: const InputDecoration(labelText: 'License / Usage', border: OutlineInputBorder()),
                    items: const ['Non-commercial', 'Commercial']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) licenseController.text = v;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ackController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Acknowledgement / Credits', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (allCategories.isEmpty)
                    const Text('No categories available', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allCategories.map((cat) {
                        final catId = cat['id'] as int;
                        final catName = cat['name'] as String;
                        final isSelected = selectedCategoryIds.contains(catId);
                        return FilterChip(
                          label: Text(catName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedCategoryIds.add(catId);
                              } else {
                                selectedCategoryIds.remove(catId);
                              }
                            });
                          },
                          selectedColor: AppTheme.hkmuGreen.withOpacity(0.3),
                          checkmarkColor: AppTheme.hkmuGreen,
                          backgroundColor: Colors.grey[200],
                        );
                      }).toList(),
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
      final selectedNames = allCategories
          .where((cat) => selectedCategoryIds.contains(cat['id'] as int))
          .map((cat) => cat['name'] as String)
          .toList();

      Map<String, dynamic> updates = {
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
        'source': sourceController.text,
        'license_type': licenseController.text,
        'acknowledgement': ackController.text.trim().isEmpty ? null : ackController.text.trim(),
        'categories': selectedNames,
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
      html.AnchorElement(href: signedUrl)
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
      final name = model['name']?.toString().toLowerCase() ?? '';
      final fileType = model['file_type']?.toString().toLowerCase() ?? '';
      final cats = (model['categories'] as List?)?.cast<String>() ?? [];
      final catString = cats.join(' ').toLowerCase();
      return name.contains(query) || fileType.contains(query) || catString.contains(query);
    }).toList();
  }

  String getThumbnailUrl(String path) {
    return Supabase.instance.client.storage.from('3d-models').getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double textScale = isMobile ? 1.18 : 1.05;
    final double cardAspect = isMobile ? 0.70 : 0.78;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search by name, category, or file type...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'Upload New Model',
                    color: AppTheme.hkmuGreen,
                    onPressed: () => context.go('/upload'),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    color: AppTheme.hkmuGreen,
                    onPressed: _loadModels,
                  ),
                ],
              ),
              if (_selectedModelIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedModelIds.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.archive, color: Colors.teal),
                        label: const Text('Download as ZIP', style: TextStyle(color: Colors.teal)),
                        onPressed: _isCreatingZip ? null : _batchDownloadAsZip,
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('Delete Selected', style: TextStyle(color: Colors.red)),
                        onPressed: _batchDeleteModels,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedModelIds.clear();
                          _selectAllModels = false;
                        }),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _selectAllModels,
                    onChanged: _toggleSelectAllModels,
                  ),
                  const Text('Select all'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                                const SizedBox(height: 24),
                                const Text('Failed to load models', style: TextStyle(fontSize: 20)),
                                const SizedBox(height: 16),
                                OutlinedButton(onPressed: _loadModels, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _filteredModels.isEmpty
                            ? const Center(child: Text('No models found', style: TextStyle(fontSize: 18)))
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  int crossAxisCount = 1;
                                  if (width > 1400) crossAxisCount = 4;
                                  else if (width > 1000) crossAxisCount = 3;
                                  else if (width > 680) crossAxisCount = 2;
                                  return GridView.builder(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: cardAspect,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: isMobile ? 24 : 20,
                                    ),
                                    itemCount: _filteredModels.length,
                                    itemBuilder: (context, index) {
                                      final model = _filteredModels[index];
                                      final id = model['id'];
                                      final name = model['name'] ?? 'Untitled';
                                      final fileType = (model['file_type'] as String?)?.toUpperCase() ?? '—';
                                      final uploaderEmail = model['uploader_email'] ?? 'Unknown';
                                      final createdAt = DateTime.tryParse(model['created_at'] ?? '') ?? DateTime.now();
                                      final cats = (model['categories'] as List?)?.cast<String>() ?? [];
                                      final displayCats = cats.isEmpty ? '—' : cats.join(', ');
                                      final isSelected = _selectedModelIds.contains(id);
                                      return Card(
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        clipBehavior: Clip.antiAlias,
                                        color: isSelected ? AppTheme.hkmuGreen.withOpacity(0.08) : null,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                              child: Row(
                                                children: [
                                                  Checkbox(
                                                    value: isSelected,
                                                    onChanged: (v) => _toggleModelSelection(id, v),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 17 * textScale,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Image.network(
                                                getThumbnailUrl(model['thumbnail_path']),
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: Colors.grey[850],
                                                  child: const Center(
                                                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.all(isMobile ? 16.0 : 12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayCats,
                                                    style: TextStyle(
                                                      fontSize: 15.5 * textScale,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      height: 1.35,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    fileType,
                                                    style: TextStyle(
                                                      color: AppTheme.hkmuGreen,
                                                      fontSize: 15 * textScale,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            uploaderEmail,
                                                            style: TextStyle(
                                                              fontSize: 14.5 * textScale,
                                                              color: theme.colorScheme.onSurfaceVariant,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            DateFormat('dd/MM/yy').format(createdAt),
                                                            style: TextStyle(
                                                              fontSize: 13.5 * textScale,
                                                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.75),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                                            tooltip: 'Edit',
                                                            onPressed: () => _editModel(model),
                                                          ),
                                                          IconButton(
                                                            icon: SvgPicture.asset(
                                                              'assets/icons/download.svg',
                                                              colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                                                              width: 26,
                                                              height: 26,
                                                            ),
                                                            tooltip: 'Download',
                                                            onPressed: () => _downloadModel(model),
                                                          ),
                                                          IconButton(
                                                            icon: SvgPicture.asset(
                                                              'assets/icons/delete.svg',
                                                              colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                                                              width: 26,
                                                              height: 26,
                                                            ),
                                                            tooltip: 'Delete',
                                                            onPressed: () => _deleteModel(model),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
        if (_isCreatingZip)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Creating ZIP file...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
  final Map<String, bool> _processingRequests = {};

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
          .select('''
            id,
            user_id,
            email,
            model_ids,
            status,
            created_at,
            updated_at,
            description,
            processed_by,
            reject_reason
          ''')
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
      return [];
    }
  }

  Future<String> _getUserDisplayName(String userId, String fallbackEmail) async {
    String displayName = 'User';

    if (userId.isEmpty) {
      if (fallbackEmail.isNotEmpty && fallbackEmail.contains('@')) {
        final prefix = fallbackEmail.split('@').first.trim();
        if (prefix.isNotEmpty) displayName = prefix;
      }
      return displayName;
    }

    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('nickname, username, email')
          .eq('userid', userId)
          .maybeSingle();

      if (userData != null) {
        final nickname = userData['nickname'] as String?;
        if (nickname != null && nickname.trim().isNotEmpty) {
          return nickname.trim();
        }

        final username = userData['username'] as String?;
        if (username != null && username.trim().isNotEmpty) {
          return username.trim();
        }

        final dbEmail = userData['email'] as String?;
        if (dbEmail != null && dbEmail.contains('@')) {
          final prefix = dbEmail.split('@').first.trim();
          if (prefix.isNotEmpty) {
            return prefix;
          }
        }
      }
    } catch (_) {}

    if (fallbackEmail.isNotEmpty && fallbackEmail.contains('@')) {
      final prefix = fallbackEmail.split('@').first.trim();
      if (prefix.isNotEmpty) {
        displayName = prefix;
      }
    }

    return displayName;
  }

  Future<void> _updateStatus(
    String id,
    String newStatus, {
    String? rejectReason,
  }) async {
    if (_processingRequests[id] == true) return;
    setState(() {
      _processingRequests[id] = true;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw 'Not authenticated';

      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
        'processed_by': currentUser.id,
      };
      if (newStatus == 'rejected') {
        updateData['reject_reason'] = rejectReason?.isNotEmpty == true ? rejectReason : null;
      }

      await Supabase.instance.client
          .from('download_requests')
          .update(updateData)
          .eq('id', id);

      final req = _requests.firstWhere((r) => r['id'] == id);

      final userId = req['user_id'] as String? ?? '';
      final reqEmail = req['email'] as String? ?? '';

      final displayName = await _getUserDisplayName(userId, reqEmail);

      String message = newStatus == 'processed'
          ? 'Request processed'
          : 'Request rejected${rejectReason?.isNotEmpty == true ? ' with reason' : ''}';

      bool actionSuccess = true;

      if (newStatus == 'processed') {
        final filePaths = await _getModelFilePaths(id);
        if (filePaths.isNotEmpty) {
          try {
            final session = Supabase.instance.client.auth.currentSession;
            if (session == null) throw 'No active session';

            final response = await http.post(
              Uri.parse('https://mygplwghoudapvhdcrke.supabase.co/functions/v1/zip-models'),
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'filePaths': filePaths}),
            );

            if (response.statusCode == 200) {
              final bytes = response.bodyBytes;

              if (bytes.length >= 4 &&
                  bytes[0] == 0x50 &&
                  bytes[1] == 0x4B &&
                  bytes[2] == 0x03 &&
                  bytes[3] == 0x04) {
                final blob = html.Blob([bytes], 'application/zip');
                final url = html.Url.createObjectUrlFromBlob(blob);

                final fileName =
                    'hkmu-request-$id-${DateTime.now().toIso8601String().substring(0, 10)}.zip';

                html.AnchorElement(href: url)
                  ..setAttribute('download', fileName)
                  ..style.display = 'none'
                  ..click();

                html.Url.revokeObjectUrl(url);

                message += ' – ZIP downloaded (${filePaths.length} models)';
              } else {
                message += ' – ZIP created but invalid format';
                actionSuccess = false;
              }
            } else {
              message += ' – ZIP creation failed (${response.statusCode})';
              actionSuccess = false;
            }
          } catch (zipErr) {
            message += ' – ZIP error';
            actionSuccess = false;
          }
        } else {
          message += ' – no files available';
          actionSuccess = false;
        }
      } else if (newStatus == 'rejected') {
        try {
          final edgeResponse = await http.post(
            Uri.parse('https://mygplwghoudapvhdcrke.supabase.co/functions/v1/send-request-status-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'toEmail': req['email'] as String? ?? 'unknown@email.com',
              'userName': displayName,
              'status': newStatus,
              'rejectReason': rejectReason,
              'modelNames': (req['model_names'] as List?)?.cast<String>() ?? [],
            }),
          );

          actionSuccess = edgeResponse.statusCode == 200;
          message += actionSuccess ? ' – email sent' : ' – email failed';
        } catch (_) {
          actionSuccess = false;
          message += ' – email failed';
        }
      }

      setState(() {
        req['status'] = newStatus;
        req['updated_at'] = DateTime.now().toIso8601String();
        req['processed_by'] = currentUser.id;
        if (newStatus == 'rejected') {
          req['reject_reason'] = rejectReason;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: actionSuccess ? AppTheme.hkmuGreen : Colors.orange[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests.remove(id);
        });
      }
    }
  }

  Future<void> _batchDeleteProcessedOrRejected() async {
    final toDelete = _filteredRequests
        .where((r) => _selectedIds.contains(r['id'] as String))
        .where((r) => r['status'] == 'processed' || r['status'] == 'rejected')
        .map((r) => r['id'] as String)
        .toList();

    if (toDelete.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No processed or rejected requests selected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

    if (confirmed != true || !mounted) return;

    setState(() {
      for (final id in toDelete) {
        _processingRequests[id] = true;
      }
    });

    try {
      await Supabase.instance.client
          .from('download_requests')
          .delete()
          .inFilter('id', toDelete);

      setState(() {
        _requests.removeWhere((r) => toDelete.contains(r['id'] as String));
        _selectedIds.removeAll(toDelete.toSet());
        _selectAll = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${toDelete.length} requests deleted successfully'),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          for (final id in toDelete) {
            _processingRequests.remove(id);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double basePadding = isMobile ? 16.0 : 24.0;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(basePadding),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: TextStyle(fontSize: isMobile ? 17 : 16),
                      decoration: InputDecoration(
                        hintText: 'Search by email or status...',
                        hintStyle: TextStyle(fontSize: isMobile ? 16 : 15),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isMobile ? 14 : 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _loadRequests,
                    color: AppTheme.hkmuGreen,
                    iconSize: 28,
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
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: Text(
                          'Delete Selected',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 15,
                            color: Colors.red,
                          ),
                        ),
                        onPressed: _batchDeleteProcessedOrRejected,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _selectedIds.clear();
                          _selectAll = false;
                        }),
                        child: Text(
                          'Clear',
                          style: TextStyle(fontSize: isMobile ? 16 : 15),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: _toggleSelectAll,
                  ),
                  Text(
                    'Select all',
                    style: TextStyle(fontSize: isMobile ? 17 : 16),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                                const SizedBox(height: 24),
                                Text(
                                  'Failed to load requests',
                                  style: TextStyle(fontSize: isMobile ? 24 : 22),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _loadRequests,
                                  child: Text(
                                    'Retry',
                                    style: TextStyle(fontSize: isMobile ? 17 : 16),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _requests.isEmpty
                            ? Text(
                                'No download requests yet.',
                                style: TextStyle(fontSize: isMobile ? 22 : 20),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  int crossAxisCount = 1;
                                  double childAspectRatio = isMobile ? 1.05 : 1.25;

                                  if (width > 1600) {
                                    crossAxisCount = 4;
                                    childAspectRatio = 1.35;
                                  } else if (width > 1200) {
                                    crossAxisCount = 3;
                                    childAspectRatio = 1.32;
                                  } else if (width > 800) {
                                    crossAxisCount = 2;
                                    childAspectRatio = 1.28;
                                  }

                                  return GridView.builder(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: childAspectRatio,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 20,
                                    ),
                                    itemCount: _filteredRequests.length,
                                    itemBuilder: (context, index) {
                                      final req = _filteredRequests[index];
                                      final id = req['id'] as String;
                                      final email = req['email'] as String? ?? 'Unknown';
                                      final status = req['status'] as String? ?? 'pending';
                                      final description = (req['description'] as String? ?? '—').trim();
                                      final modelNames = (req['model_names'] as List?)?.cast<String>() ?? [];
                                      final createdAt = DateTime.tryParse(req['created_at'] ?? '') ?? DateTime.now();
                                      final isSelected = _selectedIds.contains(id);
                                      final isProcessing = _processingRequests[id] == true;

                                      Color statusColor = status == 'processed'
                                          ? Colors.green[700]!
                                          : status == 'rejected'
                                              ? Colors.red[700]!
                                              : Colors.orange[800]!;

                                      return LayoutBuilder(
                                        builder: (context, cardConstraints) {
                                          final double baseCardWidth = 420.0;
                                          final double scale = (cardConstraints.maxWidth / baseCardWidth).clamp(0.75, 1.45);

                                          return Card(
                                            color: isSelected ? AppTheme.hkmuGreen.withOpacity(0.08) : null,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 2,
                                            child: Padding(
                                              padding: EdgeInsets.all(isMobile ? 16 : 12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Checkbox(
                                                        value: isSelected,
                                                        onChanged: isProcessing ? null : (v) => _toggleSelection(id, v),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          email,
                                                          style: TextStyle(
                                                            fontSize: 17 * scale,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Chip(
                                                    label: Text(status.toUpperCase()),
                                                    backgroundColor: statusColor,
                                                    labelStyle: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13 * scale,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Requested: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                                                    style: TextStyle(
                                                      fontSize: 13.5 * scale,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  if (modelNames.isNotEmpty) ...[
                                                    Text(
                                                      'Models (${modelNames.length}):',
                                                      style: TextStyle(
                                                        fontSize: 14.5 * scale,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      modelNames.length <= 4
                                                          ? modelNames.join(', ')
                                                          : '${modelNames.length} models',
                                                      style: TextStyle(fontSize: 13.5 * scale),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                  if (description != '—') ...[
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Reason:',
                                                      style: TextStyle(
                                                        fontSize: 15 * scale,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      description,
                                                      style: TextStyle(fontSize: 13.5 * scale),
                                                      maxLines: 3,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      if (status == 'pending') ...[
                                                        IconButton(
                                                          icon: SvgPicture.asset(
                                                            'assets/icons/check_circle.svg',
                                                            colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                                                            width: 28 * scale,
                                                            height: 28 * scale,
                                                          ),
                                                          tooltip: 'Mark as Processed',
                                                          onPressed: isProcessing ? null : () => _updateStatus(id, 'processed'),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(Icons.cancel, color: Colors.red),
                                                          iconSize: 28 * scale,
                                                          tooltip: 'Reject',
                                                          onPressed: isProcessing ? null : () async {
                                                            final reasonCtrl = TextEditingController();
                                                            final confirmed = await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                title: const Text('Reject Request'),
                                                                content: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Text('Reason for rejection:'),
                                                                    const SizedBox(height: 12),
                                                                    TextField(
                                                                      controller: reasonCtrl,
                                                                      minLines: 3,
                                                                      maxLines: 5,
                                                                      decoration: const InputDecoration(
                                                                        border: OutlineInputBorder(),
                                                                        filled: true,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(ctx, false),
                                                                    child: const Text('Cancel'),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(ctx, true),
                                                                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirmed == true && mounted) {
                                                              await _updateStatus(id, 'rejected', rejectReason: reasonCtrl.text.trim());
                                                            }
                                                          },
                                                        ),
                                                      ],
                                                      if (status == 'processed' || status == 'rejected')
                                                        IconButton(
                                                          icon: SvgPicture.asset(
                                                            'assets/icons/delete.svg',
                                                            colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                                                            width: 28 * scale,
                                                            height: 28 * scale,
                                                          ),
                                                          tooltip: 'Delete',
                                                          onPressed: isProcessing ? null : () async {
                                                            final confirmed = await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                title: const Text('Delete Request'),
                                                                content: const Text('This cannot be undone.'),
                                                                actions: [
                                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(ctx, true),
                                                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirmed == true && mounted) {
                                                              try {
                                                                await Supabase.instance.client
                                                                    .from('download_requests')
                                                                    .delete()
                                                                    .eq('id', id);
                                                                setState(() {
                                                                  _requests.removeWhere((r) => r['id'] == id);
                                                                  _selectedIds.remove(id);
                                                                  _selectAll = false;
                                                                });
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  const SnackBar(content: Text('Request deleted'), backgroundColor: AppTheme.hkmuGreen),
                                                                );
                                                              } catch (e) {
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  const SnackBar(content: Text('Failed to delete'), backgroundColor: Colors.red),
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
        if (_processingRequests.isNotEmpty || _loading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}