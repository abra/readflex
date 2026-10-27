import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/native_reader_formats.dart';

void main() {
  const config = ApplicationConfig();

  test('follows the build when nothing is saved', () {
    expect(
      effectiveNativeReaderFormats(
        config: config,
        preferences: const Preferences(),
      ),
      config.nativeReaderFormats,
    );
  });

  test('a saved override replaces the build setting', () {
    expect(
      effectiveNativeReaderFormats(
        config: config,
        preferences: const Preferences(nativeReaderFormats: ['pdf', 'CBZ']),
      ),
      {BookFormat.pdf, BookFormat.cbz},
    );
    expect(
      effectiveNativeReaderFormats(
        config: config,
        preferences: const Preferences(nativeReaderFormats: []),
      ),
      isEmpty,
    );
    expect(
      effectiveNativeReaderFormats(
        config: config,
        preferences: const Preferences(nativeReaderFormats: ['docx']),
      ),
      isEmpty,
      reason: 'unknown names are ignored, as in the build setting',
    );
  });
}
