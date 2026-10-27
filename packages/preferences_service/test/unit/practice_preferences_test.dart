import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _supportedCodes = ['en', 'ru'];
const _key = 'app_preferences';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('practice preferences', () {
    test('default to 20 new cards and highlights on', () async {
      final repo = PreferencesRepository(PreferencesStorage());
      final prefs = await repo.load(_supportedCodes);

      expect(prefs.practiceNewCardsPerDay, 20);
      expect(prefs.practiceReviewHighlights, isTrue);
    });

    test('round-trip through storage', () async {
      final storage = PreferencesStorage();
      final repo = PreferencesRepository(storage);
      final prefs = (await repo.load(_supportedCodes)).copyWith(
        practiceNewCardsPerDay: 50,
        practiceReviewHighlights: false,
      );

      await repo.save(prefs);
      final loaded = await PreferencesRepository(storage).load(_supportedCodes);

      expect(loaded.practiceNewCardsPerDay, 50);
      expect(loaded.practiceReviewHighlights, isFalse);
      final stored = jsonDecode((await storage.getString(_key))!) as Map;
      expect(stored['_schemaVersion'], 14);
    });

    test(
      'rejects a negative new-card limit and tolerates missing keys',
      () async {
        final storage = PreferencesStorage();
        await storage.setString(
          _key,
          jsonEncode({'_schemaVersion': 13, 'practiceNewCardsPerDay': -5}),
        );

        final prefs = await PreferencesRepository(
          storage,
        ).load(_supportedCodes);

        expect(prefs.practiceNewCardsPerDay, 0);
        expect(prefs.practiceReviewHighlights, isTrue);
      },
    );

    test('equality covers the practice limits', () {
      const a = Preferences(practiceNewCardsPerDay: 5);
      const b = Preferences(practiceNewCardsPerDay: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const Preferences(practiceNewCardsPerDay: 6)));
      expect(
        const Preferences(practiceReviewHighlights: false),
        isNot(const Preferences()),
      );
    });
  });
}
