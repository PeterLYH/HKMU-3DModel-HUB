//lib/core/widgets/header.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app.dart';
import '../../providers/cart_provider.dart';
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
      if (!mounted) return;

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

  Future<void> _handleChangePassword() async {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(),
                    ),
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
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final old = oldPasswordCtrl.text.trim();
                    final newPass = newPasswordCtrl.text.trim();
                    final confirm = confirmCtrl.text.trim();

                    if (newPass.isEmpty || old.isEmpty) {
                      setDialogState(() => errorMessage = 'All fields are required');
                      return;
                    }

                    if (newPass != confirm) {
                      setDialogState(() => errorMessage = 'Passwords do not match');
                      return;
                    }

                    if (newPass.length < 6) {
                      setDialogState(() => errorMessage = 'Password too short');
                      return;
                    }

                    try {
                      final response = await Supabase.instance.client
                          .rpc('change_password', params: {
                        'current_plain_password': old,
                        'new_plain_password': newPass,
                      });

                      if (response == 'success') {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else if (response == 'incorrect') {
                        setDialogState(() => errorMessage = 'Current password is incorrect');
                      } else {
                        setDialogState(() => errorMessage = 'Something went wrong');
                      }
                    } catch (e) {
                      setDialogState(() => errorMessage = 'Error: $e');
                    }
                  },
                  child: const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );

    oldPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLoggedIn = _currentUser != null;
    final bool isAdmin = _userRole == 'admin' && !_roleLoading;
    final bool showCart = isLoggedIn && !isAdmin;

    final displayName = _currentUser?.email ?? 'User';

    return AppBar(
      automaticallyImplyLeading: false,
      leading: const SizedBox.shrink(),
      backgroundColor: AppTheme.hkmuGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/admin_panel_settings.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (showCart) ...[
            const SizedBox(width: 24),
            Stack(
              children: [
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/shopping_cart.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                  onPressed: () => context.go('/cart'),
                ),
                if (cartProvider.itemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartProvider.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(width: 16),
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
            PopupMenuButton<String>(
              offset: const Offset(0, 50),
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.hkmuGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              onSelected: (value) async {
                if (value == 'change_password') {
                  await _handleChangePassword();
                } else if (value == 'logout') {
                  await Supabase.instance.client.auth.signOut();
                  final cart = Provider.of<CartProvider>(context, listen: false);
                  cart.clearCart();
                  if (!mounted) return;
                  context.go('/');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: AppTheme.hkmuGreen,
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'change_password',
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/password.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white : Colors.black87,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Change Password'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/logout.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white : Colors.black87,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                key: ValueKey(isDark),
                color: Colors.white,
              ),
            ),
            onPressed: () => MyApp.toggleTheme(context, isDark ? ThemeMode.light : ThemeMode.dark),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}