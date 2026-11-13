import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

import 'package:preferences_service/preferences_service.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final (profile, size, locale, scale, suffix) in const [
    (
      VisualProfile.phone,
      Size(390, 844),
      Locale('en'),
      1.0,
      'phone',
    ),
    (
      VisualProfile.largeText,
      Size(320, 568),
      Locale('de'),
      2.0,
      'small-de',
    ),
    (
      VisualProfile.dark,
      Size(390, 844),
      Locale('ar'),
      2.0,
      'phone-ar-large',
    ),
    (
      VisualProfile.phone,
      Size(800, 1280),
      Locale('en'),
      1.0,
      'tablet',
    ),
  ]) {
    testWidgets('bottom search opens and returns $suffix', (tester) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(
        () => app.preferencesService.update(
          (p) => p.copyWith(
            locale: locale,
            themeMode: profile.brightness == Brightness.light
                ? AppThemeMode.light
                : AppThemeMode.dark,
          ),
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widget),
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'Library with bottom search',
      );
      await tester.pumpAndSettle();
      final reads = app.bookRepository.reads;
      final capsule = find.byKey(const ValueKey('libraryFloatingActions'));
      final initialBounds = tester.getRect(capsule);
      final collections = tester.getCenter(
        find.byKey(const ValueKey('libraryCollectionsButton')),
      );
      final searchButton = tester.getCenter(
        find.byKey(const ValueKey('librarySearchButton')),
      );
      final add = tester.getCenter(
        find.byKey(const ValueKey('libraryCapsuleActionButton')),
      );
      expect(searchButton.dy, closeTo(add.dy, .01));
      expect(
        searchButton.dx,
        inExclusiveRange(
          collections.dx < add.dx ? collections.dx : add.dx,
          collections.dx > add.dx ? collections.dx : add.dx,
        ),
      );
      expect(find.byType(AppTextField), findsNothing);

      await tapUi(tester, find.byKey(const ValueKey('librarySearchButton')));
      final field = find.byKey(const ValueKey('librarySearchField'));
      final editable = tester.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      final controller = tester.widget<AppTextField>(field).controller!;
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'opening Search must attach input without tapping the field',
      );
      expect(find.byType(AppTextField), findsOneWidget);
      await expectUiGolden(tester, profile, 'library-search-empty-$suffix');

      // Widget captures model the inset; native tests verify the real IME.
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      await tester.enterText(field, 'no matching title');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(
        tester.getRect(capsule).bottom,
        lessThanOrEqualTo(size.height - 216 - AppSpacing.lg),
      );
      final noResults = find.text(
        tester.element(field).l10n.libraryNoResultsTitle,
      );
      expect(noResults, findsOneWidget);
      expect(
        tester.getRect(noResults).bottom,
        lessThanOrEqualTo(tester.getRect(capsule).top - AppSpacing.sm),
        reason: 'empty feedback must remain readable above the search capsule',
      );
      await expectUiGolden(tester, profile, 'library-search-keyboard-$suffix');
      await tapUi(
        tester,
        find.byKey(const ValueKey('librarySearchClearButton')),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(controller.text, isEmpty);
      expect(editable.widget.focusNode.hasFocus, isTrue);

      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryCapsuleActionButton')),
      );
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(find.byKey(const ValueKey('librarySearchButton')), findsOneWidget);
      expect(controller.text, isEmpty);
      expect(tester.getRect(capsule), rectMoreOrLessEquals(initialBounds));
      expect(app.bookRepository.reads, reads);
      expect(find.text(ReadingFixture.bookTitle), findsOneWidget);
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
