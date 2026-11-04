import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/djvu.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_image_selection_cubit.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../pagecraft/test/formats/djvu/djvu_fixture.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  late Directory directory;
  late PreferencesService preferences;
  late FakeBookRepository books;
  late FakeHighlightRepository highlights;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    directory = Directory.systemTemp.createTempSync('reader-djvu-screen-');
    final path = '${directory.path}/original.djvu';
    File(path).writeAsBytesSync(djvuFixtureBytes());
    books = FakeBookRepository();
    highlights = FakeHighlightRepository();
    books.seedBook(
      Book(
        id: 'djvu-1',
        title: 'Original DjVu fixture',
        filePath: path,
        format: BookFormat.djvu,
        addedAt: DateTime(2026, 1, 1),
      ),
    );
  });

  tearDown(() {
    preferences.dispose();
    directory.deleteSync(recursive: true);
  });

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() ready,
  ) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 120; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 16));
        if (ready()) return;
      }
    });
    expect(ready(), isTrue, reason: 'native DjVu page/text preparation');
    await tester.pump();
  }

  Future<void> showReader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: ReaderScreen(
          sourceId: 'djvu-1',
          bookRepository: books,
          highlightRepository: highlights,
          preferencesService: preferences,
          screenControlService: const NoopScreenControlService(),
          textActions: const [],
        ),
      ),
    );
    await waitFor(tester, () {
      final views = tester.widgetList<FixedPagesView>(
        find.byType(FixedPagesView),
      );
      return views.isNotEmpty &&
          views.first.pages is DjvuPages &&
          tester
              .widgetList<DjvuTextOverlay>(find.byType(DjvuTextOverlay))
              .any(
                (overlay) => overlay.layer?.isEmpty == false,
              );
    });
  }

  Future<void> closeReader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'opens native pages, reports capabilities and persists page turns',
    (
      tester,
    ) async {
      await showReader(tester);
      final view = tester.widget<FixedPagesView>(find.byType(FixedPagesView));
      final context = tester.element(find.byType(FixedPagesView));
      final bloc = context.read<ReaderBloc>();
      expect(view.pages.pageCount, 3);
      expect(bloc.state.documentFeatures?.format, 'djvu');
      expect(bloc.state.documentFeatures?.hasSearchableText, isTrue);
      expect(bloc.state.documentFeatures?.pageCount, 3);
      view.controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(bloc.state.document?.readingProgress, closeTo(2 / 3, 1e-9));
      expect(bloc.state.document?.currentCfi, fakeCfiFromIndex(1));
      await closeReader(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      expect(
        (await books.getBookById('djvu-1'))?.currentCfi,
        fakeCfiFromIndex(1),
      );
    },
  );

  testWidgets('hidden-word long press reaches reader text actions', (
    tester,
  ) async {
    await showReader(tester);
    final finder = find.byType(DjvuTextOverlay).first;
    final overlay = tester.widget<DjvuTextOverlay>(finder);
    final word = overlay.layer!.words
        .firstWhere((word) => word.text == 'Quiet')
        .box
        .center;
    final point =
        tester.getTopLeft(finder) +
        Offset(
          overlay.imageRect.left +
              word.dx / overlay.pageWidth * overlay.imageRect.width,
          overlay.imageRect.top +
              word.dy / overlay.pageHeight * overlay.imageRect.height,
        );
    await tester.longPressAt(point);
    await tester.pump();
    final context = tester.element(find.byType(FixedPagesView));
    final selected = context.read<ReaderSelectionCubit>().state;
    expect(selected.hasSelection, isTrue);
    expect(selected.selectedText, 'Quiet');
    expect(selected.cfiRange, startsWith('epubcfi(/6/2!/2[pagecraft-djvu]'));
    expect(
      context.read<ReaderImageSelectionCubit>().state.hasSelection,
      isFalse,
    );
    await closeReader(tester);
  });

  testWidgets('scan-only page mounts image-area selection instead of text', (
    tester,
  ) async {
    await showReader(tester);
    tester
        .widget<FixedPagesView>(find.byType(FixedPagesView))
        .controller
        .goToPage(2);
    await tester.pump();
    await waitFor(
      tester,
      () => find.byType(ComicImageAreaLayer).evaluate().isNotEmpty,
    );
    expect(find.byType(DjvuTextOverlay), findsNothing);
    final layer = tester.widget<ComicImageAreaLayer>(
      find.byType(ComicImageAreaLayer),
    );
    layer.onDraftCommitted?.call(
      const Rect.fromLTWH(0.1, 0.15, 0.4, 0.2),
      null,
    );
    await tester.pump();
    final context = tester.element(find.byType(FixedPagesView));
    expect(
      context.read<ReaderImageSelectionCubit>().state.hasSelection,
      isTrue,
    );
    expect(context.read<ReaderSelectionCubit>().state.hasSelection, isFalse);
    await closeReader(tester);
  });
}
