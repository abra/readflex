import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_document_features.dart';
import 'package:reader/src/reader_screen_chrome.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  setUpAll(() async {
    for (final family in [
      'Geist',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      await (FontLoader(family)..addFont(
            rootBundle.load(
              'packages/component_library/fonts/Geist-Variable.ttf',
            ),
          ))
          .load();
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final format in <BookFormat?>[...BookFormat.values, null]) {
      testWidgets(
        '$platform ${format?.name ?? 'article'} controls: phone RTL at 200%',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final (preferences, bloc) = (await tester.runAsync(
            () => _load(format),
          ))!;
          addTearDown(() async {
            await bloc.close();
            preferences.dispose();
          });
          final presses = <String>[];
          await tester.pumpWidget(
            PlatformTestApp(
              platform: platform,
              locale: const Locale('ar'),
              textScale: 2,
              supportedLocales: ReadflexSupportedLocales.locales,
              localizationsDelegates: readflexLocalizationsDelegates,
              home: _ChromeHarness(
                bloc: bloc,
                preferences: preferences,
                presses: presses,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final capsule = find.byKey(const ValueKey('readerChromeCapsule'));
          final buttons = find.descendant(
            of: capsule,
            matching: find.byType(AppPlainIconButton),
          );
          final l10n = tester.element(capsule).l10n;
          final imagePages =
              format == BookFormat.cbz || format == BookFormat.djvu;
          final expected = [
            l10n.readerBack,
            l10n.readerContents,
            if (imagePages)
              l10n.readerPageTurnHorizontal
            else if (format == BookFormat.pdf)
              l10n.readerAppearanceTitle
            else
              l10n.readerFontAction,
            l10n.readerBookmark,
            if (format != BookFormat.cbz) l10n.readerSearchAction,
          ];
          expect(
            tester
                .widgetList<AppPlainIconButton>(buttons)
                .map((button) => button.tooltip),
            expected,
          );
          for (final button in tester.widgetList<AppPlainIconButton>(buttons)) {
            expect(button.onPressed, isNotNull, reason: button.tooltip);
          }

          if (format == BookFormat.pdf || format == BookFormat.djvu) {
            final staticPolicy = bloc.state.formatCapabilities;
            for (final hasText in [null, false, true]) {
              final features = ReaderDocumentFeatures(
                format: format!.name,
                hasSearchableText: hasText,
                hasTableOfContents: false,
                pageCount: 12,
              );
              await tester.runAsync(() async {
                final changed = bloc.stream.firstWhere(
                  (state) => state.documentFeatures == features,
                );
                bloc.add(ReaderDocumentFeaturesUpdated(features: features));
                await changed.timeout(const Duration(seconds: 3));
              });
              await tester.pumpAndSettle();
              expect(
                identical(bloc.state.formatCapabilities, staticPolicy),
                isTrue,
              );
              final search = find.descendant(
                of: capsule,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is AppPlainIconButton &&
                      widget.tooltip == l10n.readerSearchAction,
                ),
              );
              expect(
                tester.widget<AppPlainIconButton>(search).onPressed,
                isNotNull,
              );
              await tester.tap(search);
              expect(presses.last, 'search');
              expect(tester.takeException(), isNull);
            }
          }
        },
      );
    }
  }
}

Future<(PreferencesService, ReaderBloc)> _load(BookFormat? format) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final preferences = await PreferencesService.create(
    supportedCodes: const ['en', 'ar'],
  );
  final books = FakeBookRepository();
  final articles = FakeArticleRepository();
  if (format == null) {
    articles.seedArticle(
      Article(
        id: 'source',
        title: 'Saved article',
        url: 'https://example.com/article',
        contentPath: '/fixture/article.json',
        addedAt: DateTime(2026),
      ),
    );
  } else {
    books.seedBook(
      Book(
        id: 'source',
        title: 'Book',
        filePath: '/fixture.${format.name}',
        format: format,
        addedAt: DateTime(2026),
      ),
    );
  }
  final bloc = ReaderBloc(
    bookRepository: books,
    articleRepository: articles,
    highlightRepository: FakeHighlightRepository(),
  );
  bloc.add(const ReaderSourceLoadRequested(sourceId: 'source'));
  await bloc.stream
      .firstWhere((state) => state.status == ReaderStatus.ready)
      .timeout(const Duration(seconds: 3));
  return (preferences, bloc);
}

class _ChromeHarness extends StatelessWidget {
  const _ChromeHarness({
    required this.bloc,
    required this.preferences,
    required this.presses,
  });

  final ReaderBloc bloc;
  final PreferencesService preferences;
  final List<String> presses;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: bloc),
      BlocProvider(create: (_) => ReaderUiCubit()..showChrome()),
      BlocProvider(create: (_) => ReaderSelectionCubit()),
      BlocProvider(
        create: (_) => ReaderAppearanceCubit(
          preferencesService: preferences,
          sourceId: 'source',
        ),
      ),
    ],
    child: Stack(
      children: [
        ReaderBottomChromeDriver(
          readerTheme: ReaderThemePreset.paper.data,
          onTocPressed: () => presses.add('contents'),
          onFontPressed: () => presses.add('appearance'),
          onPageTurnPressed: () => presses.add('pageTurn'),
          onBookmarkPressed: () => presses.add('bookmark'),
          onSearchPressed: () => presses.add('search'),
          onSeekFraction: (_) {},
        ),
      ],
    ),
  );
}
