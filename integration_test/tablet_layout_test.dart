import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:library_feature/src/library_grid_tile.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:library_feature/src/library_selection_bar.dart';
import 'package:local_storage/local_storage.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import '../test/support/device_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';
import 'tablet_extra_flows_test.dart' as extra;

const _physicalRotation = bool.fromEnvironment('READFLEX_TEST_TABLET_ROTATION');

/// Uses the native window. With READFLEX_TEST_TABLET_ROTATION, rotate the device
/// when the READFLEX_TABLET_ROTATE marker appears; the test waits for real metrics.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Size window(WidgetTester tester) =>
      tester.view.physicalSize / tester.view.devicePixelRatio;

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 350));
    final size = window(tester);
    expect(size.shortestSide, greaterThanOrEqualTo(600));
    binding.reportData ??= {};
    final snapshots =
        binding.reportData!.putIfAbsent('tabletSnapshots', () => <Object>[])
            as List;
    snapshots.add({
      'name': name,
      'width': size.width,
      'height': size.height,
      'devicePixelRatio': tester.view.devicePixelRatio,
    });
    await takeDeviceScreenshot(binding, name);
  }

  Future<void> mount(WidgetTester tester, UiTestApp app) async {
    expect(window(tester).shortestSide, greaterThanOrEqualTo(600));
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
  }

  testWidgets('Library uses tablet grid, list and RTL selection layouts', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    for (var index = 0; index < 20; index++) {
      await app.database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: 'tablet-layout-$index',
          title: index == 0
              ? 'A Very Long Title About Reading Books Slowly Across Many Quiet Winter Evenings'
              : 'Tablet Book ${index.toString().padLeft(2, '0')}',
          author: const Value('Readflex Tablet Tests'),
          filePath: 'fixture.fb2',
          format: 'fb2',
          addedAt: DateTime(2026, 1, index + 1).toIso8601String(),
          readingProgress: Value(index == 0 ? .42 : 0),
          lastOpenedAt: Value(
            index == 0 ? DateTime(2026, 10).toIso8601String() : null,
          ),
        ),
      );
    }
    await mount(tester, app);
    final tiles = find.byType(BookLibraryGridTile).hitTestable();
    await waitForUi(
      tester,
      () => tiles.evaluate().length >= 6,
      description: 'tablet grid',
    );
    final top = tester.getTopLeft(tiles.first).dy;
    final firstRow = [
      for (final element in tiles.evaluate())
        if ((tester.getTopLeft(find.byWidget(element.widget)).dy - top).abs() <
            1)
          tester.getRect(find.byWidget(element.widget)),
    ];
    expect(firstRow.length, greaterThanOrEqualTo(6));
    expect(firstRow.every((rect) => rect.width <= 160.5), isTrue);
    final cover = tester.getRect(
      find.byKey(const ValueKey('libraryContinueReadingCover')),
    );
    final title = tester.getRect(
      find.byKey(const ValueKey('libraryContinueReadingTitle')),
    );
    expect(title.top, greaterThanOrEqualTo(cover.top - .5));
    expect(title.bottom, lessThanOrEqualTo(cover.bottom + .5));
    await capture(tester, 'tablet-library-grid');

    await tapUi(tester, find.byTooltip('Display options'));
    await tapUi(tester, find.text('List'));
    await tapUi(tester, find.byTooltip('Close').hitTestable().last);
    final rows = find.byType(BookLibraryListTile).hitTestable();
    await waitForUi(
      tester,
      () => rows.evaluate().length >= 2,
      description: 'tablet list',
    );
    final first = tester.getRect(rows.at(0));
    final second = tester.getRect(rows.at(1));
    final wide = AppWindowSize.isWideSize(window(tester));
    if (wide) {
      expect(first.top, closeTo(second.top, 1));
      expect(first.right, lessThanOrEqualTo(second.left + 1));
    } else {
      expect(second.top, greaterThanOrEqualTo(first.bottom - 1));
    }
    await capture(tester, 'tablet-library-list');

    await app.preferencesService.update(
      (prefs) =>
          prefs.copyWith(locale: const Locale('ar'), themeMode: ThemeMode.dark),
    );
    await waitForUi(
      tester,
      () =>
          rows.evaluate().isNotEmpty &&
          Directionality.of(tester.element(rows.first)) == TextDirection.rtl,
      description: 'Arabic tablet list',
    );
    if (wide) {
      expect(
        tester.getRect(rows.at(0)).left,
        greaterThan(tester.getRect(rows.at(1)).left),
      );
    }
    await tester.longPress(rows.first);
    await tester.pumpAndSettle();
    final selection = tester.getRect(find.byType(LibrarySelectionBar));
    expect(selection.left, greaterThanOrEqualTo(0));
    expect(selection.right, lessThanOrEqualTo(window(tester).width + .5));
    await capture(tester, 'tablet-library-rtl-selection-dark');
    await unmountUi(tester);
  });

  testWidgets('tablet book columns and position survive native rotation', (
    tester,
  ) async {
    final app = await UiTestApp.create();
    addTearDown(app.dispose);
    await mount(tester, app);
    await tapUi(tester, find.byKey(ValueKey('library-grid-${app.book!.id}')));
    final pages = find.byType(TextPagesView);
    TextPagesController controller() =>
        tester.widget<TextPagesView>(pages).controller;
    await waitForUi(
      tester,
      () =>
          pages.evaluate().isNotEmpty &&
          controller().isReady &&
          controller().position != null,
      description: 'tablet book layout',
      timeout: const Duration(seconds: 45),
    );
    final original = controller();
    final initialWindow = window(tester);
    final expectedColumns = initialWindow.width > initialWindow.height ? 2 : 1;
    expect(original.columns, expectedColumns);
    final fontScale = original.layout.style.fontScale;
    expect(fontScale, closeTo(Platform.isAndroid ? 1.17 : 1.125, .01));
    await capture(tester, 'tablet-book-auto');

    final context = tester.element(pages);
    final l10n = context.l10n;
    context.read<ReaderUiCubit>().showChrome();
    await tester.pumpAndSettle();
    await tapUi(tester, find.byTooltip(l10n.readerFontAction));
    final columns = find.byKey(const ValueKey('reader-columns-control'));
    await tester.ensureVisible(columns);
    await tester.pumpAndSettle();
    for (final (label, count) in [
      (l10n.readerColumnsOne, 1),
      (l10n.readerColumnsTwo, 2),
      (l10n.readerColumnsAuto, expectedColumns),
    ]) {
      await tapUi(
        tester,
        find.descendant(of: columns, matching: find.text(label)),
      );
      await waitForUi(
        tester,
        () => original.isReady && original.columns == count,
        description: '$label book columns',
      );
    }
    Navigator.of(tester.element(columns)).pop();
    await tester.pumpAndSettle();
    await original.goToFraction(.4);
    await waitForUi(
      tester,
      () => original.position!.fraction > .2,
      description: 'reading position',
    );

    if (_physicalRotation) {
      final initialOrientation = initialWindow.width > initialWindow.height
          ? 'landscape'
          : 'portrait';
      for (final orientation in [
        initialOrientation == 'portrait' ? 'landscape' : 'portrait',
        initialOrientation,
      ]) {
        final before = original.position!;
        debugPrint('READFLEX_TABLET_ROTATE:$orientation');
        await waitForUi(
          tester,
          () {
            final size = window(tester);
            final landscape = size.width > size.height;
            return landscape == (orientation == 'landscape') &&
                original.isReady &&
                original.geometry?.viewport == tester.getSize(pages);
          },
          description: 'native tablet rotation to $orientation',
          timeout: const Duration(seconds: 45),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(identical(controller(), original), isTrue);
        expect(original.position!.section, before.section);
        expect(
          original.position!.cfi,
          before.cfi,
          reason:
              'rotation keeps the reading anchor while page fractions can change',
        );
        expect(original.layout.style.fontScale, closeTo(fontScale, .001));
        expect(original.columns, orientation == 'landscape' ? 2 : 1);
        await capture(tester, 'tablet-book-rotated-$orientation');
      }
    }
    await tester.pump(const Duration(seconds: 1));
    await unmountUi(tester);
  });

  group('RTL and Practice', extra.main);

  tearDownAll(() {
    binding.reportData = {
      ...?binding.reportData,
      'platform': Platform.operatingSystem,
      'physicalRotationEnabled': _physicalRotation,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'tests': binding.results.map(
        (name, result) => MapEntry(name, result.toString()),
      ),
    };
  });
}
