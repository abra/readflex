import 'dart:async';

import 'package:collection_repository/collection_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:component_library/src/app_sheet_drag_handle.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/add_to_collection_cubit.dart';
import 'package:library_feature/src/add_to_collection_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  testWidgets(
    'standard bottom sheet confirms destinations and returns their count',
    (
      tester,
    ) async {
      final repository = FakeCollectionRepository();
      final harness = await _openModal(tester, repository);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getRect(find.byType(BottomSheet)).bottom, 844);
      expect(find.byType(AppSheetDragHandle), findsOneWidget);
      await tester.tap(_destination('reading'));
      await tester.pumpAndSettle();
      expect(repository.addedSourceIdsByCollection, isEmpty);
      await tester.tap(_submit());
      await tester.pumpAndSettle();
      expect(harness.result, 1);
      expect(repository.addedSourceIdsByCollection['reading'], {'book'});
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('modal Back and scrim protect the collection name draft', (
    tester,
  ) async {
    await _openModal(tester, FakeCollectionRepository());
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'Draft');
    await tester.pumpAndSettle();
    expect(find.byType(AppSheetDragHandle), findsNothing);
    await tester.drag(
      find.byType(BottomSheetHeader).hitTestable(),
      const Offset(0, 240),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.widget<AppTextField>(_nameField()).controller!.text, 'Draft');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Reading').hitTestable(), findsOneWidget);
    await tester.tapAt(const Offset(4, 16));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(_nameField()).controller!.text, 'Draft');
    final close = find.descendant(
      of: find.byKey(const ValueKey('addToCollectionCreateStep')),
      matching: find.byTooltip('Close'),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('modal busy guard blocks Back and scrim until saving finishes', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final harness = await _openModal(tester, repository);
    await tester.tap(_destination('reading'));
    await tester.pumpAndSettle();
    repository.writeGate = Completer<void>();
    await tester.tap(_submit());
    await tester.pump();
    expect(harness.cubit.state.status, AddToCollectionStatus.submitting);
    await tester.tapAt(const Offset(4, 16));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(harness.result, 1);
  });

  testWidgets('destinations are staged and confirmed together', (tester) async {
    final repository = FakeCollectionRepository();
    final harness = await _open(tester, repository);
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(_destination('reading'));
    await tester.tap(
      _destination(CollectionRepository.favouritesCollectionId),
    );
    await tester.pumpAndSettle();
    expect(harness.cubit.state.selectedDestinationCount, 2);
    expect(repository.addedSourceIdsByCollection, isEmpty);
    expect(find.text('Add to 2 collections'), findsOneWidget);

    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(harness.added, [2]);
    expect(repository.addedSourceIdsByCollection['reading'], {'book'});
    expect(repository.favouriteSourceIds, {'book'});
    expect(harness.closeCount, 0);
  });

  testWidgets('existing membership is checked and cannot be removed', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()
      ..seedCollectionSourceIds({
        'reading': {'book'},
      });
    final harness = await _open(tester, repository);
    final row = tester.widget<CheckboxListTile>(_destination('reading'));
    expect(row.value, isTrue);
    expect(row.onChanged, isNull);
    expect(find.text('Added to collection'), findsOneWidget);
    expect(harness.cubit.state.selectedDestinationCount, 0);
    expect(_submitButton(tester).onPressed, isNull);
    await tester.tap(_destination('research'));
    await tester.pumpAndSettle();
    expect(harness.cubit.state.selectedDestinationCount, 1);
  });

  testWidgets('search filters manual and localized favourite destinations', (
    tester,
  ) async {
    final harness = await _open(tester, FakeCollectionRepository());
    await tester.tap(_destination('reading'));
    await tester.enterText(_searchField(), 'RESEARCH');
    await tester.pumpAndSettle();
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('Reading'), findsNothing);
    expect(find.text('Favourites'), findsNothing);
    expect(harness.cubit.state.selectedCollectionIds, {'reading'});

    await tester.enterText(_searchField(), 'not a collection');
    await tester.pumpAndSettle();
    expect(find.text('No matching collections'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('libraryNewCollectionRow')),
      findsOneWidget,
    );
    expect(_submitButton(tester).onPressed, isNotNull);
    await tester.enterText(_searchField(), 'fAVourites');
    await tester.pumpAndSettle();
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Research'), findsNothing);
  });

  testWidgets('load failure retries without losing the selected source ids', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()..shouldThrow = true;
    final harness = await _open(tester, repository);
    expect(find.text('Retry'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
    repository.shouldThrow = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    await tester.tap(_destination('reading'));
    await tester.pumpAndSettle();
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(harness.added, [1]);
    expect(repository.addedSourceIdsByCollection['reading'], {'book'});
  });

  testWidgets('loading shows progress and prevents commands', (tester) async {
    final repository = _DelayedLoadRepository();
    final harness = await _open(tester, repository, waitForLoad: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
    harness.key.currentState!.requestClose();
    harness.key.currentState!.handleBack();
    expect(harness.closeCount, 0);
    repository.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Research'), findsOneWidget);
  });

  testWidgets('write failure keeps selected destinations and supports retry', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final harness = await _open(tester, repository);
    await tester.tap(_destination('reading'));
    await tester.pumpAndSettle();
    repository.shouldThrow = true;
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(harness.added, isEmpty);
    expect(find.text('Failed to add to collections'), findsOneWidget);
    expect(harness.cubit.state.selectedCollectionIds, {'reading'});
    expect(
      tester.widget<CheckboxListTile>(_destination('reading')).value,
      isTrue,
    );

    repository.shouldThrow = false;
    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(harness.added, [1]);
  });

  testWidgets('pending writes guard close, Back and duplicate submission', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final harness = await _open(tester, repository);
    await tester.tap(_destination('reading'));
    await tester.pumpAndSettle();
    repository.writeGate = Completer<void>();
    await tester.tap(_submit());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
    expect(
      tester.widget<CheckboxListTile>(_destination('research')).onChanged,
      isNull,
    );
    harness.key.currentState!.requestClose();
    harness.key.currentState!.handleBack();
    expect(harness.closeCount, 0);
    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(harness.added, [1]);
  });

  testWidgets('creation selects the new collection but waits for final Add', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final harness = await _open(tester, repository);
    await tester.tap(_destination('reading'));
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.byType(AddToCollectionSheet));
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AddToCollectionSheet)), bounds);
    expect(
      tester.widget<AppButton>(_createButton()).onPressed,
      isNull,
    );
    await tester.enterText(_nameField(), 'Design');
    await tester.pumpAndSettle();
    await tester.tap(_createButton());
    await tester.pumpAndSettle();
    expect(harness.created, 1);
    expect(harness.added, isEmpty);
    expect(harness.closeCount, 0);
    expect(find.text('Design'), findsOneWidget);
    final newId = harness.cubit.state.collections.first.id;
    expect(harness.cubit.state.selectedCollectionIds, {'reading', newId});
    expect(repository.addedSourceIdsByCollection[newId], isEmpty);

    await tester.tap(_submit());
    await tester.pumpAndSettle();
    expect(harness.added, [2]);
    expect(repository.addedSourceIdsByCollection[newId], {'book'});
  });

  testWidgets('creation failure retains the name and selected destinations', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    final harness = await _open(tester, repository);
    await tester.tap(_destination('reading'));
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'Design');
    await tester.pumpAndSettle();
    repository.shouldThrow = true;
    await tester.tap(_createButton());
    await tester.pumpAndSettle();
    expect(harness.created, 0);
    expect(
      tester.widget<AppTextField>(_nameField()).controller!.text,
      'Design',
    );
    expect(harness.cubit.state.selectedCollectionIds, {'reading'});
    expect(find.text('Failed to create collection'), findsOneWidget);
  });

  testWidgets('repeated Close retains the discard decision', (tester) async {
    final harness = await _open(tester, FakeCollectionRepository());
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'Draft');
    harness.key.currentState!.requestClose();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(harness.closeCount, 0);
    harness.key.currentState!.requestClose();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(harness.closeCount, 1);
  });

  testWidgets('Back unwinds and Keep editing retains a hidden draft', (
    tester,
  ) async {
    final harness = await _open(tester, FakeCollectionRepository());
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'Draft');
    harness.key.currentState!.handleBack();
    await tester.pumpAndSettle();
    expect(find.text('Research').hitTestable(), findsOneWidget);
    harness.key.currentState!.requestClose();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    harness.key.currentState!.handleBack();
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(_nameField()).controller!.text, 'Draft');
    harness.key.currentState!.requestClose();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(_nameField()).controller!.text, 'Draft');
    expect(harness.closeCount, 0);
  });

  testWidgets('an empty form closes without a discard decision', (
    tester,
  ) async {
    final harness = await _open(tester, FakeCollectionRepository());
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    harness.key.currentState!.requestClose();
    expect(harness.closeCount, 1);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('a thousand destinations remain lazy', (tester) async {
    final repository = FakeCollectionRepository()
      ..seedCollections([
        for (var i = 0; i < 1000; i++) _collection('$i', 'Collection $i'),
      ]);
    await _open(tester, repository, seed: false);
    expect(find.byType(CheckboxListTile).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short content shrinks and has no false list overflow', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()..seedCollections([]);
    await _open(tester, repository, seed: false);
    final panel = tester.getRect(find.byType(AddToCollectionSheet));
    expect(panel.height, lessThan(620));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('addToCollectionDestinationList')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
  });

  for (final (locale, width, scale) in [
    (const Locale('en'), 390.0, 1.0),
    (const Locale('ru'), 320.0, 2.0),
    (const Locale('ar'), 390.0, 2.0),
  ]) {
    testWidgets('all steps fit a 120dp host: $locale/$width/$scale', (
      tester,
    ) async {
      final harness = await _open(
        tester,
        FakeCollectionRepository(),
        locale: locale,
        width: width,
        scale: scale,
        height: 120,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_submit());
      await tester.pumpAndSettle();
      expect(_submit().hitTestable(), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('libraryNewCollectionRow')),
      );
      await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_nameField());
      await tester.enterText(_nameField(), 'Draft');
      await tester.pumpAndSettle();
      await tester.ensureVisible(_createButton());
      await tester.pumpAndSettle();
      expect(_createButton().hitTestable(), findsOneWidget);
      harness.key.currentState!.requestClose();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(AddToCollectionSheet));
      await tester.ensureVisible(find.text(context.l10n.commonKeepEditing));
      await tester.pumpAndSettle();
      expect(
        find.text(context.l10n.commonKeepEditing).hitTestable(),
        findsOneWidget,
      );
    });
  }

  testWidgets('keyboard resizing retains form focus and text', (tester) async {
    final height = ValueNotifier(620.0);
    addTearDown(height.dispose);
    final harness = await _open(
      tester,
      FakeCollectionRepository(),
      hostHeight: height,
    );
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'Focused draft');
    final editable = tester.element(
      find.descendant(of: _nameField(), matching: find.byType(EditableText)),
    );
    final focus = tester
        .widget<EditableText>(
          find.descendant(
            of: _nameField(),
            matching: find.byType(EditableText),
          ),
        )
        .focusNode;
    expect(focus.hasFocus, isTrue);
    height.value = 140;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.element(
        find.descendant(of: _nameField(), matching: find.byType(EditableText)),
      ),
      same(editable),
    );
    expect(focus.hasFocus, isTrue);
    expect(
      tester.widget<AppTextField>(_nameField()).controller!.text,
      'Focused draft',
    );
    height.value = 620;
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    harness.key.currentState!.handleBack();
    await tester.pumpAndSettle();
    expect(find.text('Research').hitTestable(), findsOneWidget);
  });

  testWidgets('step navigation resets a compact viewport to its header', (
    tester,
  ) async {
    final harness = await _open(
      tester,
      FakeCollectionRepository(),
      locale: const Locale('de'),
      width: 320,
      scale: 2,
      height: 300,
    );
    final context = tester.element(find.byType(AddToCollectionSheet));
    final l10n = context.l10n;
    final outer = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('addToCollectionPanelViewport')),
        )
        .controller!;

    await tester.ensureVisible(_submit());
    await tester.pumpAndSettle();
    expect(outer.offset, greaterThan(0));
    await tester.ensureVisible(
      find.byKey(const ValueKey('libraryNewCollectionRow')),
    );
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    expect(outer.offset, closeTo(0, .01));
    expect(
      find
          .descendant(
            of: find.byKey(const ValueKey('addToCollectionCreateStep')),
            matching: find.text(l10n.libraryNewCollection),
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(_nameField().hitTestable(), findsOneWidget);

    await tester.enterText(_nameField(), 'Draft');
    await tester.pumpAndSettle();
    await tester.ensureVisible(_createButton());
    await tester.pumpAndSettle();
    expect(outer.offset, greaterThan(0));
    harness.key.currentState!.requestClose();
    await tester.pumpAndSettle();
    expect(outer.offset, closeTo(0, .01));
    expect(
      find.text(l10n.libraryDiscardChangesTitle).hitTestable(),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text(l10n.commonKeepEditing));
    await tester.tap(find.text(l10n.commonKeepEditing));
    await tester.pumpAndSettle();
    expect(outer.offset, closeTo(0, .01));
    expect(_nameField().hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large German action labels wrap in full', (tester) async {
    final harness = await _open(
      tester,
      FakeCollectionRepository(),
      locale: const Locale('de'),
      width: 320,
      scale: 2,
    );
    harness.cubit.toggleCollection('reading');
    await tester.pumpAndSettle();
    await tester.ensureVisible(_submit());
    await tester.pumpAndSettle();
    final submitParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: _submit(), matching: find.byType(RichText)),
    );
    expect(submitParagraph.didExceedMaxLines, isFalse);
    expect(submitParagraph.maxLines, isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('libraryNewCollectionRow')),
    );
    await tester.tap(find.byKey(const ValueKey('libraryNewCollectionRow')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_nameField());
    await tester.enterText(_nameField(), 'Design');
    await tester.pumpAndSettle();
    await tester.ensureVisible(_createButton());
    await tester.pumpAndSettle();
    final createParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: _createButton(), matching: find.byType(RichText)),
    );
    expect(createParagraph.didExceedMaxLines, isFalse);
    expect(createParagraph.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact German results show a complete destination row', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()
      ..seedCollections([_collection('research', 'Research')])
      ..seedCollectionSourceIds({
        CollectionRepository.favouritesCollectionId: {'book'},
      });
    await _open(
      tester,
      repository,
      seed: false,
      locale: const Locale('de'),
      width: 320,
      windowHeight: 568,
      scale: 2,
      height: 360,
    );
    final list = find.byKey(const ValueKey('addToCollectionDestinationList'));
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      _destination('research'),
      80,
      scrollable: scrollable,
    );
    await Scrollable.ensureVisible(
      tester.element(_destination('research')),
      alignment: .5,
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(list);
    final row = tester.getRect(_destination('research'));
    expect(row.height, lessThanOrEqualTo(viewport.height + .01));
    expect(row.top, greaterThanOrEqualTo(viewport.top - .01));
    expect(row.bottom, lessThanOrEqualTo(viewport.bottom + .01));
    final visibleViewport = viewport.intersect(
      tester.getRect(find.byType(AddToCollectionSheet)),
    );
    expect(visibleViewport.contains(row.center), isTrue);
    final title = find.descendant(
      of: _destination('research'),
      matching: find.text('Research'),
    );
    final titleRect = tester.getRect(title);
    expect(titleRect.top, greaterThanOrEqualTo(visibleViewport.top - .01));
    expect(titleRect.bottom, lessThanOrEqualTo(visibleViewport.bottom + .01));
    expect(_destination('research').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _destination(String id) =>
    find.byKey(ValueKey('addToCollectionDestination-$id'));

Finder _submit() => find.byKey(const ValueKey('addToCollectionsSubmitButton'));

AppButton _submitButton(WidgetTester tester) =>
    tester.widget<AppButton>(_submit());

Finder _nameField() => find.byKey(const ValueKey('newCollectionNameField'));

Finder _createButton() =>
    find.byKey(const ValueKey('createCollectionSubmitButton'));

Finder _searchField() => find.descendant(
  of: find.byKey(const ValueKey('addToCollectionsSearch')),
  matching: find.byType(TextField),
);

Future<_SheetHarness> _open(
  WidgetTester tester,
  FakeCollectionRepository repository, {
  bool seed = true,
  bool waitForLoad = true,
  double height = 620,
  double width = 390,
  double windowHeight = 844,
  double scale = 1,
  Locale locale = const Locale('en'),
  ValueNotifier<double>? hostHeight,
}) async {
  tester.view
    ..physicalSize = Size(width, windowHeight)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (seed) {
    repository.seedCollections([
      _collection('reading', 'Reading'),
      _collection('research', 'Research'),
      _collection('long', 'A collection with a long name that wraps naturally'),
    ]);
  }
  final harness = _SheetHarness(
    AddToCollectionCubit(collectionRepository: repository),
  );
  addTearDown(harness.cubit.close);
  final loading = harness.cubit.load(sourceIds: {'book'});
  if (waitForLoad) await loading;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: BlocProvider.value(
              value: harness.cubit,
              child: _SheetHost(
                harness: harness,
                height: height,
                hostHeight: hostHeight,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (waitForLoad) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return harness;
}

class _SheetHost extends StatelessWidget {
  const _SheetHost({
    required this.harness,
    required this.height,
    this.hostHeight,
  });

  final _SheetHarness harness;
  final double height;
  final ValueNotifier<double>? hostHeight;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: hostHeight ?? AlwaysStoppedAnimation(height),
    child: AddToCollectionSheet(
      key: harness.key,
      sourceIds: const {'book'},
      onClose: () => harness.closeCount++,
      onAdded: harness.added.add,
      onCollectionCreated: () => harness.created++,
    ),
    builder: (context, height, child) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: child,
    ),
  );
}

class _SheetHarness {
  _SheetHarness(this.cubit);

  final AddToCollectionCubit cubit;
  final key = GlobalKey<AddToCollectionSheetState>();
  int closeCount = 0;
  final added = <int>[];
  int created = 0;
}

LibraryCollection _collection(String id, String name) => LibraryCollection(
  id: id,
  name: name,
  sourceCount: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _DelayedLoadRepository extends FakeCollectionRepository {
  final ready = Completer<void>();

  @override
  Future<List<LibraryCollection>> getCollections() async {
    await ready.future;
    return super.getCollections();
  }
}

Future<_ModalHarness> _openModal(
  WidgetTester tester,
  FakeCollectionRepository repository,
) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  repository.seedCollections([_collection('reading', 'Reading')]);
  final cubit = AddToCollectionCubit(collectionRepository: repository);
  final harness = _ModalHarness(cubit);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: readflexLocalizationsDelegates,
      supportedLocales: ReadflexSupportedLocales.locales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              harness.result = await showAddToCollectionSheet(
                context: context,
                cubit: cubit,
                sourceIds: const {'book'},
                onCollectionCreated: () {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return harness;
}

class _ModalHarness {
  _ModalHarness(this.cubit);

  final AddToCollectionCubit cubit;
  int? result;
}
