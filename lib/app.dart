// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'styles/styles.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/model_detail_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void toggleTheme(BuildContext context, ThemeMode newMode) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?._setThemeMode(newMode);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode newMode) {
    setState(() {
      _themeMode = newMode;
    });
  }

  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
        redirect: (context, state) async {
          final user = Supabase.instance.client.auth.currentUser;

          if (user == null) return '/';

          try {
            final response = await Supabase.instance.client
                .from('users')
                .select('role')
                .eq('userid', user.id)
                .single();

            final role = response['role'] as String?;

            return role == 'admin' ? null : '/';
          } catch (e) {
            return '/';
          }
        },
      ),
      GoRoute(
        path: '/upload',
        builder: (context, state) => const UploadScreen(),
        redirect: (context, state) async {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) return '/';

          try {
            final response = await Supabase.instance.client
                .from('users')
                .select('role')
                .eq('userid', user.id)
                .single();

            final role = response['role'] as String?;
            return role == 'admin' ? null : '/';
          } catch (e) {
            return '/';
          }
        },
      ),
      GoRoute(
        path: '/model/:id',
        builder: (context, state) => ModelDetailScreen(
          modelId: state.pathParameters['id']!,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    usePathUrlStrategy(); // Clean URLs: no #

    return MaterialApp.router(
      title: 'HKMU 3D Model Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}