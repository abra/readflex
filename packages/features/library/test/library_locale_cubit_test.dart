import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_locale_cubit.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferencesService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ['en', 'ru'],
    );
  });

  tearDown(() async {
    await preferencesService.dispose();
  });

  test('persists selected locale', () async {
    final cubit = LibraryLocaleCubit(preferencesService: preferencesService);
    addTearDown(cubit.close);

    await cubit.setLocale(const Locale('ru'));

    expect(cubit.state, const Locale('ru'));
    expect(preferencesService.current.locale, const Locale('ru'));
  });
}
