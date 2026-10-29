import 'dart:io';

import 'package:integration_test/integration_test.dart';

import 'native_screenshots.dart';

/// Captures [name] into the device run's artifacts: Android through the
/// driver's adb transport (the binding needs a surface conversion there),
/// iOS through the binding.
Future<void> takeDeviceScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  if (Platform.isAndroid) {
    await captureAndroidScreenshot(name);
  } else {
    await binding.takeScreenshot(name).timeout(const Duration(seconds: 20));
  }
}
