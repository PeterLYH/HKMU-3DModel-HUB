// lib/screens/admin_panel_screen.dart

import 'package:flutter/material.dart';
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
          // Admin Panel Title + Tabs
          Container(
            width: double.infinity,
            color: AppTheme.hkmuGreen,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Admin Panel',
                    style: TextStyle(
                      fontSize: 32,
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
                  labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Users Management'),
                    Tab(text: 'Models Management'),
                  ],
                ),
              ],
            ),
          ),

          // Tab Views
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

// ==================== USERS MANAGEMENT TAB ====================

class UsersManagementTab extends StatefulWidget {
  const UsersManagementTab({super.key});

  @override
  State<UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load users')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _updateUserRole(String userid, String newRole) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'role': newRole})
          .eq('userid', userid);

      _loadUsers(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to $newRole')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update role')),
      );
    }
  }

  Future<void> _deleteUser(String userid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete $email? This cannot be undone.'),
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
      // Delete from auth.users (admin only)
      await Supabase.instance.client.rpc('delete_user', params: {'user_id': userid});

      // Delete from public.users (RLS allows admin)
      await Supabase.instance.client.from('users').delete().eq('userid', userid);

      _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete user')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final email = user['email']?.toLowerCase() ?? '';
      final nickname = user['nickname']?.toLowerCase() ?? '';
      final username = user['username']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return email.contains(query) || nickname.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by email, username or nickname...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // Users Table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nickname', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Joined', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _filteredUsers.map((user) {
                        final userid = user['userid'];
                        final email = user['email'];
                        final role = user['role'];
                        final createdAt = DateTime.parse(user['created_at']);

                        return DataRow(cells: [
                          DataCell(Text(email)),
                          DataCell(Text(user['username'] ?? '-')),
                          DataCell(Text(user['nickname'] ?? '-')),
                          DataCell(
                            DropdownButton<String>(
                              value: role,
                              items: ['user', 'admin']
                                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                  .toList(),
                              onChanged: (newRole) {
                                if (newRole != null && newRole != role) {
                                  _updateUserRole(userid, newRole);
                                }
                              },
                            ),
                          ),
                          DataCell(Text('${createdAt.day}/${createdAt.month}/${createdAt.year}')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(userid, email),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== MODELS MANAGEMENT TAB (Placeholder for now) ====================

class ModelsManagementTab extends StatelessWidget {
  const ModelsManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_in_ar,
            size: 100,
            color: AppTheme.hkmuGreen.withOpacity(0.6),
          ),
          const SizedBox(height: 24),
          Text(
            'Models Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.hkmuGreen,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This section will allow admins to:\n• View all uploaded 3D models\n• Approve/reject models\n• Edit metadata\n• Delete inappropriate content',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}