// reset_password_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/styles.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = GoRouter.of(context);
      final currentUri = router.routerDelegate.currentConfiguration.uri;
      if (currentUri.queryParameters.containsKey('error') ||
          currentUri.queryParameters.containsKey('error_code') ||
          currentUri.queryParameters.containsKey('error_description')) {
        router.replace('/reset-password');
        if (currentUri.queryParameters['error_code'] == 'otp_expired' ||
            currentUri.queryParameters['error_description']?.contains('expired') == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The reset link was invalid or expired. '
                'If your password was updated successfully, you can now sign in with it.'
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
      _checkRecoverySession();
    });
  }

  void _checkRecoverySession() {
    final session = supabase.auth.currentSession;
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or expired reset link. Please request a new one.'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/login');
      }
    }
  }

  Future<void> _updatePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showError('Please enter both new password and confirmation');
      return;
    }

    if (newPass != confirmPass) {
      _showError('Passwords do not match');
      return;
    }

    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (response.user != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password updated successfully! Please sign in again.'),
            backgroundColor: AppTheme.hkmuGreen,
            duration: const Duration(seconds: 5),
          ),
        );

        _newPasswordController.clear();
        _confirmPasswordController.clear();

        context.replace('/login');
      }
    } on AuthException catch (e) {
      _showError('Update failed: ${e.message}');
    } catch (e) {
      _showError('An unexpected error occurred. Please try again later.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppTheme.hkmuGreen,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 32),

                      Text(
                        'Set New Password',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.hkmuGreen,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Please enter your new password (minimum 6 characters)',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 40),

                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: SvgPicture.asset(
                              _obscureNewPassword ? 'assets/icons/eye_off.svg' : 'assets/icons/eye.svg',
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurfaceVariant,
                                BlendMode.srcIn,
                              ),
                            ),
                            onPressed: () {
                              setState(() => _obscureNewPassword = !_obscureNewPassword);
                            },
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: SvgPicture.asset(
                              _obscureConfirmPassword ? 'assets/icons/eye_off.svg' : 'assets/icons/eye.svg',
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurfaceVariant,
                                BlendMode.srcIn,
                              ),
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                        ),
                        onFieldSubmitted: (_) => _updatePassword(),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hkmuGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Update Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 32),
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