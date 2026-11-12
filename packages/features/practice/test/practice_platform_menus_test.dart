import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoActionSheet;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/practice_item.dart';
import 'package:practice/src/practice_settings_sheet.dart';
import 'package:practice/src/practice_word_sheet.dart';
import 'package:practice/src/review_session_screen.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform review actions open, dismiss and invoke callbacks', (
      tester,
    ) async {
      var opened = 0;
      var removed = 0;
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          home: ReviewSessionTopBar(
            position: 1,
            total: 2,
            canOpenInSource: true,
            onClose: () {},
            onOpenInSource: () => opened++,
            onRemove: () => removed++,
          ),
        ),
      );
      final menu = find.byKey(const ValueKey('reviewMenu'));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(
        find.byType(CupertinoActionSheet),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(removed, 0);
      for (final action in ['reviewMenuOpen', 'reviewMenuRemove']) {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(action)));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(action)), findsNothing);
        expect(tester.takeException(), isNull);
      }
      expect(opened, 1);
      expect(removed, 1);
    });

    testWidgets('$platform opens settings and persists an actual choice', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final preferences = await PreferencesService.create(
        supportedCodes: ReadflexSupportedLocales.codes,
      );
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        _PracticeMenuHost(
          platform: platform,
          onOpen: (context) => showPracticeSettingsSheet(
            context: context,
            preferencesService: preferences,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      expect(preferences.current.practiceNewCardsPerDay, 10);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeSettingsSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform word details open and return the selected action', (
      tester,
    ) async {
      PracticeWordSheetOutcome? outcome;
      final word = PracticeWordItem(
        entry: DictionaryEntry(
          id: 'word',
          word: 'power',
          translation: 'сила',
          baseTranslation: 'мощность',
          context: 'This power bank provides emergency power.',
          contextTranslation: 'Этот аккумулятор обеспечивает питание.',
          addedAt: DateTime(2026),
        ),
        fsrs: const FsrsCardData(),
      );
      await tester.pumpWidget(
        _PracticeMenuHost(
          platform: platform,
          onOpen: (context) async {
            outcome = await showPracticeWordSheet(
              context,
              word: word,
              canOpenInSource: false,
            );
          },
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(PracticeWordSheet));
      final remove = find.widgetWithText(AppButton, context.l10n.wordUnsave);
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(outcome, PracticeWordSheetOutcome.remove);
      expect(find.byType(PracticeWordSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _PracticeMenuHost extends StatelessWidget {
  const _PracticeMenuHost({required this.platform, required this.onOpen});

  final TargetPlatform platform;
  final Future<void> Function(BuildContext) onOpen;

  @override
  Widget build(BuildContext context) => PlatformTestApp(
    platform: platform,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: readflexLocalizationsDelegates,
    home: Builder(
      builder: (context) => Center(
        child: AppButton(
          onPressed: () => onOpen(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}
