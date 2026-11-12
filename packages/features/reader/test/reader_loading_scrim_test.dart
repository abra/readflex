import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsRole;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:pagecraft/testing.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

final _progress = find.byKey(const ValueKey('readerLoadingProgress'));

enum _SourceKind { text, article, comic, pdf }

void main() {
  late Directory directory;
  late PreferencesService preferences;
  late _GatedBookRepository books;
  late FakeArticleRepository articles;

  setUpAll(preparePdfEngineForTests);

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ar'],
    );
    directory = Directory.systemTemp.createTempSync('reader_loading_');
    books = _GatedBookRepository();
    articles = FakeArticleRepository();
  });

  tearDown(() async {
    books.release();
    await preferences.dispose();
    directory.deleteSync(recursive: true);
  });

  Future<void> pumpReader(
    WidgetTester tester,
    String sourceId, {
    bool reduceMotion = false,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size window = const Size(390, 844),
  }) async {
    books.delayNextLoad();
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      books.release();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      _ReaderHarness(
        sourceId: sourceId,
        books: books,
        articles: articles,
        preferences: preferences,
        reduceMotion: reduceMotion,
        locale: locale,
        textScaler: textScaler,
      ),
    );
    await tester.pump();
  }

  for (final kind in _SourceKind.values) {
    testWidgets(
      '${kind.name} keeps one loading indicator until its first page',
      (
        tester,
      ) async {
        final sourceId = _seedSource(kind, directory, books, articles);
        await pumpReader(tester, sourceId);

        expect(_readerState(tester).status, ReaderStatus.loading);
        _expectLoading(tester);
        expect(TickerMode.valuesOf(tester.element(_progress)).enabled, isTrue);
        expect(tester.hasRunningAnimations, isTrue);

        books.release();
        await tester.pump();
        // Metadata resolves on the fake clock. Native file I/O has not been
        // advanced, so a ready bloc must stay covered until the page exists.
        expect(_readerState(tester).status, ReaderStatus.ready);
        expect(_page(kind), findsNothing);
        _expectLoading(tester);

        await _waitForSurface(tester);
        expect(_page(kind), findsWidgets);
        _expectInactive(tester);
        await _settle(tester);
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reduced motion keeps pending loading visible without ticking', (
    tester,
  ) async {
    final sourceId = _seedSource(_SourceKind.text, directory, books, articles);
    await pumpReader(tester, sourceId, reduceMotion: true);

    _expectLoading(tester);
    expect(TickerMode.valuesOf(tester.element(_progress)).enabled, isFalse);
    await _settle(tester);
    expect(_readerState(tester).status, ReaderStatus.loading);
    expect(tester.hasRunningAnimations, isFalse);
    _expectLoading(tester);
  });

  testWidgets('failure stops loading and Retry starts it again', (
    tester,
  ) async {
    final sourceId = _seedSource(_SourceKind.text, directory, books, articles);
    books.failNextLoad = true;
    await pumpReader(tester, sourceId);
    _expectLoading(tester);

    books.release();
    await tester.pump();
    expect(_readerState(tester).status, ReaderStatus.failure);
    expect(find.byType(ErrorState), findsOneWidget);
    _expectInactive(tester);
    await _settle(tester);
    expect(tester.hasRunningAnimations, isFalse);

    books.delayNextLoad();
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_readerState(tester).status, ReaderStatus.loading);
    expect(TickerMode.valuesOf(tester.element(_progress)).enabled, isTrue);
    _expectLoading(tester);

    books.release();
    await tester.pump();
    await _waitForSurface(tester);
    expect(books.loadCalls, 2);
    _expectInactive(tester);
    await _settle(tester);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'loading uses reader colors on a small RTL phone with large text',
    (
      tester,
    ) async {
      await preferences.update(
        (value) => value.copyWith(readerThemeId: ReaderThemePreset.mist.id),
      );
      final sourceId = _seedSource(
        _SourceKind.text,
        directory,
        books,
        articles,
      );
      await pumpReader(
        tester,
        sourceId,
        locale: const Locale('ar'),
        textScaler: const TextScaler.linear(2),
        window: const Size(320, 568),
      );

      _expectLoading(tester);
      final readerTheme = ReaderThemePreset.mist.data;
      final indicator = tester.widget<AppProgressIndicator>(_progress);
      expect(
        indicator.color,
        readerTheme.primaryTextColor.withValues(alpha: 0.82),
      );
      final scrim = find.ancestor(
        of: _progress,
        matching: find.byType(ColoredBox),
      );
      expect(
        tester.widget<ColoredBox>(scrim.first).color,
        readerTheme.backgroundColor,
      );
      expect(tester.getSize(_progress), const Size.square(28));
      expect(tester.getCenter(_progress), const Offset(160, 284));
      expect(Directionality.of(tester.element(_progress)), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    },
  );
}

ReaderState _readerState(WidgetTester tester) =>
    tester.element(_progress).read<ReaderBloc>().state;

AnimatedOpacity _loadingOpacity(WidgetTester tester) => tester.widget(
  find.ancestor(of: _progress, matching: find.byType(AnimatedOpacity)),
);

String _loadingLabel(WidgetTester tester) =>
    ReadflexLocalizations.of(tester.element(_progress))!.readerLoadingContent;

void _expectLoading(WidgetTester tester) {
  expect(_progress, findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(tester.widget<AppProgressIndicator>(_progress).value, isNull);
  expect(_loadingOpacity(tester).opacity, 1);
  expect(find.byIcon(AppIcons.book), findsNothing);
  expect(find.semantics.byLabel(_loadingLabel(tester)), findsOneWidget);
  final data = tester.getSemantics(_progress).getSemanticsData();
  expect(data.role, SemanticsRole.loadingSpinner);
  expect(data.value, isEmpty);
}

void _expectInactive(WidgetTester tester) {
  // The scrim remains mounted for its fade, but never keeps work scheduled
  // or announces loading after the page is ready or has failed.
  expect(_progress, findsOneWidget);
  expect(_loadingOpacity(tester).opacity, 0);
  expect(TickerMode.valuesOf(tester.element(_progress)).enabled, isFalse);
  expect(find.semantics.byLabel(_loadingLabel(tester)), findsNothing);
}

Future<void> _waitForSurface(WidgetTester tester) async {
  for (var i = 0; i < 300 && _loadingOpacity(tester).opacity != 0; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorState), findsNothing);
  }
  expect(_loadingOpacity(tester).opacity, 0, reason: 'first page timed out');
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}

