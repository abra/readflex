import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';
import 'package:library_feature/src/add_to_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  Future<AddToCollectionCubit> open(
    WidgetTester tester,
    FakeCollectionRepository repository, {
    double inset = 0,
    double scale = 1,
    int count = 7,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository.seedCollections(
      List.generate(
        count,
        (i) => LibraryCollection(
          id: '$i',
          name: 'Collection $i',
          sourceCount: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    final cubit = AddToCollectionCubit(collectionRepository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.only(bottom: inset),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddToCollectionSheet(
                context: context,
                cubit: cubit,
                sourceIds: {'book'},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return cubit;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('collection actions stay above keyboard at $scale', (
      tester,
    ) async {
      await open(tester, FakeCollectionRepository(), inset: 320, scale: scale);
      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create and add').hitTestable(), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        tester.getBottomLeft(find.text('Create and add')).dy,
        lessThan(844 - 320),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('load failure has retry, not an empty creation form', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()..shouldThrow = true;
    await open(tester, repository);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    repository.shouldThrow = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('New collection'), findsOneWidget);
  });

  testWidgets('existing membership is explicit and does not add again', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()
      ..seedCollectionSourceIds({
        '0': {'book'},
      });
    await open(tester, repository);
    final row = find
        .ancestor(of: find.text('Collection 0'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(row).onTap, isNull);
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIcons.check)),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.add), findsNothing);
    expect(find.text('Collection 1').hitTestable(), findsOneWidget);
  });

  for (final label in ['Favourites', 'Collection 0']) {
    testWidgets('destination rows omit plus and stay tappable: $label', (
      tester,
    ) async {
      final repository = FakeCollectionRepository();
      await open(tester, repository, count: 2);
      expect(find.byIcon(AppIcons.add), findsNothing);
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      final bounds = tester.getRect(row);
      await tester.tapAt(Offset(bounds.right - 2, bounds.center.dy));
      await tester.pumpAndSettle();
      expect(
        label == 'Favourites'
            ? repository.favouriteSourceIds
            : repository.addedSourceIdsByCollection['0'],
        {'book'},
      );
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets('Back returns to destinations while Close leaves the flow', (
    tester,
  ) async {
    await open(tester, FakeCollectionRepository());
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection 0'), findsOneWidget);
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Draft',
    );
    // Close with a typed name asks first; Discard leaves the flow.
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('long collections remain lazy', (tester) async {
    await open(tester, FakeCollectionRepository(), count: 1000);
    expect(find.textContaining('Collection ').evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creation is a stable separate step and retains its draft', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    await open(tester, repository, count: 3);
    expect(find.byType(TextField), findsNothing);
    final bounds = tester.getRect(find.byType(BottomSheet));
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create and add'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Research');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Research',
    );
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });

  testWidgets('existing collection still adds with one tap', (tester) async {
    final repository = FakeCollectionRepository();
    await open(tester, repository);
    await tester.tap(find.text('Collection 0'));
    await tester.pumpAndSettle();
    expect(repository.addedSourceIdsByCollection['0'], {'book'});
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('creation failure retains draft and height; retry creates once', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    await open(tester, repository, count: 2);
    final bounds = tester.getRect(find.byType(BottomSheet));
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Research');
    await tester.pump();
    repository.shouldThrow = true;
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Research',
    );
    final context = tester.element(find.byType(TextField));
    expect(
      find.text(context.l10n.libraryCreateCollectionFailed),
      findsOneWidget,
    );
    repository.shouldThrow = false;
    await tester.tap(find.text('Create and add'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });

  testWidgets('load failure renders the shared error state', (tester) async {
    final repository = FakeCollectionRepository()..shouldThrow = true;
    await open(tester, repository);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(find.byIcon(AppIcons.refresh), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new collection is a drill-in row that opens the form', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, FakeCollectionRepository());
    final row = find.byKey(const ValueKey('libraryNewCollectionRow'));
    expect(tester.widget(row), isA<AppDrillInRow>());
    expect(
      tester.getSemantics(row),
      matchesSemantics(
        label: 'New collection',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIcons.chevronRight)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: row,
              matching: find.byIcon(AppIcons.collectionAdd),
            ),
          )
          .color,
      tester.element(row).actionForeground,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('destination rows clip their ripple to the shared radius', (
    tester,
  ) async {
    await open(tester, FakeCollectionRepository());
    final row = find.ancestor(
      of: find.text('Favourites'),
      matching: find.byType(InkWell),
    );
    expect(
      tester.widget<InkWell>(row.first).borderRadius,
      BorderRadius.circular(AppRadius.sm),
    );
    final colors = tester.element(row.first).colors;
    expect(
      tester.widget<Text>(find.text('Favourites')).style!.color,
      colors.onSurface,
    );
  });

  Future<void> openForm(WidgetTester tester, {String draft = ''}) async {
    await open(tester, FakeCollectionRepository());
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    if (draft.isNotEmpty) {
      await tester.enterText(find.byType(TextField), draft);
      tester.testTextInput.hide();
    }
    // The dismiss guard publishes after the frame.
    await tester.pumpAndSettle();
  }

  Finder dragHandle() => find.byWidgetPredicate(
    (w) => w is Container && w.constraints?.maxWidth == 32,
  );

  testWidgets('typed name: scrim tap asks to discard and Discard closes', (
    tester,
  ) async {
    await openForm(tester, draft: 'Draft');
    expect(dragHandle(), findsNothing);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Discard changes?'), findsOneWidget);
    final discard = find.widgetWithText(OutlinedButton, 'Discard');
    final style = tester.widget<OutlinedButton>(discard).style!;
    expect(
      style.foregroundColor!.resolve({}),
      Theme.of(tester.element(discard)).colorScheme.error,
    );
    expect(find.widgetWithText(FilledButton, 'Keep editing'), findsOneWidget);
    // Another scrim tap keeps the decision visible.
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(discard);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed name: Keep editing returns to the form with the draft', (
    tester,
  ) async {
    await openForm(tester, draft: 'Draft');
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Draft',
    );
    // Header Back from the decision also keeps the draft.
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
  });

  testWidgets('empty name: scrim tap and drag-down close the flow', (
    tester,
  ) async {
    await openForm(tester);
    expect(dragHandle(), findsOneWidget);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    await openForm(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.dragFrom(
      Offset(sheet.center.dx, sheet.top + 10),
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('typed name: drag-down is swallowed and the draft survives', (
    tester,
  ) async {
    await openForm(tester, draft: 'Draft');
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.dragFrom(
      Offset(sheet.center.dx, sheet.top + 10),
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destination step: scrim and drag-down wait for the write', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final cubit = await open(tester, repository);
    final gate = Completer<void>();
    repository.writeGate = gate;
    await tester.tap(find.text('Favourites'));
    // The guard publishes after the frame.
    await tester.pump();
    await tester.pump();
    expect(cubit.state.status, AddToCollectionStatus.submitting);
    expect(dragHandle(), findsNothing);

    await tester.tapAt(const Offset(10, 20));
    await tester.pump();
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.dragFrom(
      Offset(sheet.center.dx, sheet.top + 10),
      const Offset(0, 450),
    );
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    expect(cubit.state.status, AddToCollectionStatus.submitting);
    expect(tester.takeException(), isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.favouriteSourceIds, {'book'});
  });

  testWidgets('destination step: a failed write restores dismissal', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final cubit = await open(tester, repository);
    repository.shouldThrow = true;
    await tester.tap(find.text('Favourites'));
    await tester.pumpAndSettle();
    expect(cubit.state.status, AddToCollectionStatus.failure);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(dragHandle(), findsOneWidget);

    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('system Back from the decision keeps editing the draft', (
    tester,
  ) async {
    await openForm(tester, draft: 'Draft');
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
    // System Back from the form is a step back that keeps the draft.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection 0'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('destination rows, dividers and counts share the picker\'s '
        'gutters ($locale)', (tester) async {
      final repository = FakeCollectionRepository()
        ..seedCollectionSourceIds({
          '0': {'book'},
        });
      await open(tester, repository, count: 2, locale: locale);
      final rtl = locale.languageCode == 'ar';
      final sheet = tester.getRect(find.byType(BottomSheet));
      double start(Rect r) => rtl ? sheet.right - r.right : r.left - sheet.left;
      double end(Rect r) => rtl ? r.left - sheet.left : sheet.right - r.right;
      final strings = tester.element(find.byType(BottomSheet)).l10n;

      final title = tester.getRect(
        find.text(strings.libraryAddToCollectionTitle),
      );
      final favouritesIcon = tester.getRect(
        find.byIcon(AppIcons.collectionFavourites),
      );
      final collectionIcon = tester.getRect(
        find.byIcon(AppIcons.collection).first,
      );
      final newRow = find.byKey(const ValueKey('libraryNewCollectionRow'));
      final newIcon = tester.getRect(
        find.descendant(
          of: newRow,
          matching: find.byIcon(AppIcons.collectionAdd),
        ),
      );
      expect(start(title), AppSpacing.xl);
      expect(start(favouritesIcon), closeTo(AppSpacing.xl, .01));
      expect(start(collectionIcon), closeTo(AppSpacing.xl, .01));
      expect(start(newIcon), closeTo(AppSpacing.xl, .01));
      final dividers = find.byType(Divider).evaluate().toList();
      expect(dividers, hasLength(2));
      for (final element in dividers) {
        final box = element.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(start(rect), closeTo(AppSpacing.xl, .01));
        expect(end(rect), closeTo(AppSpacing.xl, .01));
      }
      // Ink bleeds 4dp past the content on both sides.
      final row = find
          .ancestor(
            of: find.text('Collection 1'),
            matching: find.byType(InkWell),
          )
          .first;
      final rowRect = tester.getRect(row);
      expect(start(rowRect), closeTo(AppSpacing.xl - AppSpacing.xs, .01));
      expect(
        end(rowRect),
        closeTo(AppSpacing.xl - AppSpacing.xs - AppSizes.iconActionOutset, .01),
      );
      // The check glyph ends on the gutter like the picker's menu glyph and
      // counts end 12dp before that 48dp slot.
      final check = tester.getRect(find.byIcon(AppIcons.check));
      expect(end(check), closeTo(AppSpacing.xl, .01));
      final countEnd =
          AppSpacing.xl +
          AppIconSize.sm +
          AppSizes.iconActionOutset +
          AppSpacing.md;
      for (final count in tester.widgetList<Text>(find.text('0'))) {
        expect(
          end(tester.getRect(find.byWidget(count))),
          closeTo(countEnd, .01),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Create and add shows a busy spinner instead of a progress '
      'strip and disables the command without resizing it', (tester) async {
    final repository = FakeCollectionRepository();
    final cubit = await open(tester, repository);
    final gate = Completer<void>();
    repository.writeGate = gate;
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    final layout = tester.widget<ActionBottomSheetLayout>(
      find.byKey(const ValueKey('addToCollectionCreateStep')),
    );
    expect(layout.footer, isNotNull);
    expect(layout.footerPadding, ActionBottomSheetLayout.defaultFooterPadding);
    expect(layout.bodyPadding.vertical, AppSpacing.lg);
    await tester.enterText(find.byType(TextField), 'Research');
    await tester.pump();
    final create = find.widgetWithText(FilledButton, 'Create and add');
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
    final createRect = tester.getRect(create);
    await tester.tap(find.text('Create and add'));
    await tester.pump();
    expect(cubit.state.isBusy, isTrue);
    // No strip over the form; the hidden destination step keeps its own.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('addToCollectionCreateStep')),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: create,
        matching: find.byType(ButtonLoadingIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AppBusyButtonLabel>(
            find.descendant(
              of: create,
              matching: find.byType(AppBusyButtonLabel),
            ),
          )
          .busy,
      isTrue,
    );
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    expect(tester.getRect(create), createRect);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.addedSourceIdsByCollection.values.single, {'book'});
  });

  testWidgets('create step shows one full-width command on the 24dp gutters '
      'and no secondary', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await openForm(tester);
      final step = find.byKey(const ValueKey('addToCollectionCreateStep'));
      final layout = tester.widget<ActionBottomSheetLayout>(step);
      expect(layout.footer, isA<Widget>());
      expect(
        layout.footerPadding,
        ActionBottomSheetLayout.defaultFooterPadding,
      );
      expect(
        find.descendant(of: step, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: step, matching: find.byType(OutlinedButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: step, matching: find.byType(AppSheetActions)),
        findsNothing,
      );
      expect(find.text('Cancel'), findsNothing);
      final create = tester.getRect(
        find.widgetWithText(FilledButton, 'Create and add'),
      );
      expect(create.left, closeTo(AppSpacing.xl, .01));
      expect(create.right, closeTo(390 - AppSpacing.xl, .01));
      expect(create.height, AppSizes.buttonHeight);
      // 16dp footer inset plus the route's max(16, safe inset).
      expect(844 - create.bottom, closeTo(AppSpacing.lg * 2, .01));
      // Leaving stays with the header: Back and Close are both present (the
      // offstage destination step keeps its own, non-interactive Close).
      expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('create step: Close with a draft still asks, Keep editing '
      'closes only the decision', (tester) async {
    await openForm(tester, draft: 'Draft');
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Keep editing'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Discard'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
    // Header Back from the form is a step back that keeps the draft.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Collection 0'), findsOneWidget);
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
  });
}
