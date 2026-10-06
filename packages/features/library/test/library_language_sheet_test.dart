import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_language_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.physicalSize = const Size(600, 1000);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget subject({
    Locale selected = const Locale('en'),
    required ValueChanged<Locale> onSelected,
  }) => MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: LibraryLanguageSheet(
          selectedLocale: selected,
          onSelected: onSelected,
          onClose: () {},
        ),
      ),
    ),
  );

  testWidgets(
    'every language has selectable semantics and the right callback',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        Locale? result;
        await tester.pumpWidget(subject(onSelected: (value) => result = value));
        await tester.pumpAndSettle();
        for (final language in ReadflexSupportedLocales.languages) {
          final option = find.byKey(
            ValueKey('libraryLanguageOption-${language.code}'),
          );
          expect(
            tester.getSemantics(option),
            isSemantics(
              label: language.name,
              isButton: true,
              hasSelectedState: true,
              isSelected: language.code == 'en',
              isInMutuallyExclusiveGroup: true,
              hasTapAction: true,
            ),
          );
          await tester.tap(option);
          expect(result, Locale(language.code));
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('checkmark does not change option geometry', (tester) async {
    await tester.pumpWidget(subject(onSelected: (_) {}));
    await tester.pumpAndSettle();
    List<Rect> geometry() => [
      for (final language in ReadflexSupportedLocales.languages)
        tester.getRect(
          find.byKey(ValueKey('libraryLanguageOption-${language.code}')),
        ),
    ];
    final before = geometry();
    await tester.pumpWidget(
      subject(selected: const Locale('ru'), onSelected: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(geometry(), before);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('libraryLanguageOption-ru')),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing switches columns without losing languages', (
    tester,
  ) async {
    await tester.pumpWidget(subject(onSelected: (_) {}));
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('libraryLanguageOption-en'));
    final second = find.byKey(const ValueKey('libraryLanguageOption-zh'));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(second).dy,
      tester.getBottomLeft(first).dy,
    );
    for (final language in ReadflexSupportedLocales.languages) {
      final option = find.byKey(
        ValueKey('libraryLanguageOption-${language.code}'),
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      expect(option.hitTestable(), findsOneWidget);
      expect(
        tester.getSize(option).height,
        greaterThanOrEqualTo(AppSizes.buttonHeight),
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('option text and checkmark sit on the 24dp gutter with the '
        'title ($locale)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: LibraryLanguageSheet(
                selectedLocale: const Locale('en'),
                onSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rtl = locale.languageCode == 'ar';
      final strings = tester.element(find.byType(LibraryLanguageSheet)).l10n;
      final title = tester.getRect(find.text(strings.libraryDisplayLanguage));
      final english = find.byKey(const ValueKey('libraryLanguageOption-en'));
      final option = tester.getRect(english);
      final label = tester.getRect(find.text('English'));
      final check = tester.getRect(
        find.descendant(of: english, matching: find.byIcon(AppIcons.check)),
      );
      final close = tester.getRect(find.byIcon(AppIcons.close));
      // The first option is in the leading column; the pill bleeds 8dp.
      if (rtl) {
        expect(title.right, 390 - AppSpacing.xl);
        expect(label.right, closeTo(title.right, .01));
        expect(option.right, 390 - AppSpacing.xl + AppSpacing.sm);
        expect(check.left, closeTo(option.left + AppSpacing.sm, .01));
      } else {
        expect(title.left, AppSpacing.xl);
        expect(label.left, closeTo(title.left, .01));
        expect(option.left, AppSpacing.xl - AppSpacing.sm);
        expect(check.right, closeTo(option.right - AppSpacing.sm, .01));
      }
      // The trailing column's checkmark would end where Close's glyph ends.
      final lastOption = tester.getRect(
        find.byKey(const ValueKey('libraryLanguageOption-zh')),
      );
      expect(
        rtl ? lastOption.left : lastOption.right,
        rtl ? close.left - AppSpacing.sm : close.right + AppSpacing.sm,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
