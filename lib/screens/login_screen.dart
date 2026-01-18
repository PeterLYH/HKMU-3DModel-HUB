// lib/screens/login_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/styles.dart';
import '../core/widgets/header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isResetMode = false;
  bool _resetEmailSent = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && response.session != null) {
        if (!mounted) return;
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Logged in successfully!'),
            backgroundColor: AppTheme.hkmuGreen,
          ),
        );
      }
    } on AuthException catch (e) {
      String message = 'An authentication error occurred.';

      if (e.message.contains('Invalid login credentials')) {
        message = 'Incorrect email or password.';
      } else if (e.message.contains('Email not confirmed')) {
        message = 'Please confirm your email first.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: kIsWeb
            ? 'https://hkmu-3dmodel-hub.web.app/reset-password'
            : 'io.supabase.hkmumodelhub://login-callback/',
      );

      if (!mounted) return;

      setState(() {
        _resetEmailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'If an account exists with this email, a reset link has been sent.\n'
            'Please check your inbox (including spam/junk folder).',
            textAlign: TextAlign.center,
          ),
          backgroundColor: AppTheme.hkmuGreen,
          duration: const Duration(seconds: 7),
        ),
      );
    } on AuthException catch (e) {
      String message = 'Failed to send reset link. Please try again.';

      if (e.message.contains('rate limit')) {
        message = 'Too many requests. Please wait a few minutes.';
      } else if (e.message.contains('network') || e.message.contains('timeout')) {
        message = 'Network issue. Please check your connection.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send reset email. Try again later.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleResetMode() {
    setState(() {
      _isResetMode = !_isResetMode;
      _resetEmailSent = false;
      // Keep email field value when switching views
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Header(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isResetMode
                    ? _buildResetPasswordView()
                    : _buildLoginView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.view_in_ar_outlined,
            size: 80,
            color: AppTheme.hkmuGreen,
          ),
          const SizedBox(height: 24),
          Text(
            'HKMU 3D Model Hub',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.hkmuGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your HKMU email',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.hkmuGreen,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sign in to continue',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'HKMU Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!v.endsWith('@live.hkmu.edu.hk') && !v.endsWith('@hkmu.edu.hk')) {
                return 'Only HKMU emails allowed';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            onFieldSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _toggleResetMode,
              child: Text(
                'Forgot password?',
                style: TextStyle(color: AppTheme.hkmuGreen),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.hkmuGreen,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/mail.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              AppTheme.hkmuGreen,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            _resetEmailSent ? 'Check Your Email' : 'Reset Password',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.hkmuGreen,
                ),
          ),
          const SizedBox(height: 16),

          if (_resetEmailSent) ...[
            const Text(
              'A reset link has been sent.\n'
              'Please check your inbox.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _toggleResetMode,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.hkmuGreen),
                ),
                child: Text(
                  'Back to Sign In',
                  style: TextStyle(color: AppTheme.hkmuGreen),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Enter your HKMU email to receive a password reset link.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'HKMU Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.endsWith('@live.hkmu.edu.hk') && !v.endsWith('@hkmu.edu.hk')) {
                  return 'Only HKMU emails allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.hkmuGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('SEND RESET LINK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: _toggleResetMode,
              child: Text(
                'Back to Sign In',
                style: TextStyle(color: AppTheme.hkmuGreen),
              ),
            ),
          ],
        ],
      ),
    );
  }
}