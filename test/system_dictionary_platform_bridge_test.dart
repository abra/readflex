import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS bridge presents the native reference library', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('io.github.abra.readflex/dictionary'));
    expect(source, contains('showDefinition'));
    expect(
      source,
      contains('UIReferenceLibraryViewController.dictionaryHasDefinition'),
    );
    expect(source, contains('UIReferenceLibraryViewController(term: term)'));
  });

  test('Android bridge resolves ACTION_DEFINE before launching it', () {
    final activity = File(
      'android/app/src/main/kotlin/io/github/abra/readflex/MainActivity.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(activity, contains('io.github.abra.readflex/dictionary'));
    expect(activity, contains('Intent(Intent.ACTION_DEFINE)'));
    expect(activity, contains('intent.resolveActivity(packageManager)'));
    expect(activity, contains('Build.VERSION_CODES.Q'));
    expect(manifest, contains('android.intent.action.DEFINE'));
  });
}
