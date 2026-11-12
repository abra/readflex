import 'dart:async';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_highlight_color.dart';
import 'package:reader/src/reader_highlight_controls.dart';
import 'package:reader/src/reader_highlight_note_sheet.dart';
import 'package:reader/src/reader_image_highlight_cubit.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:toast_service/toast_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:pagecraft/testing.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  late Directory tempDir;
  late PreferencesService preferences;
  late FakeBookRepository books;
  late FakeHighlightRepository highlights;
  late Book comic;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    // Widget tests run in a fake async zone where real file I/O never
    // completes; the fixture is written synchronously.
    tempDir = Directory.systemTemp.createTempSync('reader_comic_');
    final path = '${tempDir.path}/issue.cbz';
    File(path).writeAsBytesSync(buildComicArchive(portraitPages(5)));
    books = FakeBookRepository();
    highlights = FakeHighlightRepository();
    comic = Book(
      id: 'comic-1',
      title: 'Issue 1',
      filePath: path,
      format: BookFormat.cbz,
      addedAt: DateTime(2026, 1, 1),
      comicPageOrderVersion: 1,
    );
    books.seedBook(comic);
  });

  tearDown(() {
    preferences.dispose();
    tempDir.deleteSync(recursive: true);
  });

  /// Lets the archive open and the visible page decode. Both are chains of
  /// real I/O: each step completes on the real event loop and continues on
  /// the next pump, so the two alternate until the page is on screen.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        final frames = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is FixedPagePainter,
        );
        if (frames.evaluate().isNotEmpty) break;
      }
    });
    await tester.pump();
  }

  Future<void> pumpReader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        navigatorObservers: [ToastNavigatorObserver()],
        localizationsDelegates: readflexLocalizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: ReaderScreen(
          sourceId: comic.id,
          bookRepository: books,
          highlightRepository: highlights,
          preferencesService: preferences,
          screenControlService: _ScreenControlService(),
          textActions: const [],
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  ReadflexLocalizations l10n(WidgetTester tester) =>
      tester.element(find.byType(FixedPagesView)).l10n;

  /// Shows the chrome when it is hidden (a centre tap, after the
  /// double-tap window) and returns the tappable control with [tooltip].
  Future<Finder> chromeControl(WidgetTester tester, String tooltip) async {
    var control = find.byTooltip(tooltip).hitTestable();
    if (control.evaluate().isEmpty) {
      await tester.tapAt(const Offset(195, 422));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      control = find.byTooltip(tooltip).hitTestable();
    }
    expect(control, findsOneWidget);
    return control;
  }

  Future<void> beginGatedAreaSave(
    WidgetTester tester,
    Completer<void> gate,
  ) async {
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    highlights.addGate = gate.future;
    final strings = l10n(tester);
    await tester.tap(find.byTooltip(strings.highlightAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.readerSkip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final saver = tester
        .element(find.byType(FixedPagesView))
        .read<ReaderImageHighlightCubit>();
    expect(saver.state.status, ReaderImageHighlightStatus.saving);
  }

  testWidgets('opens a comic on the native engine', (
    tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(FixedPagesView), findsOneWidget);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(1)),
      findsOneWidget,
    );
    // One contents entry per page, each naming its page counted from 1.
    final toc = tester
        .element(find.byType(FixedPagesView))
        .read<ReaderBloc>()
        .state
        .tocItems;
    expect(toc.map((i) => i.startPage), [1, 2, 3, 4, 5]);

    // The opening position is reported and persisted.
    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, 'epubcfi(/6/2)');
    expect(books.updatedBook?.readingProgress, closeTo(0.2, 1e-9));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a swipe turns the page and persists the new position', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(2)),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(books.updatedBook?.currentCfi, 'epubcfi(/6/4)');
    expect(books.updatedBook?.readingProgress, closeTo(0.4, 1e-9));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('the vertical page turn swipes pages up and down', (
    tester,
  ) async {
    await pumpReader(tester);
    final element = tester.element(find.byType(FixedPagesView));
    await element.read<ReaderAppearanceCubit>().setPageTurnStyle(
      ReaderPageTurnStyle.vertical,
    );
    await tester.pump();
    await tester.pump();
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(1)),
      findsOneWidget,
      reason: 'a sideways swipe does nothing',
    );
    await tester.fling(find.byType(PageView), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(
      find.bySemanticsLabel(l10n(tester).readerPageNumber(2)),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'global comic page animation switches without changing its page or zoom',
    (
      tester,
    ) async {
      await preferences.update(
        (prefs) =>
            prefs.copyWith(readerPageAnimation: ReaderPageAnimation.slide),
      );
      await pumpReader(tester);
      final pages = find.byType(FixedPagesView);
      final initial = tester.widget<FixedPagesView>(pages);
      expect(initial.pageTurnAnimation, PageTurnAnimation.slide);
      final controller = initial.controller;
      expect(controller.next(), isTrue);
      await tester.pumpAndSettle();
      await settle(tester);
      expect(controller.page, 1);
      final source = (initial.pages as ComicPages).source;
      final viewer = find.byType(InteractiveViewer).hitTestable().first;
      final zoom = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      zoom.value = Matrix4.diagonal3Values(1.75, 1.75, 1);
      await tester.pump();
      final matrix = zoom.value.clone();
      final epoch = controller.zoomEpoch;
      await preferences.update(
        (prefs) =>
            prefs.copyWith(readerPageAnimation: ReaderPageAnimation.cover),
      );
      await tester.pumpAndSettle();
      final updated = tester.widget<FixedPagesView>(pages);
      expect(updated.pageTurnAnimation, PageTurnAnimation.cover);
      expect(updated.controller, same(controller));
      expect((updated.pages as ComicPages).source, same(source));
      expect(controller.page, 1);
      expect(controller.zoomEpoch, epoch);
      expect(
        tester.widget<InteractiveViewer>(viewer).transformationController,
        same(zoom),
      );
      expect(zoom.value, matrix);
      expect(preferences.readerAppearanceOverrideFor(comic.id), isNull);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('the chrome bookmark button bookmarks the page on screen', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = l10n(tester);
    await tester.tap(await chromeControl(tester, strings.readerBookmark));
    await tester.pumpAndSettle();

    final saved = books.bookmarksBySourceId[comic.id]!.single;
    expect(saved.cfi, 'epubcfi(/6/2)');
    expect(saved.anchorSectionIndex, 0);
    expect(saved.anchorSectionPage, 0);
    expect(saved.content, 'Page 1 / 5');
    expect(saved.progress, closeTo(0.2, 1e-9));
    // The page's bookmark state reaches the chrome through the position.
    expect(
      find.byTooltip(strings.readerRemoveBookmark).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(
      find.byTooltip(strings.readerRemoveBookmark).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(books.bookmarksBySourceId[comic.id], isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final initialTheme in [
    ReaderThemePreset.paper,
    ReaderThemePreset.night,
  ]) {
    testWidgets(
      'Comic image draft stays lightly tinted from ${initialTheme.id} through popup, palette and theme changes',
      (tester) async {
        await preferences.update(
          (value) => value.copyWith(readerThemeId: initialTheme.id),
        );
        await highlights.addImageAreaHighlight(
          sourceId: 'comic-1',
          sourceType: SourceType.book,
          pageIndex: 0,
          x: .05,
          y: .05,
          width: .1,
          height: .1,
          color: HighlightColor.pink,
        );
        await pumpReader(tester);
        final layer = tester.widget<ComicImageAreaLayer>(
          find.byWidgetPredicate(
            (widget) => widget is ComicImageAreaLayer && widget.page == 0,
          ),
        );
        expect(layer.draft.opacity, .45, reason: 'initial engine style');
        expect(
          layer.areas.single.color,
          readerImageHighlightColor(HighlightColor.pink),
        );
        expect(
          layer.draft.color,
          readerImageHighlightColor(HighlightColor.yellow),
        );
        await tester.longPressAt(const Offset(195, 422));
        await tester.pumpAndSettle();
        expect(
          layer.draft.opacity,
          .45,
          reason: 'popup preview must not restore text opacity',
        );
        expect(
          tester
              .widgetList<AppColorSwatchButton>(
                find.byType(AppColorSwatchButton),
              )
              .singleWhere((swatch) => swatch.selected)
              .color,
          layer.draft.color,
        );
        final strings = l10n(tester);
        for (final (color, label) in [
          (HighlightColor.green, strings.highlightColorGreen),
          (HighlightColor.blue, strings.highlightColorBlue),
        ]) {
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is AppColorSwatchButton && widget.tooltip == label,
            ),
          );
          await tester.pump();
          expect(layer.draft.opacity, .45);
          expect(
            layer.draft.color,
            readerImageHighlightColor(color),
          );
          expect(
            tester
                .widgetList<AppColorSwatchButton>(
                  find.byType(AppColorSwatchButton),
                )
                .singleWhere((swatch) => swatch.selected)
                .color,
            layer.draft.color,
          );
        }
        final nextTheme = initialTheme == ReaderThemePreset.paper
            ? ReaderThemePreset.night
            : ReaderThemePreset.paper;
        await tester
            .element(find.byType(FixedPagesView))
            .read<ReaderAppearanceCubit>()
            .setTheme(nextTheme.id);
        await tester.pumpAndSettle();
        expect(layer.draft.isActive, isTrue);
        expect(
          tester
              .widgetList<ComicImageAreaLayer>(find.byType(ComicImageAreaLayer))
              .first
              .areas
              .single
              .color,
          readerImageHighlightColor(HighlightColor.pink),
          reason: 'saved image areas keep their palette across themes',
        );
        expect(
          layer.draft.opacity,
          .45,
          reason: 'theme update must keep image opacity',
        );
        expect(
          layer.draft.color,
          readerImageHighlightColor(HighlightColor.blue),
          reason: 'theme update must keep the selected bright image colour',
        );
        expect(
          tester
              .widgetList<AppColorSwatchButton>(
                find.byType(AppColorSwatchButton),
              )
              .singleWhere((swatch) => swatch.selected)
              .color,
          layer.draft.color,
        );
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppColorSwatchButton &&
                widget.tooltip == strings.highlightColorGreen,
          ),
        );
        await tester.pump();
        expect(layer.draft.opacity, .45);
        expect(
          layer.draft.color,
          readerImageHighlightColor(HighlightColor.green),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets('a long press starts an image-area selection with controls', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.longPressAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final selection = tester
        .element(find.byType(FixedPagesView))
        .read<ReaderImageSelectionCubit>()
        .state;
    expect(selection.hasSelection, isTrue);
    expect(selection.pageIndex, 0);
    expect(
      selection.rect!.width,
      closeTo(ComicImageAreaGeometry.defaultWidth, 1e-6),
    );
    expect(selection.position, isNotNull);
    expect(find.byType(ReaderHighlightControls), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a tap outside the draft cancels it without turning the page', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.longPressAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ReaderHighlightControls), findsOneWidget);

    // In the left edge zone, where a plain tap turns back a page.
    await tester.tapAt(const Offset(30, 700));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(FixedPagesView));
    expect(
      element.read<ReaderImageSelectionCubit>().state.hasSelection,
      isFalse,
    );
    expect(find.byType(ReaderHighlightControls), findsNothing);
    expect(
      tester
          .widget<FixedPagesView>(find.byType(FixedPagesView))
          .controller
          .page,
      0,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'a color tap immediately followed by outside clears draft and popup together',
    (tester) async {
      await pumpReader(tester);
      await tester.longPressAt(const Offset(195, 422));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(FixedPagesView))
          .read<ReaderImageSelectionCubit>();
      final layer = tester.widget<ComicImageAreaLayer>(
        find.byWidgetPredicate(
          (widget) => widget is ComicImageAreaLayer && widget.page == 0,
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppColorSwatchButton &&
              widget.tooltip == l10n(tester).highlightColorBlue,
        ),
      );
      await tester.pump();
      expect(layer.draft.isActive, isTrue);
      await tester.tapAt(const Offset(30, 700));
      await tester.pump();
      expect(cubit.state, const ReaderImageSelectionState());
      expect(layer.draft.isActive, isFalse);
      expect(layer.controller.inputLocked, isFalse);
      expect(layer.controller.page, 0);
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'resize hides actions and mirrors only final committed geometry',
    (tester) async {
      await pumpReader(tester);
      await tester.longPressAt(const Offset(195, 422));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(FixedPagesView))
          .read<ReaderImageSelectionCubit>();
      final before = cubit.state;
      final emitted = <ReaderImageSelectionState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);
      final finder = find.byWidgetPredicate(
        (widget) => widget is ComicImageAreaLayer && widget.page == 0,
      );
      final layer = tester.widget<ComicImageAreaLayer>(finder);
      final rect = layer.draft.rect!;
      final corner = tester
          .renderObject<RenderBox>(finder)
          .localToGlobal(
            Offset(
              layer.imageRect.left + rect.right * layer.imageRect.width,
              layer.imageRect.top + rect.bottom * layer.imageRect.height,
            ),
          );
      final drag = await tester.startGesture(corner);
      await drag.moveBy(const Offset(25, 30));
      await tester.pump();
      await drag.moveBy(const Offset(25, 30));
      await tester.pump();
      expect(cubit.state.isAdjusting, isTrue);
      expect(cubit.state.rect, before.rect);
      expect(layer.draft.rect!.width, greaterThan(rect.width));
      expect(find.byType(ReaderHighlightControls), findsNothing);
      expect(emitted, hasLength(1));
      await drag.up();
      await tester.pumpAndSettle();
      final actual = layer.draft.rect!;
      expect(cubit.state.isAdjusting, isFalse);
      expect(cubit.state.rect!.x, closeTo(actual.left, 1e-6));
      expect(cubit.state.rect!.y, closeTo(actual.top, 1e-6));
      expect(cubit.state.rect!.width, closeTo(actual.width, 1e-6));
      expect(cubit.state.rect!.height, closeTo(actual.height, 1e-6));
      expect(emitted.map((state) => state.isAdjusting), [true, true, false]);
      expect(find.byType(ReaderHighlightControls), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'cancelling the note retains the area; Skip saves that same draft',
    (tester) async {
      await pumpReader(tester);
      await tester.longPressAt(const Offset(195, 422));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(FixedPagesView))
          .read<ReaderImageSelectionCubit>();
      final selected = cubit.state.rect!;
      final strings = l10n(tester);
      final layer = tester.widget<ComicImageAreaLayer>(
        find.byWidgetPredicate(
          (widget) => widget is ComicImageAreaLayer && widget.page == 0,
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppColorSwatchButton &&
              widget.tooltip == strings.highlightColorGreen,
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip(strings.highlightAction));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderHighlightNoteSheet), findsOneWidget);
      expect(layer.draft.retained, isTrue);
      await tester.tap(find.byTooltip(strings.commonClose).hitTestable());
      await tester.pumpAndSettle();
      expect(layer.draft.retained, isFalse);
      expect(layer.draft.isActive, isTrue);
      expect(cubit.state.rect, selected);
      expect(cubit.state.isAdjusting, isFalse);
      expect(highlights.imageAreaHighlights, isEmpty);
      await tester.tap(find.byTooltip(strings.highlightAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.readerSkip));
      await tester.pumpAndSettle();
      final saved = highlights.imageAreaHighlights.single;
      expect(saved.imageArea!.x, selected.x);
      expect(saved.imageArea!.y, selected.y);
      expect(saved.imageArea!.width, selected.width);
      expect(saved.imageArea!.height, selected.height);
      expect(saved.color, HighlightColor.green);
      expect(saved.note, isNull);
      expect(cubit.state, const ReaderImageSelectionState());
      expect(layer.draft.isActive, isFalse);
      expect(find.byType(ReaderHighlightControls), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  for (final cancelAfterFailure in [true, false]) {
    testWidgets(
      'failed area save keeps the draft for ${cancelAfterFailure ? 'Cancel' : 'retry'}',
      (tester) async {
        await pumpReader(tester);
        await tester.longPressAt(const Offset(195, 422));
        await tester.pumpAndSettle();
        final cubit = tester
            .element(find.byType(FixedPagesView))
            .read<ReaderImageSelectionCubit>();
        final selected = cubit.state.rect!;
        final strings = l10n(tester);
        final layer = tester.widget<ComicImageAreaLayer>(
          find.byWidgetPredicate(
            (widget) => widget is ComicImageAreaLayer && widget.page == 0,
          ),
        );
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppColorSwatchButton &&
                widget.tooltip == strings.highlightColorGreen,
          ),
        );
        await tester.pump();
        await tester.tap(find.byTooltip(strings.highlightAction));
        await tester.pumpAndSettle();
        highlights.shouldThrow = true;
        await tester.tap(find.text(strings.readerSkip));
        await tester.pumpAndSettle();
        expect(highlights.imageAreaHighlights, isEmpty);
        expect(layer.draft.isActive, isTrue);
        expect(layer.draft.retained, isFalse);
        expect(cubit.state.rect, selected);
        expect(
          tester
              .widget<ReaderHighlightControls>(
                find.byType(ReaderHighlightControls),
              )
              .busy,
          isFalse,
        );
        if (cancelAfterFailure) {
          await tester.tap(find.byTooltip(strings.commonCancel));
          await tester.pumpAndSettle();
          expect(cubit.state, const ReaderImageSelectionState());
          expect(layer.draft.isActive, isFalse);
        } else {
          highlights.shouldThrow = false;
          final gate = Completer<void>();
          highlights.addGate = gate.future;
          addTearDown(() {
            if (!gate.isCompleted) gate.complete();
          });
          await tester.tap(find.byTooltip(strings.highlightAction));
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.readerSkip));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final controls = find.byType(ReaderHighlightControls);
          expect(tester.widget<ReaderHighlightControls>(controls).busy, isTrue);
          expect(layer.draft.retained, isTrue);
          expect(cubit.state.rect, selected);
          expect(highlights.imageAreaHighlights, isEmpty);
          for (final button in tester.widgetList<AppPlainIconButton>(
            find.descendant(
              of: controls,
              matching: find.byType(AppPlainIconButton),
            ),
          )) {
            expect(button.onPressed, isNull);
          }
          for (final color in tester.widgetList<ReaderHighlightColorButton>(
            find.byType(ReaderHighlightColorButton),
          )) {
            expect(color.enabled, isFalse);
          }
          gate.complete();
          await tester.pumpAndSettle();
          final saved = highlights.imageAreaHighlights.single;
          expect(saved.imageArea!.x, selected.x);
          expect(saved.imageArea!.y, selected.y);
          expect(saved.imageArea!.width, selected.width);
          expect(saved.imageArea!.height, selected.height);
          expect(saved.color, HighlightColor.green);
          expect(cubit.state, const ReaderImageSelectionState());
          expect(layer.draft.isActive, isFalse);
        }
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'finishing a cancelled save refreshes its highlight without clearing the newer same-geometry draft',
    (tester) async {
      await pumpReader(tester);
      await tester.longPressAt(const Offset(195, 422));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FixedPagesView));
      final cubit = context.read<ReaderImageSelectionCubit>();
      final bloc = context.read<ReaderBloc>();
      final first = cubit.state;
      final strings = l10n(tester);
      final gate = Completer<void>();
      await beginGatedAreaSave(tester, gate);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(cubit.state.hasSelection, isFalse);
      await tester.longPressAt(const Offset(195, 422));
      await tester.pumpAndSettle();
      final second = cubit.state;
      expect(second.selectionId, isNot(first.selectionId));
      expect(second.rect, first.rect);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppColorSwatchButton &&
              widget.tooltip == strings.highlightColorBlue,
        ),
      );
      await tester.pump();
      final controls = tester.widget<ReaderHighlightControls>(
        find.byType(ReaderHighlightControls),
      );
      expect(
        controls.actions
            .singleWhere((action) => action.tooltip == strings.highlightAction)
            .onPressed,
        isNull,
      );
      expect(
        controls.actions
            .singleWhere((action) => action.tooltip == strings.commonCancel)
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widgetList<ReaderHighlightColorButton>(
              find.byType(ReaderHighlightColorButton),
            )
            .every((color) => color.enabled),
        isTrue,
      );
      await tester.tap(find.byTooltip(strings.highlightAction));
      await tester.pump();
      expect(find.byType(ReaderHighlightNoteSheet), findsNothing);
      expect(highlights.imageAreaHighlights, isEmpty);
      expect(find.text(strings.readerHighlightSaved), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(highlights.imageAreaHighlights, hasLength(1));
      expect(bloc.state.highlights, hasLength(1));
      expect(
        bloc.state.highlights.single.id,
        highlights.imageAreaHighlights.single.id,
      );
      expect(cubit.state.selectionId, second.selectionId);
      expect(cubit.state.rect, second.rect);
      expect(find.text(strings.readerHighlightSaved), findsNothing);
      final layer = tester.widget<ComicImageAreaLayer>(
        find.byWidgetPredicate(
          (widget) => widget is ComicImageAreaLayer && widget.page == 0,
        ),
      );
      expect(layer.draft.isActive, isTrue);
      expect(
        tester
            .widget<ReaderHighlightControls>(
              find.byType(ReaderHighlightControls),
            )
            .selectedColor,
        HighlightColor.blue,
      );

      await tester.tap(find.byTooltip(strings.highlightAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.readerSkip));
      await tester.pumpAndSettle();
      expect(highlights.imageAreaHighlights, hasLength(2));
      expect(highlights.imageAreaHighlights.last.color, HighlightColor.blue);
      expect(cubit.state.hasSelection, isFalse);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'a save finishing after Reader closes never uses the disposed context',
    (tester) async {
      await pumpReader(tester);
      await tester.longPressAt(const Offset(195, 422));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      await beginGatedAreaSave(tester, gate);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(highlights.imageAreaHighlights, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Contents shows the page grid with engine previews', (
    tester,
  ) async {
    await pumpReader(tester);
    final strings = l10n(tester);
    await tester.tap(await chromeControl(tester, strings.readerContents));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPageGrid), findsOneWidget);
    await settle(tester);
    expect(find.byType(RawImage), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _ScreenControlService implements ScreenControlService {
  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}

  @override
  Future<double?> readApplicationBrightness() async => 0.5;

  @override
  Future<void> setApplicationBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationBrightness() async {}
}
