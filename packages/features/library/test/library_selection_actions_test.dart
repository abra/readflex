import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_selection_bar.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:library_feature/src/library_content_scroll_view.dart';
import 'package:library_feature/src/library_grid_tile.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_list_tile.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const _cancel = ValueKey('libraryCancelSelectionFab');
const _capsule = ValueKey('librarySelectionCapsule');
const _collections = ValueKey('libraryAddToCollectionButton');
const _delete = ValueKey('libraryDeleteSelectedButton');

Future<LibrarySelectionCubit> _pumpActions(
  WidgetTester tester, {
  int count = 3,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool busy = false,
  bool open = false,
  VoidCallback? onCancel,
  VoidCallback? onAdd,
  VoidCallback? onDelete,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.view
    ..viewPadding = FakeViewPadding(
      left: viewPadding.left,
      top: viewPadding.top,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
    )
    ..padding = FakeViewPadding(
      left: viewPadding.left,
      top: viewPadding.top,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
    );
  addTearDown(tester.view.reset);
  final cubit = LibrarySelectionCubit();
  for (var i = 0; i < count; i++) {
    cubit.toggle('source-$i');
  }
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: LibrarySelectionBar(
            onAddToCollection: onAdd ?? () {},
            onDelete: onDelete ?? () {},
            onCancelSelection: onCancel,
            busy: busy,
            collectionPickerOpen: open,
            viewPadding: viewPadding,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets('selection controls disappear when nothing is selected', (
    tester,
  ) async {
    await _pumpActions(tester, count: 0);
    expect(find.byKey(_cancel), findsNothing);
    expect(find.byKey(_capsule), findsNothing);
  });

  testWidgets('separate cancel FAB and capsule retain their actions', (
    tester,
  ) async {
    var adds = 0;
    var deletes = 0;
    await _pumpActions(
      tester,
      onAdd: () => adds++,
      onDelete: () => deletes++,
    );
    final cancel = tester.getRect(find.byKey(_cancel));
    final capsule = tester.getRect(find.byKey(_capsule));
    expect(cancel.width, closeTo(56, .01));
    expect(cancel.height, closeTo(56, .01));
    expect(cancel.left, closeTo(16, .01));
    expect(capsule.right, closeTo(374, .01));
    expect(capsule.left - cancel.right, closeTo(16, .01));
    expect(capsule.height, closeTo(56, .01));
    expect(capsule.bottom, closeTo(cancel.bottom, .01));
    await tester.tap(find.byKey(_collections));
    await tester.tap(find.byKey(_delete));
    expect(adds, 1);
    expect(deletes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default cancel clears selection', (tester) async {
    final cubit = await _pumpActions(tester);
    await tester.tap(find.byKey(_cancel));
    await tester.pump();
    expect(cubit.state.isActive, isFalse);
    expect(find.byKey(_capsule), findsNothing);
  });

  testWidgets('custom cancel delegates selection cancellation to the screen', (
    tester,
  ) async {
    var cancels = 0;
    final cubit = await _pumpActions(tester, onCancel: () => cancels++);
    await tester.tap(find.byKey(_cancel));
    expect(cancels, 1);
    expect(cubit.state.count, 3);
  });

  testWidgets('busy state blocks every command while preserving geometry', (
    tester,
  ) async {
    await _pumpActions(tester, busy: true);
    expect(
      tester.widget<AppIconButton>(find.byKey(_cancel)).onPressed,
      isNull,
    );
    expect(
      tester.widget<AppButton>(find.byKey(_collections)).onPressed,
      isNull,
    );
    expect(
      tester.widget<AppIconButton>(find.byKey(_delete)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byKey(_capsule)).height, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'open sheet marks the collection action and disables deletion',
    (
      tester,
    ) async {
      await _pumpActions(tester, open: true);
      expect(find.byIcon(AppIcons.chevronUp), findsOneWidget);
      expect(
        tester.widget<AppIconButton>(find.byKey(_delete)).onPressed,
        isNull,
      );
      expect(
        tester.widget<AppButton>(find.byKey(_collections)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<AppIconButton>(find.byKey(_cancel)).onPressed,
        isNotNull,
      );
    },
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('landscape selection respects side safe insets $locale', (
      tester,
    ) async {
      const window = Size(844, 390);
      const padding = EdgeInsets.symmetric(horizontal: 44);
      await _pumpActions(
        tester,
        size: window,
        locale: locale,
        viewPadding: padding,
      );
      final context = tester.element(find.byType(LibrarySelectionBar));
      final cancel = tester.getRect(find.byKey(_cancel));
      final capsule = tester.getRect(find.byKey(_capsule));
      if (Directionality.of(context) == TextDirection.rtl) {
        expect(cancel.right, closeTo(window.width - padding.right - 16, .01));
        expect(capsule.left, closeTo(padding.left + 16, .01));
      } else {
        expect(cancel.left, closeTo(padding.left + 16, .01));
        expect(capsule.right, closeTo(window.width - padding.right - 16, .01));
      }
      expect(
        capsule.height,
        closeTo(
          LibrarySelectionBar.heightOf(context, viewPadding: padding),
          .01,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, locale, textScale, count) in const [
    (Size(320, 568), Locale('de'), 2.0, 1200),
    (Size(390, 844), Locale('ar'), 1.0, 3),
    (Size(800, 1280), Locale('de'), 2.0, 3),
  ]) {
    testWidgets('controls fit $size $locale ${textScale}x count $count', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpActions(
        tester,
        size: size,
        locale: locale,
        textScale: textScale,
        count: count,
      );
      final context = tester.element(find.byType(LibrarySelectionBar));
      final cancel = tester.getRect(find.byKey(_cancel));
      final capsule = tester.getRect(find.byKey(_capsule));
      expect(
        capsule.height,
        closeTo(LibrarySelectionBar.heightOf(context), .01),
      );
      expect(capsule.bottom, closeTo(cancel.bottom, .01));
      expect(capsule.top, greaterThanOrEqualTo(0));
      if (Directionality.of(context) == TextDirection.rtl) {
        expect(cancel.right, closeTo(size.width - 16, .01));
        expect(capsule.left, closeTo(16, .01));
      } else {
        expect(cancel.left, closeTo(16, .01));
        expect(capsule.right, closeTo(size.width - 16, .01));
      }
      for (final key in [_cancel, _collections, _delete]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(context.l10n.libraryCollectionsTitle),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final countSemantics = tester.getSemantics(
        find.byKey(const ValueKey('librarySelectedCount')),
      );
      expect(countSemantics.label, context.l10n.librarySelectedCount(count));
      if (count > 999) expect(find.text('999+'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final mode in LibraryLayoutMode.values) {
    testWidgets('last $mode item clears inset large selection controls', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1
        ..viewPadding = const FakeViewPadding(left: 44, right: 44)
        ..padding = const FakeViewPadding(left: 44, right: 44);
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final cubit = LibrarySelectionCubit()..toggle('book-0');
      addTearDown(cubit.close);
      final sources = [
        for (var i = 0; i < 20; i++)
          LibrarySource(
            id: 'book-$i',
            sourceType: SourceType.book,
            title: 'Book $i',
            typeLabel: 'EPUB',
            addedAt: DateTime(2026),
            lastOpenedAt: DateTime(2026),
          ),
      ];
      var actualActionsHeight = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('de'),
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                final padding = MediaQuery.viewPaddingOf(context);
                actualActionsHeight = LibrarySelectionBar.heightOf(
                  context,
                  viewPadding: padding,
                );
                return Scaffold(
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.endFloat,
                  floatingActionButton: LibrarySelectionBar(
                    onAddToCollection: () {},
                    onDelete: () {},
                    viewPadding: padding,
                  ),
                  body: SafeArea(
                    bottom: false,
                    child: LibraryContentScrollView(
                      layoutMode: mode,
                      sources: sources,
                      selection: cubit.state,
                      selectionActionsHeight: actualActionsHeight,
                      scrollController: controller,
                      onSourcePressed: (_) {},
                      onSourceLongPressed: (_) {},
                      onConfirmSwipeDelete: (_) async => false,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final capsule = tester.getRect(find.byKey(_capsule));
      final last = mode == LibraryLayoutMode.grid
          ? find.byWidgetPredicate(
              (widget) =>
                  widget is BookLibraryGridTile &&
                  widget.source.id == 'book-19',
            )
          : find.byWidgetPredicate(
              (widget) =>
                  widget is BookLibraryListTile &&
                  widget.source.id == 'book-19',
            );
      expect(last, findsOneWidget);
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(capsule.top - 16));
      expect(capsule.height, closeTo(actualActionsHeight, .01));
      expect(tester.takeException(), isNull);
    });
  }
}
