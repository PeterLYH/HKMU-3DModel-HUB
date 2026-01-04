// lib/core/widgets/header.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app.dart';
import '../../styles/styles.dart';
import '../../screens/login_screen.dart';
import '../../screens/admin_panel_screen.dart';

class Header extends StatefulWidget implements PreferredSizeWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HeaderState extends State<Header> {
  User? _currentUser;
  String _userRole = 'user';
  bool _roleLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = Supabase.instance.client.auth.currentUser;

    // Listen to auth changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
          _roleLoading = true;
        });
        if (_currentUser != null) {
          await _fetchRole();
        } else {
          setState(() {
            _userRole = 'user';
            _roleLoading = false;
          });
        }
      }
    });

    // Initial fetch
    if (_currentUser != null) {
      _fetchRole();
    } else {
      setState(() => _roleLoading = false);
    }
  }

  Future<void> _fetchRole() async {
    if (_currentUser == null) {
      setState(() {
        _userRole = 'user';
        _roleLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('userid', _currentUser!.id)
          .single();

      if (mounted) {
        setState(() {
          _userRole = response['role'] ?? 'user';
          _roleLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'user';
          _roleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLoggedIn = _currentUser != null;
    final bool isAdmin = _userRole == 'admin' && !_roleLoading;

    return AppBar(
      backgroundColor: AppTheme.hkmuGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(
              'HKMU 3D Model Hub',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),

          const Spacer(),

          // Browse
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Browse page coming soon!')),
            ),
            child: const Text('Browse', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ),

          const SizedBox(width: 24),

          // ADMIN PANEL BUTTON — Only show if truly admin
          if (isAdmin)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 20),
                  SizedBox(width: 8),
                  Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          if (isAdmin) const SizedBox(width: 24),

          // Login / User Info
          if (!isLoggedIn)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Text(
                    _currentUser!.email![0].toUpperCase(),
                    style: TextStyle(color: AppTheme.hkmuGreen, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('Logged out successfully'), backgroundColor: AppTheme.hkmuGreen),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),

          const SizedBox(width: 16),

          // Theme Toggle
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
              child: Icon(isDark ? Icons.light_mode : Icons.dark_mode, key: ValueKey(isDark), color: Colors.white),
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              MyApp.toggleTheme(context, isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}