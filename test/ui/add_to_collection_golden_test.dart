import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';
import 'package:library_feature/src/add_to_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final (profile, size, locale, directory, suffix) in [
    for (final profile in VisualProfile.values)
      (
        profile,
        profile == VisualProfile.tabletRtl
            ? const Size(390, 844)
            : profile.size,
        profile.locale,
        profile.name,
        '',
      ),
    (
      VisualProfile.phone,
      const Size(390, 844),
      const Locale('ru'),
      'phoneRu',
      '',
    ),
    (
      VisualProfile.phone,
      const Size(800, 1280),
      const Locale('en'),
      'phone',
      '-tablet-portrait-800',
    ),
    (
      VisualProfile.phone,
      const Size(1280, 800),
      const Locale('en'),
      'phone',
      '-tablet-landscape-1280',
    ),
  ]) {
    Future<void> snapshot(WidgetTester tester, String surface) async {
      expect(
        tester.takeException(),
        isNull,
        reason: '$directory/$surface$suffix',
      );
      await expectLater(
        find.byKey(goldenBoundary),
        matchesGoldenFile('goldens/$directory/$surface$suffix.png'),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '$directory/$surface$suffix',
      );
    }

    testWidgets('collection destinations and creation $directory$suffix', (
      tester,
    ) async {
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      late String researchId;
      late String weekendId;
      await tester.runAsync(() async {
        final weekend = await app.collectionRepository
            .createCollectionWithSources(
              name: 'Weekend reading',
              sourceIds: [app.book!.id],
            );
        final research = await app.collectionRepository
            .createCollectionWithSources(
              name: 'Research',
              sourceIds: [],
            );
        researchId = research.id;
        weekendId = weekend.id;
        await app.preferencesService.update(
          (p) => p.copyWith(
            locale: locale,
            themeMode: profile.brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
        );
      });
      tester.view.physicalSize = size;
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
      final tile = find.byKey(ValueKey('library-grid-${app.book!.id}'));
      await tester.longPressAt(tester.getTopLeft(tile) + const Offset(30, 30));
      await tester.pumpAndSettle();
      await tapUi(
        tester,
        find.byKey(const ValueKey('libraryAddToCollectionButton')),
      );
      final sheet = find.byType(AddToCollectionSheet);
      await waitForUi(
        tester,
        () => sheet.evaluate().isNotEmpty,
        description: 'collection bottom sheet',
      );
      final sheetContext = tester.element(sheet);
      final l10n = sheetContext.l10n;
      final cubit = sheetContext.read<AddToCollectionCubit>();
      await waitForUi(
        tester,
        () => cubit.state.status == AddToCollectionStatus.success,
        description: 'loaded collection destinations',
      );
      await tester.pumpAndSettle();
      expect(cubit.state.containingAll, {weekendId});
      expect(cubit.state.selectedCollectionIds, isEmpty);
      final submit = find.byKey(const ValueKey('addToCollectionsSubmitButton'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await snapshot(tester, 'collection-destinations');

      final destinationScrollable = find.descendant(
        of: find.byKey(const ValueKey('addToCollectionDestinationList')),
        matching: find.byType(Scrollable),
      );
      Future<void> revealDestination(
        Finder destination, {
        bool interactive = true,
      }) async {
        final position = tester
            .state<ScrollableState>(destinationScrollable)
            .position;
        position.jumpTo(position.minScrollExtent);
        await tester.pump();
        for (
          var attempt = 0;
          destination.evaluate().isEmpty && attempt < 50;
          attempt++
        ) {
          final next = (position.pixels + 48)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
          if (next == position.pixels) break;
          position.jumpTo(next);
          await tester.pump();
        }
        expect(destination, findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(destination),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        if (interactive) expect(destination.hitTestable(), findsOneWidget);
      }

      final includedDestination = find.byKey(
        ValueKey('addToCollectionDestination-$weekendId'),
      );
      await revealDestination(includedDestination, interactive: false);
      final weekend = tester.widget<CheckboxListTile>(
        includedDestination,
      );
      expect(weekend.value, isTrue);
      expect(weekend.onChanged, isNull);

      final research = find.byKey(
        ValueKey('addToCollectionDestination-$researchId'),
      );
      await revealDestination(research);
      await tapUi(tester, research);
      expect(cubit.state.selectedCollectionIds, {researchId});
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(
        (await tester.runAsync(
              app.collectionRepository.getCollectionSourceIds,
            ))![researchId] ??
            const <String>{},
        isEmpty,
        reason:
            'choosing a destination must not add the book before confirmation',
      );
      if (profile == VisualProfile.largeText) {
        // Keep the chosen row readable in the short enlarged-text viewport.
        await Scrollable.ensureVisible(
          tester.element(research),
          alignment: .5,
        );
      } else {
        await tester.ensureVisible(submit);
        await tester
            .state<ScrollableState>(destinationScrollable)
            .position
            .ensureVisible(tester.renderObject(research), alignment: 1);
      }
      await tester.pumpAndSettle();
      await snapshot(tester, 'collection-destinations-selected');

      final bounds = tester.getRect(sheet);
      final create = find.byKey(const ValueKey('libraryNewCollectionRow'));
      await tester.ensureVisible(create);
      await tapUi(tester, create);
      expect(tester.getRect(sheet), bounds);
      await snapshot(tester, 'collection-create');
      final field = find.byKey(const ValueKey('newCollectionNameField'));
      final creationStep = find.byKey(
        const ValueKey('addToCollectionCreateStep'),
      );
      final back = find.descendant(
        of: creationStep,
        matching: find.byTooltip(l10n.commonBack),
      );
      final close = find.descendant(
        of: creationStep,
        matching: find.byTooltip(l10n.commonClose),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Learning');
      await tester.ensureVisible(back);
      await tapUi(tester, back);
      expect(tester.getRect(sheet), bounds);
      expect(cubit.state.selectedCollectionIds, {researchId});
      await tester.ensureVisible(create);
      await tapUi(tester, create);
      expect(tester.widget<TextField>(field).controller!.text, 'Learning');
      await tester.ensureVisible(close);
      await tapUi(tester, close);
      expect(
        find.byKey(const ValueKey('addToCollectionDiscardStep')),
        findsOneWidget,
      );
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}
