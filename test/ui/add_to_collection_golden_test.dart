import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';
import 'package:library_feature/src/add_to_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in VisualProfile.values) {
    testWidgets('collection destinations and creation ${profile.name}', (
      tester,
    ) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      await tester.runAsync(() async {
        await app.collectionRepository.createCollectionWithSources(
          name: 'Weekend reading',
          sourceIds: [app.book!.id],
        );
        await app.collectionRepository.createCollectionWithSources(
          name: 'Research',
          sourceIds: [],
        );
        await app.preferencesService.update(
          (p) => p.copyWith(
            locale: profile.locale,
            themeMode: profile.brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
        );
      });
      tester.view.physicalSize = profile == VisualProfile.tabletRtl
          ? const Size(390, 844)
          : profile.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = profile.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        RepaintBoundary(key: goldenBoundary, child: app.widget),
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'library',
      );
      final cubit = AddToCollectionCubit(
        collectionRepository: app.collectionRepository,
      );
      addTearDown(cubit.close);
      final context = tester.element(find.byType(LibraryScreen));
      final l10n = context.l10n;
      unawaited(
        showAddToCollectionSheet(
          context: context,
          cubit: cubit,
          sourceIds: {app.book!.id},
        ),
      );
      await waitForUi(
        tester,
        () => find.text('Research').evaluate().isNotEmpty,
        description: 'collection destinations',
      );
      await tester.pumpAndSettle();
      expect(cubit.state.containingAll, hasLength(1));
      await expectUiGolden(tester, profile, 'collection-destinations');
      final bounds = tester.getRect(find.byType(BottomSheet));
      await tapUi(tester, find.text(l10n.libraryNewCollection));
      expect(tester.getRect(find.byType(BottomSheet)), bounds);
      await expectUiGolden(tester, profile, 'collection-create');
      final field = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Learning');
      await tapUi(tester, find.byTooltip(l10n.commonBack));
      expect(tester.getRect(find.byType(BottomSheet)), bounds);
      await tapUi(tester, find.text(l10n.libraryNewCollection));
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Learning',
      );
      await tapUi(tester, find.byTooltip(l10n.commonClose));
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
