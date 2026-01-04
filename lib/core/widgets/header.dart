// lib/core/widgets/header.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../styles/styles.dart';

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

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (!mounted) return; // ← Early return if disposed

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
    });

    if (_currentUser != null) {
      _fetchRole();
    } else {
      setState(() => _roleLoading = false);
    }
  }

  Future<void> _fetchRole() async {
    if (_currentUser == null || !mounted) return;

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
          // Clickable App Title → goes to home
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: TextButton(
              onPressed: () => context.go('/'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'HKMU 3D Model Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const Spacer(),

          if (isAdmin)
            TextButton(
              onPressed: () => context.go('/admin'),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Admin Panel',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          if (isAdmin) const SizedBox(width: 24),

          if (!isLoggedIn)
            OutlinedButton(
              onPressed: () => context.go('/login'),
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

                    // ← NOW SAFE: Check mounted before using context
                    if (!mounted) return;

                    // ignore: use_build_context_synchronously
                    context.go('/'); // Redirect to home
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Logged out successfully'),
                        backgroundColor: AppTheme.hkmuGreen,
                      ),
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

          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
              child: Icon(
                isDark ?  Icons.dark_mode : Icons.light_mode,
                key: ValueKey(isDark),
                color: Colors.white,
              ),
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