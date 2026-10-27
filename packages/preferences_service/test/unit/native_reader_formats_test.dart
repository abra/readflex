import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('follows the build until a developer override is saved', () async {
    final service = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(service.dispose);
    expect(service.current.nativeReaderFormats, isNull);

    await service.setNativeReaderFormats(['cbz', 'pdf']);
    expect(service.current.nativeReaderFormats, ['cbz', 'pdf']);

    final reloaded = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(reloaded.dispose);
    expect(reloaded.current.nativeReaderFormats, ['cbz', 'pdf']);
  });

  test('an empty override means every format in the WebView', () async {
    final service = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(service.dispose);
    await service.setNativeReaderFormats([]);
    expect(service.current.nativeReaderFormats, isEmpty);
    final reloaded = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(reloaded.dispose);
    expect(reloaded.current.nativeReaderFormats, isEmpty);
  });

  test('clearing the override follows the build again', () async {
    final service = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(service.dispose);
    await service.setNativeReaderFormats(['pdf']);
    await service.setNativeReaderFormats(null);
    expect(service.current.nativeReaderFormats, isNull);
    final reloaded = await PreferencesService.create(supportedCodes: ['en']);
    addTearDown(reloaded.dispose);
    expect(reloaded.current.nativeReaderFormats, isNull);
  });

  test('copyWith keeps the override unless told otherwise', () {
    const prefs = Preferences(nativeReaderFormats: ['cbz']);
    expect(prefs.copyWith().nativeReaderFormats, ['cbz']);
    expect(
      prefs.copyWith(nativeReaderFormats: null).nativeReaderFormats,
      isNull,
    );
    expect(prefs, const Preferences(nativeReaderFormats: ['cbz']));
    expect(prefs, isNot(const Preferences(nativeReaderFormats: ['pdf'])));
    expect(
      prefs.hashCode,
      const Preferences(nativeReaderFormats: ['cbz']).hashCode,
    );
  });
}
