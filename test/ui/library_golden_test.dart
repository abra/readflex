import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_language_sheet.dart';
import 'package:local_storage/local_storage.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final width in [320.0, 390.0, 448.0]) {
    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('compact language grid fits $width / $locale', (
        tester,
      ) async {
        final app = await tester.runAsync(() => UiTestApp.create());
        addTearDown(app!.dispose);
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await app.preferencesService.update((p) => p.copyWith(locale: locale));
        await tester.pumpWidget(app.widget);
        final display = find.byKey(
          const ValueKey('libraryHeaderDisplayButton'),
        );
        await tapUi(tester, display);
        final picker = find.byKey(const ValueKey('libraryLanguagePicker'));
        expect(
          tester.getBottomLeft(find.byType(ActionBottomSheetLayout)).dy -
              tester.getBottomLeft(picker).dy,
          closeTo(AppSpacing.lg, .01),
        );
        final sheetRect = tester.getRect(find.byType(BottomSheet));
        await tapUi(tester, picker);
        final viewport = find.descendant(
          of: find.byType(LibraryLanguageSheet),
          matching: find.byType(SingleChildScrollView),
        );
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: viewport, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.maxScrollExtent, 0);
        final viewportRect = tester.getRect(viewport);
        for (final language in ReadflexSupportedLocales.languages) {
          final option = find.byKey(
            ValueKey('libraryLanguageOption-${language.code}'),
          );
          final rect = tester.getRect(option);
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.top, greaterThanOrEqualTo(viewportRect.top));
          expect(rect.bottom, lessThanOrEqualTo(viewportRect.bottom));
          expect(option.hitTestable(), findsOneWidget);
        }
        expect(tester.getRect(find.byType(BottomSheet)), sheetRect);
        final fades = tester.widgetList<ScrollEdgeFade>(
          find.descendant(
            of: find.byType(LibraryLanguageSheet),
            matching: find.byType(ScrollEdgeFade),
          ),
        );
        expect(fades.every((fade) => !fade.visible), isTrue);
        expect(tester.takeException(), isNull);
        await unmountUi(tester);
      });
    }
  }
  for (final profile in [VisualProfile.phone, VisualProfile.dark]) {
    testWidgets('library list dividers ${profile.name}', (tester) async {
      final app = await tester.runAsync(() => UiTestApp.create());
      addTearDown(app!.dispose);
      await app.database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: 'ui-fixture-second-book',
          title: 'Another Book About Reading',
          filePath: 'second.fb2',
          format: app.book!.format.name,
          addedAt: DateTime(2026, 1, 2).toIso8601String(),
        ),
      );
      await app.preferencesService.update(
        (p) => p.copyWith(libraryLayoutMode: 'list'),
      );
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => LibraryScreen(
          bookRepository: app.bookRepository,
          articleRepository: app.articleRepository,
          collectionRepository: app.collectionRepository,
          preferencesService: app.preferencesService,
          onSourcePressed: (_, {onSourceOpened}) async {},
          onAddPressed: ({required onImported}) async {},
        ),
      );
      await waitForUi(
        tester,
        () => find
            .byKey(const ValueKey('libraryListRowTopDivider'))
            .evaluate()
            .isNotEmpty,
        description: 'library list divider',
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'library-list');
      await unmountUi(tester);
    }, tags: ['golden']);
  }
  for (final profile in VisualProfile.values) {
    testWidgets('library and display ${profile.name}', (tester) async {
      final app = await tester.runAsync(() => UiTestApp.create());
      addTearDown(app!.dispose);
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app.preferencesService.update(
        (p) => p.copyWith(
          locale: profile.locale,
          themeMode: profile.brightness == Brightness.light
              ? ThemeMode.light
              : ThemeMode.dark,
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widget),
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'library ready for snapshot',
      );
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'library-grid');
      final strings = ReadflexLocalizations.of(
        tester.element(find.byType(LibraryScreen)),
      )!;
      final tile = find.byKey(
        ValueKey(
          'library-grid-${(await tester.runAsync(app.bookRepository.getBooks))!.single.id}',
        ),
      );
      await tester.longPressAt(tester.getTopLeft(tile) + const Offset(30, 30));
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'library-selection');
      await tapUi(tester, find.byTooltip(strings.libraryCancelSelection));
      final displayPress = await tester.startGesture(
        tester.getCenter(find.byTooltip(strings.libraryDisplayOptions)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await expectUiGolden(tester, profile, 'library-display-pressed');
      await displayPress.up();
      await tester.pumpAndSettle();
      await expectUiGolden(tester, profile, 'library-display');
      final displayRect = tester.getRect(find.byType(BottomSheet));
      final picker = find.byKey(const ValueKey('libraryLanguagePicker'));
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      expect(picker.hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(ActionBottomSheetLayout)).dy -
            tester.getBottomLeft(picker).dy,
        closeTo(AppSpacing.lg, .01),
        reason: 'Display has only its standard bottom content padding',
      );
      final label = find.descendant(
        of: picker,
        matching: find.text(strings.libraryDisplayLanguage),
      );
      final language = ReadflexSupportedLocales.languages.firstWhere(
        (item) => item.code == profile.locale.languageCode,
      );
      final value = find.descendant(
        of: picker,
        matching: find.text(language.name),
      );
      final isRtl =
          Directionality.of(tester.element(picker)) == TextDirection.rtl;
      final arrow = find.descendant(
        of: picker,
        matching: find.byIcon(
          isRtl ? AppIcons.chevronLeft : AppIcons.chevronRight,
        ),
      );
      final labelRect = tester.getRect(label);
      final valueRect = tester.getRect(value);
      final arrowRect = tester.getRect(arrow);
      // Wrapping follows the measured labels, not a text-scale breakpoint.
      if (valueRect.top >= labelRect.bottom) {
        expect(
          valueRect.top - labelRect.bottom,
          greaterThanOrEqualTo(AppSpacing.sm),
        );
      } else {
        expect(labelRect.center.dy, closeTo(valueRect.center.dy, 1));
        expect(
          isRtl
              ? labelRect.left - valueRect.right
              : valueRect.left - labelRect.right,
          greaterThanOrEqualTo(AppSpacing.md),
        );
      }
      expect(valueRect.center.dy, closeTo(arrowRect.center.dy, 1));
      expect(
        isRtl
            ? valueRect.left - arrowRect.right
            : arrowRect.left - valueRect.right,
        closeTo(AppSpacing.sm, 1),
      );
      if (profile.scale > 1) {
        await expectUiGolden(tester, profile, 'library-display-language');
      }
      await tapUi(tester, picker);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getRect(find.byType(BottomSheet)), displayRect);
      final sheet = find.byType(LibraryLanguageSheet);
      final options = ReadflexSupportedLocales.languages
          .map(
            (item) =>
                find.byKey(ValueKey('libraryLanguageOption-${item.code}')),
          )
          .toList();
      final first = tester.getRect(options[0]);
      final second = tester.getRect(options[1]);
      if (profile.scale == 1) {
        expect(
          second.top,
          first.top,
          reason: 'two columns at normal text size',
        );
        expect(
          isRtl ? second.right < first.left : second.left > first.right,
          isTrue,
        );
        final third = tester.getRect(options[2]);
        expect(third.top, closeTo(first.bottom, .01));
      } else {
        expect(second.top, closeTo(first.bottom, .01));
      }
      for (final option in options) {
        final rect = tester.getRect(option);
        expect(rect.width, greaterThanOrEqualTo(AppSizes.buttonHeight));
        expect(rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
        final text = find.descendant(of: option, matching: find.byType(Text));
        expect(tester.getRect(text).left, greaterThanOrEqualTo(rect.left));
        expect(tester.getRect(text).right, lessThanOrEqualTo(rect.right));
      }
      await expectUiGolden(tester, profile, 'library-language-picker');
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: sheet, matching: find.byType(Scrollable)),
          )
          .position;
      if (profile == VisualProfile.phone || profile == VisualProfile.dark) {
        expect(position.maxScrollExtent, 0);
      }
      if (position.maxScrollExtent > 0) {
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        await expectUiGolden(
          tester,
          profile,
          'library-language-picker-scrolled',
        );
      }
      for (final option in options) {
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget);
        expect(tester.getRect(find.byType(BottomSheet)), displayRect);
      }
      await tapUi(tester, find.byTooltip(strings.commonBack));
      expect(tester.getRect(find.byType(BottomSheet)), displayRect);
      await tapUi(tester, find.byTooltip(strings.commonClose));
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(find.byType(TextField), 'no matching title');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await expectUiGolden(tester, profile, 'library-no-results');
      final clearPress = await tester.startGesture(
        tester.getCenter(find.byTooltip(strings.commonClearSearch)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await expectUiGolden(tester, profile, 'library-search-clear-pressed');
      await clearPress.up();
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
      await unmountUi(tester);
    }, tags: ['golden']);
  }

  testWidgets('library list and search clear on RTL phone', (tester) async {
    final app = await tester.runAsync(() => UiTestApp.create());
    addTearDown(app!.dispose);
    await app.preferencesService.update(
      (p) => p.copyWith(libraryLayoutMode: 'list'),
    );
    await pumpGoldenSurface(
      tester,
      VisualProfile.dark,
      (_) => LibraryScreen(
        bookRepository: app.bookRepository,
        articleRepository: app.articleRepository,
        collectionRepository: app.collectionRepository,
        preferencesService: app.preferencesService,
        onSourcePressed: (_, {onSourceOpened}) async {},
        onAddPressed: ({required onImported}) async {},
      ),
      locale: const Locale('ar'),
    );
    await waitForUi(
      tester,
      () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
      description: 'RTL phone library ready',
    );
    await tester.pumpAndSettle();
    await expectUiGolden(tester, VisualProfile.dark, 'library-list-phone-rtl');
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    final strings = ReadflexLocalizations.of(
      tester.element(find.byType(LibraryScreen)),
    )!;
    final clear = find.byTooltip(strings.commonClearSearch);
    final prefix = find.byIcon(AppIcons.search);
    expect(tester.getCenter(clear).dx, lessThan(tester.getCenter(prefix).dx));
    final gesture = await tester.startGesture(tester.getCenter(clear));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await expectUiGolden(
      tester,
      VisualProfile.dark,
      'library-search-clear-pressed-phone-rtl',
    );
    await gesture.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
    await unmountUi(tester);
  }, tags: ['golden']);
}
