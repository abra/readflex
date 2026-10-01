import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    final menuRect = tester.getRect(find.byType(ActionBottomSheetLayout));
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
    await capture(tester, 'import-article-entry');
    await tapUi(tester, find.text('Back'));
    await tapUi(tester, find.byKey(const ValueKey('importMenu-book')));
    expect(find.text('Before uploading'), findsOneWidget);
    await tapUi(tester, find.text('Cancel'));
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
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguagePicker')));
    await capture(tester, 'library-language-picker');
    await tapUi(tester, find.byKey(const ValueKey('libraryLanguageOption-en')));
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
    final field = find.descendant(
      of: find.byKey(const ValueKey('manageCollectionContent')),
      matching: find.byType(TextField),
    );
    await tapUi(tester, field);
    await tester.enterText(field, 'Unsaved');
    await waitForUi(
      tester,
      () => tester.view.viewInsets.bottom > 0,
      description: 'native keyboard',
    );
    await capture(tester, 'collection-keyboard');
    await tapUi(tester, find.byTooltip('Close'));
    await tapUi(tester, find.text('Keep editing'));
    expect(find.widgetWithText(TextField, 'Unsaved'), findsOneWidget);
    await tapUi(tester, find.byTooltip('Close'));
    await tapUi(tester, find.text('Discard'));
    expect(
      (await app.collectionRepository.getCollections()).single.name,
      'Reading',
    );
    await unmountUi(tester);
  });
}
