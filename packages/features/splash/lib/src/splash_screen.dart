import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

const _splashDuration = Duration(milliseconds: 1500);

/// Splash screen shown on app startup.
///
/// Displays the app logo for a minimum duration, then calls [onReady].
/// Navigation logic (first launch vs returning user) lives in the router.
class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onReady, super.key});

  /// Called after the splash duration elapses.
  final VoidCallback onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _waitAndProceed();
  }

  Future<void> _waitAndProceed() async {
    await Future<void>.delayed(_splashDuration);
    if (!mounted) return;
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('SplashScreen');

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 72,
              color: context.colors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Readflex',
              style: context.text.headlineLarge.copyWith(
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
