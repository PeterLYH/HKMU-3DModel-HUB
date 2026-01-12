// lib/screens/request_success_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/header.dart';
import '../styles/styles.dart';

class RequestSuccessScreen extends StatelessWidget {
  const RequestSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const Header(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom success icon from assets
                SvgPicture.asset(
                  'assets/icons/check_circle.svg',
                  width: 120,
                  height: 120,
                  colorFilter: ColorFilter.mode(
                    AppTheme.hkmuGreen,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Thank You!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.hkmuGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your download request has been successfully submitted.',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'We will prepare the download links and send them to your registered email address as soon as possible.\n\n'
                  'You can now continue browsing our 3D model collection.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: SvgPicture.asset(
                    'assets/icons/home.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: const Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hkmuGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    minimumSize: const Size(280, 56),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}