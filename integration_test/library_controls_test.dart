import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../test/support/native_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    binding.reportData ??= {};
    binding.reportData!.addAll({
      'platform': Platform.operatingSystem,
      'tests': binding.results.map(
        (name, value) => MapEntry(name, value.toString()),
      ),
    });
  });

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 350));
    if (Platform.isAndroid) {
      await captureAndroidScreenshot(name);
    } else {
      await binding.takeScreenshot(name);
    }
  }

  void expectSheetCloseAlignment(WidgetTester tester) {
    final sheet = find.byType(BottomSheet).last;
    final header = find.ancestor(
      of: find.widgetWithIcon(AppPlainIconButton, AppIcons.close).hitTestable(),
      matching: find.byType(BottomSheetHeader),
    );
    final icon = tester.getRect(
      find.descendant(of: header, matching: find.byIcon(AppIcons.close)),
    );
    final button = tester.getRect(
      find.descendant(
        of: header,
        matching: find.widgetWithIcon(AppPlainIconButton, AppIcons.close),
      ),
    );
    expect(
      tester.getRect(sheet).right - icon.right,
      closeTo(AppSpacing.xl, .01),
    );
    expect(button.size, const Size(48, 48));
  }

  testWidgets('native import menu closes and opens both import paths', (
    tester,
  ) async {
    final app = await UiTestApp.create();
    addTearDown(app.dispose);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    final add = find.byType(FloatingActionButton);
    await tapUi(tester, add);
    await capture(tester, 'import-menu');
    expectSheetCloseAlignment(tester);
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    final menuRect = tester.getRect(find.byType(ActionBottomSheetLayout));
    final menuTitleTop =
        tester.getTopLeft(find.text('Add to Library')).dy - sheetRect.top;
    final articleRect = tester.getRect(
      find.byKey(const ValueKey('importMenu-article')),
    );
    expect(
      menuRect.bottom - articleRect.bottom,
      lessThanOrEqualTo(AppSpacing.lg + AppSpacing.xl),
    );
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    app.connectivityService.setStatus(ConnectivityStatus.offline);
    await waitForUi(
      tester,
      () => find.byIcon(AppIcons.offline).evaluate().isNotEmpty,
      description: 'offline import menu',
    );
    await tapUi(tester, find.byKey(const ValueKey('importMenu-article')));
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: 'only Library search, no URL form',
    );
    expect(find.text('Add to Library'), findsOneWidget);
    await capture(tester, 'import-menu-offline');
    app.connectivityService.setStatus(ConnectivityStatus.online);
    await waitForUi(
      tester,
      () => find.byIcon(AppIcons.link).evaluate().isNotEmpty,
      description: 'online import menu',
    );

    await tapUi(tester, find.byKey(const ValueKey('importMenu-article')));
    expect(find.byKey(const ValueKey('articleUrlPasteButton')), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), sheetRect);
    expect(
      tester.getTopLeft(find.text('Save Article')).dy - sheetRect.top,
      closeTo(menuTitleTop, .5),
    );
    expect(
      tester
              .getTopLeft(
                find.text('Creates a clean article for offline reading.'),
              )
              .dy -
          tester.getRect(find.byType(TextField).last).bottom,
      greaterThanOrEqualTo(AppSpacing.sm),
      reason: 'hints stay separated from the reserved validation area',
    );
    expect(
      tester.getTopLeft(find.widgetWithText(FilledButton, 'Save')).dy -
          tester.getRect(find.text('Adds it to your Library.')).bottom,
      closeTo(AppSpacing.sm, .5),
      reason: 'the hint group sits next to the action buttons',
    );
    await capture(tester, 'import-article-entry');
    expectSheetCloseAlignment(tester);
    expect(find.text('Back'), findsNothing);
    await tapUi(tester, find.byTooltip('Back'));
    await tapUi(tester, find.byKey(const ValueKey('importMenu-book')));
    expect(find.text('Before uploading'), findsOneWidget);
    expect(
      tester.getRect(find.byType(BottomSheet)),
      sheetRect,
      reason: 'compact consent must keep the import menu height',
    );
    expect(
      Scrollable.of(
        tester.element(find.byType(Checkbox)),
      ).position.maxScrollExtent,
      0,
      reason: 'consent must fit without scrolling on the native phone viewport',
    );
    expect(find.byType(Checkbox).hitTestable(), findsOneWidget);
    expect(
      tester
          .getRect(find.text('I confirm I have the right to upload this file.'))
          .bottom,
      lessThan(tester.getTopLeft(find.text('Continue')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Before uploading')).dy -
          tester.getRect(find.byType(BottomSheet)).top,
      closeTo(menuTitleTop, .5),
    );
    await capture(tester, 'import-book-terms');
    expectSheetCloseAlignment(tester);
    expect(find.text('Cancel'), findsNothing);
    await tapUi(tester, find.byTooltip('Back'));
    expect(tester.getRect(find.byType(BottomSheet)), sheetRect);
    await tapUi(tester, find.byTooltip('Close'));
    expect(find.text('Add to Library'), findsNothing);
    await tapUi(tester, add);
    await tester.drag(find.text('Add to Library'), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Add to Library'), findsNothing);
    await unmountUi(tester);
  });

  testWidgets('native library controls preserve staged edits and preferences', (
    tester,
  ) async {
    final app = await UiTestApp.create(nativeReader: true);
    addTearDown(app.dispose);
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    final tile = find.byKey(ValueKey('library-grid-${app.book!.id}'));
    await waitForUi(
      tester,
      () => tile.evaluate().isNotEmpty,
      description: 'library',
    );
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
    await capture(tester, 'library-selection');
    await tapUi(tester, find.byTooltip('Cancel selection'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tapUi(tester, find.byTooltip('Display options'));
    await capture(tester, 'library-display');
    final displayRect = tester.getRect(find.byType(BottomSheet));
    expect(
      tester.getBottomLeft(find.byType(ActionBottomSheetLayout)).dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('libraryLanguagePicker')),
              )
              .dy,
      closeTo(AppSpacing.lg, .01),
    );
    expectSheetCloseAlignment(tester);
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguagePicker')));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), displayRect);
    await tapUi(tester, find.byTooltip('Back'));
    expect(tester.getRect(find.byType(BottomSheet)), displayRect);
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguagePicker')));
    final languageSheet = find.byType(BottomSheet).last;
    final english = find.byKey(const ValueKey('libraryLanguageOption-en'));
    final chinese = find.byKey(const ValueKey('libraryLanguageOption-zh'));
    final hindi = find.byKey(const ValueKey('libraryLanguageOption-hi'));
    expect(tester.getTopLeft(english).dy, tester.getTopLeft(chinese).dy);
    expect(tester.getSize(english).height, greaterThanOrEqualTo(48));
    expect(
      tester.getTopLeft(hindi).dy - tester.getBottomLeft(english).dy,
      closeTo(0, .01),
    );
    expect(
      tester.getRect(chinese).left,
      greaterThan(tester.getRect(english).right),
    );
    final languageScroll = tester
        .state<ScrollableState>(
          find.ancestor(of: english, matching: find.byType(Scrollable)),
        )
        .position;
    expect(languageScroll.maxScrollExtent, 0);
    await capture(tester, 'library-language-picker');
    final japanese = find.byKey(const ValueKey('libraryLanguageOption-ja'));
    expect(
      japanese.hitTestable(),
      findsOneWidget,
    );
    expect(
      tester.getRect(japanese).bottom,
      lessThanOrEqualTo(
        tester
            .getRect(
              find.ancestor(
                of: japanese,
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .bottom,
      ),
    );
    expect(tester.getRect(languageSheet), displayRect);
    await tester.drag(english, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(languageScroll.pixels, 0);
    expect(tester.getRect(languageSheet), displayRect);
    expectSheetCloseAlignment(tester);
    final russian = find.byKey(const ValueKey('libraryLanguageOption-ru'));
    await tapUi(tester, russian);
    expect(tester.getRect(find.byType(BottomSheet)), displayRect);
    expect(russian.hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('libraryLanguagePicker')).hitTestable(),
      findsNothing,
    );
    expect(
      find.descendant(of: russian, matching: find.byIcon(AppIcons.check)),
      findsOneWidget,
    );
    expect(languageScroll.maxScrollExtent, 0);
    await capture(tester, 'library-language-picker-ru');
    await tapUi(
      tester,
      find.byTooltip(tester.element(russian).l10n.commonBack),
    );
    expect(find.text('Русский'), findsOneWidget);
    await capture(tester, 'library-display-language-return');
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguagePicker')));
    final arabic = find.byKey(const ValueKey('libraryLanguageOption-ar'));
    await tapUi(tester, arabic);
    expect(arabic.hitTestable(), findsOneWidget);
    expect(Directionality.of(tester.element(arabic)), TextDirection.rtl);
    expect(languageScroll.maxScrollExtent, 0);
    await capture(tester, 'library-language-picker-rtl');
    await tapUi(tester, english);
    expect(english.hitTestable(), findsOneWidget);
    expect(Directionality.of(tester.element(english)), TextDirection.ltr);
    expect(
      find.descendant(of: english, matching: find.byIcon(AppIcons.check)),
      findsOneWidget,
    );
    await tapUi(tester, find.byTooltip('Back'));
    await tapUi(tester, find.text('Dark'));
    expect(
      Theme.of(tester.element(find.byType(ActionBottomSheetLayout))).brightness,
      Brightness.dark,
    );
    await capture(tester, 'library-display-dark');
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguagePicker')));
    await capture(tester, 'library-language-picker-dark');
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguageOption-en')));
    expect(english.hitTestable(), findsOneWidget);
    await tapUi(tester, find.byTooltip('Back'));
    await tapUi(tester, find.text('Light'));
    await tapUi(tester, find.byTooltip('Close'));
    await tester.longPress(tile);
    await tester.pumpAndSettle();
    await tapUi(tester, find.byIcon(AppIcons.collectionAdd));
    await tester.enterText(
      find.widgetWithText(TextField, 'New collection name'),
      'Reading',
    );
    await tapUi(tester, find.text('Create'));
    await waitForUi(
      tester,
      () => find.text('Create').evaluate().isEmpty,
      description: 'saved collection',
    );
    final collection = (await app.collectionRepository.getCollections()).single;
    await tapUi(tester, find.byIcon(AppIcons.collection));
    await tapUi(
      tester,
      find.byKey(ValueKey('collectionScopeManage-manual-${collection.id}')),
    );
    await capture(tester, 'collection-manage');
    expectSheetCloseAlignment(tester);
    void expectShortCollectionFits() {
      final sheet = find.byKey(const ValueKey('manageCollectionContent'));
      final viewport = find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      );
      expect(viewport, findsOneWidget);
      expect(
        tester.state<ScrollableState>(viewport).position.maxScrollExtent,
        0,
      );
      final fades = tester.widgetList<ScrollEdgeFade>(
        find.descendant(of: sheet, matching: find.byType(ScrollEdgeFade)),
      );
      expect(fades.every((fade) => !fade.visible), isTrue);
    }

    expectShortCollectionFits();
    await tapUi(tester, find.text('Delete collection'));
    await capture(tester, 'collection-delete');
    expectSheetCloseAlignment(tester);
    await tapUi(tester, find.byTooltip('Back'));
    expect(find.text('Manage collection'), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const ValueKey('manageCollectionContent')),
      matching: find.byType(TextField),
    );
    await tapUi(tester, field);
    await tester.enterText(field, 'Unsaved');
    // Reopen the native input connection after the test harness sets text.
    await tapUi(tester, field);
    final editable = tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.widget.focusNode.hasFocus, isTrue);
    await capture(tester, 'collection-focused');
    await waitForUi(
      tester,
      () => tester.view.viewInsets.bottom > 0,
      description: 'native keyboard',
    );
    await capture(tester, 'collection-keyboard');
    expectShortCollectionFits();
    await tapUi(tester, find.byTooltip('Close'));
    await capture(tester, 'collection-discard');
    expect(find.byType(AlertDialog), findsNothing);
    await tapUi(tester, find.byTooltip('Back'));
    expect(find.widgetWithText(TextField, 'Unsaved'), findsOneWidget);
    await tapUi(tester, find.text('Delete collection'));
    await tapUi(tester, find.byTooltip('Close'));
    expect(find.text('Discard changes?'), findsOneWidget);
    await tapUi(tester, find.text('Keep editing'));
    await tapUi(tester, find.byTooltip('Close'));
    await tapUi(tester, find.text('Discard'));
    expect(
      (await app.collectionRepository.getCollections()).single.name,
      'Reading',
    );
    await unmountUi(tester);
  });
}
