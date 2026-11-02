import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en'];
const _key = 'app_preferences';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('animation defaults to cover independently of the turn axis', () {
    const preferences = Preferences(
      readerPageTurnStyle: ReaderPageTurnStyle.vertical,
    );
    expect(preferences.readerPageAnimation, ReaderPageAnimation.cover);
    expect(
      preferences.readerAppearance.pageAnimation,
      ReaderPageAnimation.cover,
    );
    expect(
      ReaderAppearancePreferences.defaults.pageAnimation,
      ReaderPageAnimation.cover,
    );
    expect(
      ReaderPageAnimation.fromId('future-effect'),
      ReaderPageAnimation.cover,
    );
    expect(ReaderPageAnimation.tryFromId('future-effect'), isNull);
  });

  test('copying animation updates both preference snapshots by value', () {
    const defaults = Preferences();
    final slide = defaults.copyWith(
      readerPageAnimation: ReaderPageAnimation.slide,
    );
    final appearance = defaults.readerAppearance.copyWith(
      pageAnimation: ReaderPageAnimation.slide,
    );

    expect(slide.readerAppearance, appearance);
    expect(slide, isNot(defaults));
    expect(appearance, isNot(defaults.readerAppearance));
    expect({defaults, slide, slide.copyWith()}, hasLength(2));
    expect({
      defaults.readerAppearance,
      appearance,
      appearance.copyWith(),
    }, hasLength(2));
    expect(slide.readerPageTurnStyle, defaults.readerPageTurnStyle);
  });

  test(
    'legacy source animation is ignored while the turn axis is retained',
    () {
      final override = ReaderAppearanceOverride.fromJson({
        'pageAnimation': 'slide',
        'pageTurnStyle': 'vertical',
      });
      expect(
        override,
        const ReaderAppearanceOverride(
          pageTurnStyle: ReaderPageTurnStyle.vertical,
        ),
      );
      expect(ReaderAppearanceOverride.fromJson(override.toJson()), override);
      expect(override.toJson(), isNot(contains('pageAnimation')));
      expect(
        override.applyTo(ReaderAppearancePreferences.defaults).pageAnimation,
        ReaderPageAnimation.cover,
      );
      expect(override.copyWith(fontId: 'sans').toJson(), {
        'fontId': 'sans',
        'pageTurnStyle': 'vertical',
      });
    },
  );

  test(
    'legacy source animation alone is empty and other source traits survive',
    () {
      final override = ReaderAppearanceOverride.fromJson({
        'pageAnimation': 'cover',
        'fontId': 'sans',
      });
      expect(
        override.withoutValuesMatching(ReaderAppearancePreferences.defaults),
        const ReaderAppearanceOverride(fontId: 'sans'),
      );
      expect(
        ReaderAppearanceOverride.fromJson({'pageAnimation': 'cover'}).isEmpty,
        isTrue,
      );
    },
  );

  for (final value in [
    null,
    '',
    'curl',
    12,
    false,
    <Object?>[],
    <String, Object?>{},
  ]) {
    test('legacy source animation inherits instead of overriding: $value', () {
      final override = ReaderAppearanceOverride.fromJson({
        'pageAnimation': value,
        'fontId': 'sans',
      });
      final base = ReaderAppearancePreferences.defaults.copyWith(
        pageAnimation: ReaderPageAnimation.slide,
      );
      expect(override.toJson(), isNot(contains('pageAnimation')));
      expect(override.applyTo(base).pageAnimation, ReaderPageAnimation.slide);
      expect(override.fontId, 'sans');
    });

    test(
      'unknown global animation falls back without losing other fields: $value',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode({
            '_schemaVersion': 15,
            'readerFontId': 'geist',
            'readerPageTurnStyle': 'vertical',
            'readerPageAnimation': value,
          }),
        );
        final loaded = await PreferencesRepository(
          storage,
        ).load(_supportedCodes);
        expect(loaded.readerPageAnimation, ReaderPageAnimation.cover);
        expect(loaded.readerFontId, 'geist');
        expect(loaded.readerPageTurnStyle, ReaderPageTurnStyle.vertical);
      },
    );
  }

  for (final animation in ReaderPageAnimation.values) {
    for (final axis in ReaderPageTurnStyle.values) {
      test(
        'global animation round-trips and applies to every source: $animation, $axis',
        () async {
          final sourceAxis = axis == ReaderPageTurnStyle.horizontal
              ? ReaderPageTurnStyle.vertical
              : ReaderPageTurnStyle.horizontal;
          final preferences = Preferences(
            readerPageAnimation: animation,
            readerPageTurnStyle: axis,
            readerAppearanceOverrides: {
              'book-a': ReaderAppearanceOverride(
                fontId: 'sans',
                pageTurnStyle: sourceAxis,
              ),
            },
          );
          final storage = PreferencesStorage();
          final repository = PreferencesRepository(storage);
          await repository.save(preferences);
          final stored = jsonDecode((await storage.getString(_key))!) as Map;
          expect(stored['readerPageAnimation'], animation.id);
          expect((stored['readerAppearanceOverrides'] as Map)['book-a'], {
            'fontId': 'sans',
            'pageTurnStyle': sourceAxis.id,
          });
          final loaded = await PreferencesRepository(
            storage,
          ).load(_supportedCodes);
          expect(loaded, preferences);
          expect(
            loaded.effectiveReaderAppearanceFor('book-a').pageAnimation,
            animation,
          );
          expect(
            loaded.effectiveReaderAppearanceFor('book-a').pageTurnStyle,
            sourceAxis,
          );
          expect(
            loaded.effectiveReaderAppearanceFor('book-b').pageAnimation,
            animation,
          );
        },
      );
    }
  }

  test('legacy slide axis does not select the slide animation', () async {
    final storage = PreferencesStorage();
    await storage.setString(
      _key,
      jsonEncode({
        '_schemaVersion': 15,
        'readerPageTurnStyle': 'slide',
        'readerAppearanceOverrides': {
          'book-a': {'pageTurnStyle': 'vertical'},
        },
      }),
    );
    final preferences = await PreferencesRepository(
      storage,
    ).load(_supportedCodes);
    expect(preferences.readerPageTurnStyle, ReaderPageTurnStyle.horizontal);
    expect(preferences.readerPageAnimation, ReaderPageAnimation.cover);
    final appearance = preferences.effectiveReaderAppearanceFor('book-a');
    expect(appearance.pageTurnStyle, ReaderPageTurnStyle.vertical);
    expect(appearance.pageAnimation, ReaderPageAnimation.cover);
  });

  test(
    'service persists global animation and source reset keeps that choice',
    () async {
      final service = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      addTearDown(service.dispose);
      await service.update(
        (preferences) => preferences.copyWith(
          readerPageAnimation: ReaderPageAnimation.slide,
          readerPageTurnStyle: ReaderPageTurnStyle.vertical,
        ),
      );
      await service.setReaderAppearanceOverride(
        'book-a',
        const ReaderAppearanceOverride(fontId: 'sans'),
      );
      final restored = await PreferencesService.create(
        supportedCodes: _supportedCodes,
      );
      addTearDown(restored.dispose);
      expect(
        restored.effectiveReaderAppearanceFor('book-a').pageAnimation,
        ReaderPageAnimation.slide,
      );
      expect(
        restored.effectiveReaderAppearanceFor('book-b').pageAnimation,
        ReaderPageAnimation.slide,
      );
      await restored.clearReaderAppearanceOverride('book-a');
      expect(restored.readerAppearanceOverrideFor('book-a'), isNull);
      expect(
        restored.effectiveReaderAppearanceFor('book-a').pageAnimation,
        ReaderPageAnimation.slide,
      );
      expect(
        restored.current.readerPageTurnStyle,
        ReaderPageTurnStyle.vertical,
      );
      await restored.update(
        (preferences) => preferences.copyWith(
          readerPageAnimation: ReaderPageAnimation.cover,
        ),
      );
      for (final sourceId in ['book-a', 'book-b']) {
        expect(
          restored.effectiveReaderAppearanceFor(sourceId).pageAnimation,
          ReaderPageAnimation.cover,
        );
      }
      expect(restored.readerAppearanceOverrideFor('book-a'), isNull);
    },
  );

  test(
    'loading drops legacy animation-only overrides and keeps other traits',
    () async {
      final storage = PreferencesStorage();
      await storage.setString(
        _key,
        jsonEncode({
          '_schemaVersion': 15,
          'readerPageAnimation': 'slide',
          'readerAppearanceOverrides': {
            'book-a': {'pageAnimation': 'cover'},
            'book-b': {'pageAnimation': 'cover', 'fontId': 'sans'},
          },
        }),
      );
      final preferences = await PreferencesRepository(
        storage,
      ).load(_supportedCodes);
      expect(preferences.readerAppearanceOverrideFor('book-a'), isNull);
      expect(preferences.readerAppearanceOverrides.keys, ['book-b']);
      expect(
        preferences.readerAppearanceOverrideFor('book-b'),
        const ReaderAppearanceOverride(fontId: 'sans'),
      );
      for (final sourceId in ['book-a', 'book-b']) {
        expect(
          preferences.effectiveReaderAppearanceFor(sourceId).pageAnimation,
          ReaderPageAnimation.slide,
        );
      }
    },
  );
}
