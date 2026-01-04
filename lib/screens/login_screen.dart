// lib/screens/login_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../styles/styles.dart';
import '../core/widgets/header.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App-themed 3D icon
                  Icon(
                    Icons.view_in_ar_outlined,
                    size: 80,
                    color: AppTheme.hkmuGreen,
                  ),
                  const SizedBox(height: 24),

                  // Main title
                  Text(
                    'HKMU 3D Model Hub',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.hkmuGreen,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Important domain hint
                  Text(
                    'Use your HKMU email',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.hkmuGreen,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Sign in or create an account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Email + Password authentication form
                  SupaEmailAuth(
                    redirectTo: kIsWeb ? null : 'io.supabase.hkmumodelhub://login-callback/',
                    onSignInComplete: (response) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Logged in successfully!'),
                          backgroundColor: AppTheme.hkmuGreen,
                        ),
                      );
                    },
                    onSignUpComplete: (response) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Account created! Please check your email to confirm.'),
                          backgroundColor: AppTheme.hkmuGreen,
                        ),
                      );
                    },
                    onError: (dynamic error) {
                      String userMessage = 'An unexpected error occurred. Please try again.';

                      if (error is AuthException) {
                        switch (error.message) {
                          case 'Invalid login credentials':
                            userMessage = 'Incorrect email or password. Please try again.';
                            break;
                          case 'Email not confirmed':
                            userMessage = 'Please check your email and click the confirmation link before signing in.';
                            break;
                          case 'User already registered':
                          case 'duplicate key value violates unique constraint "users_email_key"':
                            userMessage = 'An account with this email already exists. Try signing in instead.';
                            break;
                          case 'Only HKMU email addresses (@live.hkmu.edu.hk or @hkmu.edu.hk) are allowed.':
                            userMessage = 'Only HKMU email addresses are allowed. Please use your @live.hkmu.edu.hk or @hkmu.edu.hk email.';
                            break;
                          case 'Password should be at least 6 characters':
                            userMessage = 'Password must be at least 6 characters long.';
                            break;
                          default:
                            userMessage = 'Authentication error: ${error.message}';
                        }
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(userMessage),
                          backgroundColor: Colors.red[700],
                          duration: const Duration(seconds: 6),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}