import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _firstLaunchKey = 'readflex_first_launch_done';
const _splashDuration = Duration(milliseconds: 1500);

/// Splash screen shown on app startup.
///
/// Displays the app logo, checks whether this is the first launch,
/// and calls [onFirstLaunch] or [onHome] accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.onFirstLaunch,
    required this.onHome,
    super.key,
  });

  /// Called when the app is launched for the first time.
  final VoidCallback onFirstLaunch;

  /// Called when the app has been launched before.
  final VoidCallback onHome;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = !(prefs.getBool(_firstLaunchKey) ?? false);

    // Ensure the splash is visible for a minimum duration.
    await Future<void>.delayed(_splashDuration);

    if (!mounted) return;

    if (isFirstLaunch) {
      widget.onFirstLaunch();
    } else {
      widget.onHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.materialThemeData.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 72,
              color: theme.materialThemeData.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              'Readflex',
              style: theme.materialThemeData.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.materialThemeData.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
