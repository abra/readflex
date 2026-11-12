import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoApp;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show DefaultTabController;
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_contents_tab_bar.dart';
import 'package:reader/src/reader_drawer_layout.dart';
import 'package:reader/src/reader_page_grid.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_search_event.dart';
import 'package:reader/src/reader_search_panel.dart';
import 'package:reader/src/reader_toc_item.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  setUpAll(() async {
    final font = await rootBundle.load(
      'packages/component_library/fonts/Geist-Variable.ttf',
    );
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });
  for (final (name, locale, size, scale) in [
    ('default', const Locale('en'), const Size(390, 844), 1.0),
    ('long German labels', const Locale('de'), const Size(320, 568), 2.0),
    ('RTL large text', const Locale('ar'), const Size(320, 568), 2.0),
  ]) {
    testWidgets(
      'Cupertino comic Contents has shared chrome and recovers $name',
      (
        tester,
      ) async {
        _configure(tester, size);
        final bloc = (await tester.runAsync(_comicBloc))!;
        addTearDown(bloc.close);
        final visible = ValueNotifier(true);
        addTearDown(visible.dispose);
        final selected = <ReaderTocItem>[];
        await tester.pumpWidget(
          PlatformTestApp(
            platform: TargetPlatform.iOS,
            locale: locale,
            textScale: scale,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: _ComicPanelHarness(
              bloc: bloc,
              visible: visible,
              onSelected: selected.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoApp), findsOneWidget);
        final context = tester.element(find.byType(ReaderTocDrawerDriver));
        final l10n = context.l10n;
        _expectSharedHeader(tester, l10n.readerContents);
        final grid = tester.widget<GridView>(find.byType(GridView));
        expect((grid.padding! as EdgeInsets).left, 24);
        expect((grid.padding! as EdgeInsets).right, 24);
        await tester.tap(find.text(l10n.readerBookmarks));
        await tester.pumpAndSettle();
        final field = find.byType(AppTextField).hitTestable();
        await tester.enterText(field, 'Anchor');
        await tester.pumpAndSettle();
        final fieldState = tester.state(
          find.byType(EditableText).hitTestable(),
        );
        final list = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        final scroll = tester.state<ScrollableState>(list).position;
        scroll.jumpTo(100);
        await tester.pumpAndSettle();
        final offset = scroll.pixels;
        final header = tester.getRect(find.byType(BottomSheetHeader));
        final fieldBounds = tester.getRect(field);
        expect(fieldBounds.left - header.left, 24);
        expect(header.right - fieldBounds.right, 24);
        await tester.tap(find.byTooltip(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(visible.value, isFalse);
        expect(find.byType(BottomSheetHeader), findsNothing);
        await tester.tap(find.byKey(const ValueKey('reopen-panel')));
        await tester.pumpAndSettle();
        expect(visible.value, isTrue);
        final tabContext = tester.element(find.byType(ReaderContentsTabBar));
        expect(DefaultTabController.of(tabContext).index, 1);
        expect(
          tester.state(find.byType(EditableText).hitTestable()),
          same(fieldState),
        );
        expect(tester.widget<AppTextField>(field).controller!.text, 'Anchor');
        expect(tester.state<ScrollableState>(list).position, same(scroll));
        expect(scroll.pixels, offset);
        await tester.tap(find.text(l10n.readerHighlights));
        await tester.pumpAndSettle();
        expect(DefaultTabController.of(tabContext).index, 2);
        await tester.tap(find.text(l10n.readerPages));
        await tester.pumpAndSettle();
        expect(find.byType(ReaderPageGrid), findsOneWidget);
        final page = find.text(l10n.readerPageNumber(2));
        await tester.scrollUntilVisible(
          page,
          100,
          scrollable: find.descendant(
            of: find.byType(ReaderPageGrid),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.ensureVisible(page);
        await tester.pumpAndSettle();
        await tester.tap(page);
        await tester.pumpAndSettle();
        expect(selected.single.href, 'page-1');
        expect(visible.value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cupertino Reader Search retains state and its expanded sidebar',
    (
      tester,
    ) async {
      _configure(tester, const Size(390, 844));
      final cubit = ReaderSearchCubit();
      addTearDown(cubit.close);
      cubit.recentQuerySelected(
        'devices',
        searchBook: (_) => Stream.fromIterable([
          ReaderSearchResults(
            requestId: 1,
            results: List.generate(
              40,
              (index) => ReaderSearchResult(
                cfi: 'cfi-$index',
                chapterTitle: 'Chapter $index',
                excerpt: const ReaderSearchExcerpt(
                  pre: 'The ',
                  match: 'devices',
                  post: ' run.',
                ),
              ),
            ),
          ),
          const ReaderSearchDone(requestId: 1),
        ]),
      );
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      var searches = 0;
      await tester.pumpWidget(
        PlatformTestApp(
          platform: TargetPlatform.iOS,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          home: BlocProvider.value(
            value: cubit,
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, shown, _) => Stack(
                children: [
                  Center(
                    child: AppButton(
                      key: const ValueKey('reopen-panel'),
                      onPressed: () => visible.value = true,
                      child: const Text('Reopen'),
                    ),
                  ),
                  ReaderSearchPanel(
                    visible: shown,
                    format: BookFormat.epub,
                    pageProgressionRtl: false,
                    onClose: () => visible.value = false,
                    onSearch: (_) {
                      searches++;
                      return const Stream.empty();
                    },
                    onResultSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectSharedHeader(tester, 'Search');
      final field = find.byType(AppTextField).hitTestable();
      final editor = tester.state(find.byType(EditableText).hitTestable());
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(150);
      await tester.pumpAndSettle();
      final offset = list.controller!.offset;
      final results = cubit.state.results;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reopen-panel')));
      await tester.pumpAndSettle();
      expect(tester.widget<AppTextField>(field).controller!.text, 'devices');
      expect(
        tester.state(find.byType(EditableText).hitTestable()),
        same(editor),
      );
      expect(list.controller!.offset, offset);
      expect(cubit.state.results, same(results));
      expect(searches, 0);
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheetHeader), findsNothing);
      final sidebarField = tester.getRect(field);
      expect(sidebarField.width, 420 - 32);
      expect(readerDrawerContentInset(tester.element(field)), 16);
      expect(
        tester.state(find.byType(EditableText).hitTestable()),
        same(editor),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _configure(WidgetTester tester, Size size) {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _expectSharedHeader(WidgetTester tester, String title) {
  final header = find.byType(BottomSheetHeader);
  expect(header, findsOneWidget);
  final label = find.text(title);
  final paragraph = tester.renderObject<RenderParagraph>(label);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(tester.widget<Text>(label).maxLines, isNull);
  expect(tester.getCenter(label).dx, closeTo(tester.getCenter(header).dx, .01));
  expect(
    tester.widget<BottomSheetHeader>(header).padding,
    const EdgeInsets.symmetric(horizontal: 24),
  );
  final close = find.descendant(
    of: header,
    matching: find.byType(AppPlainIconButton),
  );
  expect(tester.getSize(close), const Size(48, 48));
  expect(tester.widget<AppPlainIconButton>(close).iconWidget, isNotNull);
  final circle = find.descendant(
    of: close,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  expect(tester.getSize(circle), const Size(28, 28));
}

Future<ReaderBloc> _comicBloc() async {
  final book = Book(
    id: 'comic',
    title: 'Comic',
    filePath: '/comic.cbz',
    format: BookFormat.cbz,
    addedAt: DateTime(2026),
  );
  final repository = FakeBookRepository()
    ..seedBook(book)
    ..seedBookmarks(book.id, [
      for (var index = 0; index < 40; index++)
        SourceBookmark(
          id: 'bookmark-$index',
          sourceId: book.id,
          sourceType: SourceType.book,
          cfi: 'page-$index',
          content: 'Anchor page $index',
          progress: index / 40,
          createdAt: DateTime(2026),
        ),
    ]);
  final bloc = ReaderBloc(
    bookRepository: repository,
    highlightRepository: FakeHighlightRepository(),
    initialSource: book,
  );
  bloc.add(ReaderSourceLoadRequested(sourceId: book.id));
  await bloc.stream.firstWhere((state) => state.status == ReaderStatus.ready);
  bloc.add(
    ReaderTocUpdated(
      items: [
        for (var index = 0; index < 40; index++)
          ReaderTocItem(
            label: 'Page ${index + 1}',
            href: 'page-$index',
            level: 1,
            startPercentage: index / 40,
          ),
      ],
    ),
  );
  await bloc.stream.firstWhere((state) => state.tocItems.length == 40);
  return bloc;
}

class _ComicPanelHarness extends StatelessWidget {
  const _ComicPanelHarness({
    required this.bloc,
    required this.visible,
    required this.onSelected,
  });
  final ReaderBloc bloc;
  final ValueNotifier<bool> visible;
  final ValueChanged<ReaderTocItem> onSelected;

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: bloc,
    child: ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, shown, _) => Stack(
        children: [
          Center(
            child: AppButton(
              key: const ValueKey('reopen-panel'),
              onPressed: () => visible.value = true,
              child: const Text('Reopen'),
            ),
          ),
          ReaderTocDrawerDriver(
            loadThumbnail: (_) async => null,
            visible: shown,
            format: BookFormat.cbz,
            pageProgressionRtl: false,
            readerTheme: ReaderThemePreset.paper.data,
            onClose: () => visible.value = false,
            onItemSelected: (item) {
              onSelected(item);
              visible.value = false;
            },
            onPageSelected: (_) {},
            onBookmarkSelected: (_) {},
            onHighlightSelected: (_) {},
            onBookmarkDeleted: (_) {},
          ),
        ],
      ),
    ),
  );
}