Finder _page(_SourceKind kind) => switch (kind) {
  _SourceKind.text || _SourceKind.article => find.byType(TextColumnPage),
  _SourceKind.comic || _SourceKind.pdf => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is FixedPagePainter,
  ),
};

String _seedSource(
  _SourceKind kind,
  Directory directory,
  FakeBookRepository books,
  FakeArticleRepository articles,
) {
  final id = 'loading-${kind.name}';
  if (kind == _SourceKind.article) {
    File('${directory.path}/content.html').writeAsStringSync(
      '<h1 id="title">Loading test</h1>'
      '<p id="opening">The first sentence is ready to read. '
      'Another sentence completes this short article.</p>',
    );
    articles.seedArticle(
      Article(
        id: id,
        title: 'Loading test',
        url: 'https://example.com/article',
        contentPath: '${directory.path}/article.json',
        addedAt: DateTime(2026),
      ),
    );
    return id;
  }

  final format = switch (kind) {
    _SourceKind.text => BookFormat.fb2,
    _SourceKind.comic => BookFormat.cbz,
    _SourceKind.pdf => BookFormat.pdf,
    _SourceKind.article => throw StateError('Article seeded separately'),
  };
  final file = File('${directory.path}/book.${format.name}');
  switch (kind) {
    case _SourceKind.text:
      file.writeAsStringSync(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">'
        '<description><title-info><book-title>Loading test</book-title>'
        '<lang>en</lang></title-info></description><body><section>'
        '<title><p>Opening</p></title><p>The first page is ready to read. '
        'Another sentence completes this short book.</p>'
        '</section></body></FictionBook>',
      );
    case _SourceKind.comic:
      file.writeAsBytesSync(buildComicArchive(portraitPages(2)));
    case _SourceKind.pdf:
      final fixture = [
        File('../../pagecraft/test/fixtures/pdf/text_outline.pdf'),
        File('packages/pagecraft/test/fixtures/pdf/text_outline.pdf'),
      ].firstWhere((candidate) => candidate.existsSync());
      file.writeAsBytesSync(fixture.readAsBytesSync());
    case _SourceKind.article:
      throw StateError('Article seeded separately');
  }
  books.seedBook(
    Book(
      id: id,
      title: 'Loading test',
      filePath: file.path,
      format: format,
      addedAt: DateTime(2026),
      comicPageOrderVersion: kind == _SourceKind.comic ? 1 : 0,
    ),
  );
  return id;
}

class _GatedBookRepository extends FakeBookRepository {
  Completer<void> _gate = Completer<void>();
  bool failNextLoad = false;
  int loadCalls = 0;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  void delayNextLoad() => _gate = Completer<void>();

  @override
  Future<Book?> getBookById(String id) async {
    loadCalls++;
    await _gate.future;
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('Storage unavailable');
    }
    return super.getBookById(id);
  }
}

class _ReaderHarness extends StatelessWidget {
  const _ReaderHarness({
    required this.sourceId,
    required this.books,
    required this.articles,
    required this.preferences,
    required this.reduceMotion,
    required this.locale,
    required this.textScaler,
  });

  final String sourceId;
  final FakeBookRepository books;
  final FakeArticleRepository articles;
  final PreferencesService preferences;
  final bool reduceMotion;
  final Locale locale;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: readflexLocalizationsDelegates,
    supportedLocales: ReadflexLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: textScaler,
      ),
      child: child!,
    ),
    home: ReaderScreen(
      sourceId: sourceId,
      bookRepository: books,
      articleRepository: articles,
      highlightRepository: FakeHighlightRepository(),
      preferencesService: preferences,
      screenControlService: _ScreenControlService(),
      textActions: const [],
    ),
  );
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
