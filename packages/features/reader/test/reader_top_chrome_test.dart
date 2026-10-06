import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _articleTitleTests();

  test('top chrome title keeps base font size when it fits', () {
    const baseStyle = TextStyle(fontSize: 16);

    final style = readerTopChromeTitleStyleForText(
      title: 'Short title',
      baseStyle: baseStyle,
      textDirection: TextDirection.ltr,
      maxWidth: 320,
    );

    expect(style.fontSize, 16);
  });

  test('top chrome title reduces font size for long titles', () {
    const baseStyle = TextStyle(fontSize: 16);

    final style = readerTopChromeTitleStyleForText(
      title:
          'The Trash Droid Files: Phoenix Rising: Book 1 '
          'A Sci Fi Adventure Thriller for Adults Who Love Robot Fiction',
      baseStyle: baseStyle,
      textDirection: TextDirection.ltr,
      maxWidth: 320,
    );

    expect(style.fontSize, lessThan(16));
    expect(style.fontSize, greaterThanOrEqualTo(8));
  });

  test('top chrome title does not shrink below the minimum', () {
    const baseStyle = TextStyle(fontSize: 16);

    final style = readerTopChromeTitleStyleForText(
      title: List.filled(100, 'word').join(' '),
      baseStyle: baseStyle,
      textDirection: TextDirection.ltr,
      maxWidth: 220,
    );

    expect(style.fontSize, 8);
  });
}

void _articleTitleTests() {
  final article = Article(
    id: 'article-1',
    title: 'Saved Article',
    url: 'https://example.com/article',
    siteName: 'Example',
    contentPath: '/articles/article-1/article.json',
    addedAt: DateTime(2024, 1, 1),
  );
  late ReaderBloc bloc;
  late ReaderUiCubit uiCubit;
  late ReaderSelectionCubit selectionCubit;

  setUp(() async {
    bloc = ReaderBloc(
      bookRepository: FakeBookRepository(),
      articleRepository: FakeArticleRepository()..seedArticle(article),
      highlightRepository: FakeHighlightRepository(),
    );
    bloc.add(ReaderSourceLoadRequested(sourceId: article.id));
    await bloc.stream
        .firstWhere((s) => s.status == ReaderStatus.ready)
        .timeout(const Duration(seconds: 3));
    uiCubit = ReaderUiCubit()..showChrome();
    selectionCubit = ReaderSelectionCubit();
  });

  tearDown(() async {
    await bloc.close();
    await uiCubit.close();
    await selectionCubit.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    void Function(String url, String title)? onArticleTitlePressed,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: uiCubit),
            BlocProvider.value(value: selectionCubit),
          ],
          child: Scaffold(
            body: Stack(
              children: [
                ReaderTopChromeDriver(
                  onArticleTitlePressed: onArticleTitlePressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('article title is an accessible ink button', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <String>[];
    await pump(tester, onArticleTitlePressed: (url, _) => opened.add(url));
    final l10n = tester.element(find.byType(Scaffold)).l10n;
    final button = find.byKey(const ValueKey('readerArticleTitleButton'));
    expect(button, findsOneWidget);
    expect(tester.widget<InkWell>(button).onTap, isNotNull);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    final node = tester.getSemantics(
      find.bySemanticsLabel(l10n.readerOpenOriginalArticle),
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);
    expect(node.value, 'Saved Article');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      find.descendant(of: button, matching: find.byType(GestureDetector)),
      findsOneWidget,
      reason: 'only the ink response gesture, no bare GestureDetector',
    );
    await tester.tap(find.text('Saved Article'));
    await tester.pumpAndSettle();
    expect(opened, ['https://example.com/article']);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('title is plain text without an opener', (tester) async {
    await pump(tester);
    expect(
      find.byKey(const ValueKey('readerArticleTitleButton')),
      findsNothing,
    );
    expect(find.text('Saved Article'), findsOneWidget);
  });

  testWidgets('top chrome keeps the 16dp content gutter like the bottom bar', (
    tester,
  ) async {
    await pump(tester);
    final padding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.text('Saved Article'),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
  });

  testWidgets('top chrome hides in one frame under reduced motion', (
    tester,
  ) async {
    await pump(tester, disableAnimations: true);
    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide.duration, Duration.zero);
    uiCubit.hideChrome();
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(find.byType(SafeArea)).bottom, lessThanOrEqualTo(0));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
