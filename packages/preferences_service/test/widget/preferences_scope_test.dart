import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en', 'ru'];

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('themeModeOf rebuilds independently from reader appearance', (
    tester,
  ) async {
    final service = await PreferencesService.create(
      supportedCodes: _supportedCodes,
    );

    var themeBuilds = 0;
    var readerBuilds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PreferencesScope(
          service: service,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  themeBuilds++;
                  final themeMode = PreferencesScope.themeModeOf(context);
                  return Text('theme:${themeMode.name}');
                },
              ),
              Builder(
                builder: (context) {
                  readerBuilds++;
                  final appearance = PreferencesScope.readerAppearanceOf(
                    context,
                  );
                  return Text('reader:${appearance.fontId}');
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(themeBuilds, 1);
    expect(readerBuilds, 1);

    await service.update(
      (prefs) => prefs.copyWith(
        readerFontId: 'geist',
        readerThemeId: 'night',
        readerTextScale: 1.2,
        readerLineHeight: 1.8,
      ),
    );
    await tester.pumpAndSettle();

    expect(themeBuilds, 1);
    expect(readerBuilds, 2);

    await service.update((prefs) => prefs.copyWith(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    expect(themeBuilds, 2);
    expect(readerBuilds, 2);
  });

  testWidgets('of rebuilds for any preferences change', (tester) async {
    final service = await PreferencesService.create(
      supportedCodes: _supportedCodes,
    );

    var builds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PreferencesScope(
          service: service,
          child: Builder(
            builder: (context) {
              builds++;
              final prefs = PreferencesScope.of(context);
              return Text(
                '${prefs.themeMode.name}-${prefs.readerThemeId}-${prefs.locale.languageCode}',
              );
            },
          ),
        ),
      ),
    );

    expect(builds, 1);

    await service.update(
      (prefs) => prefs.copyWith(locale: const Locale('ru')),
    );
    await tester.pumpAndSettle();

    expect(builds, 2);
  });
}
