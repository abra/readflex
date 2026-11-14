import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_article_progress_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_brightness_cubit.dart';
import 'package:reader/src/reader_floating_chrome_layout.dart';
import 'package:reader/src/reader_screen_chrome.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

const _pillKey = ValueKey('readerBrightnessChromeIgnorePointer');
const _dockKey = ValueKey('readerChromeDock');
const _boundaryKey = ValueKey('readerChromeBoundary');
const _articleProgressKey = ValueKey('readerArticleProgress');

void main() {
  setUpAll(() async {
    final font = rootBundle.load(
      'packages/component_library/fonts/Geist-Variable.ttf',
    );
    for (final family in [
      'Geist',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
    ]) {
      await (FontLoader(family)..addFont(font)).load();
    }
    final arabic = await File('../../../test/fonts/NotoSansArabic.ttf')
        .readAsBytes();
    await (FontLoader('Noto Sans Arabic')..addFont(
          Future.value(ByteData.sublistView(arabic)),
        ))
        .load();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      for (final rtl in [false, true]) {
        testWidgets('$platform $size rtl=$rtl retains original positions', (
          tester,
        ) async {
          _configure(tester, size);
          final fixture = (await tester.runAsync(_Fixture.create))!;
          addTearDown(() async {
            await tester.runAsync(fixture.dispose);
          });
          await fixture.pump(
            tester,
            platform: platform,
            rtl: rtl,
            scale: rtl ? 2 : 1,
            sharedLayout: false,
          );
          final oldPill = tester.getRect(find.byKey(_pillKey));
          final oldDock = tester.getRect(find.byKey(_dockKey));
          final oldTitle = tester.getRect(
            find.byKey(const ValueKey('readerTopChromeLine')),
          );
          final progress = [
            find.byType(AppSlider),
            find.byKey(const ValueKey('readerProgressStartLabel')),
            find.byKey(const ValueKey('readerProgressPageLabel')),
          ];
          final oldProgress = progress.map(tester.getRect).toList();
          await fixture.pump(
            tester,
            platform: platform,
            rtl: rtl,
            scale: rtl ? 2 : 1,
          );
          expect(tester.getRect(find.byKey(_pillKey)), oldPill);
          expect(tester.getRect(find.byKey(_dockKey)), oldDock);
          expect(
            tester.getRect(find.byKey(const ValueKey('readerTopChromeLine'))),
            oldTitle,
          );
          expect(progress.map(tester.getRect).toList(), oldProgress);
          final slider = tester.element(find.byType(AppSlider));
          final pill = tester.element(find.byKey(_pillKey));
          fixture.ui.hideChrome();
          await tester.pumpAndSettle();
          fixture.ui.showChrome();
          await tester.pumpAndSettle();
          expect(tester.element(find.byType(AppSlider)), same(slider));
          expect(tester.element(find.byKey(_pillKey)), same(pill));
          expect(tester.getRect(find.byKey(_pillKey)), oldPill);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final rtl in [false, true]) {
      testWidgets('$platform compact article progress stays above its backdrop '
          'rtl=$rtl', (tester) async {
        _configure(tester, const Size(568, 320));
        tester.view.padding = const FakeViewPadding(
          top: 24,
          bottom: 34,
          left: 11,
          right: 17,
        );
        final fixture = (await tester.runAsync(
          () => _Fixture.create(longTitle: true, article: true),
        ))!;
        addTearDown(() async {
          await tester.runAsync(fixture.dispose);
        });
        await fixture.pump(tester, platform: platform, rtl: rtl, scale: 2);
        final line = tester.getRect(find.byKey(_articleProgressKey));
        expect(line.left, 11);
        expect(line.right, 568 - 17);
        expect(line.top, 24 + AppSpacing.xs + AppSizes.buttonHeight);
        expect(line.height, readerChromeProgressTrackHeight);
        final pill = tester.getRect(find.byKey(_pillKey));
        expect(line.overlaps(pill), isFalse);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundaryKey),
        );
        final pixels = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            return await image.toByteData();
          } finally {
            image.dispose();
          }
        }))!;
        final indicator = tester.widget<AppLinearProgressIndicator>(
          find.byKey(_articleProgressKey),
        );
        // Bounds miss the title backdrop painting above the thin line.
        // Sample its active half as rendered in the complete chrome stack.
        final index =
            (line.center.dy.floor() * 568 + line.left.toInt() + 2) * 4;
        final expected = indicator.color!.toARGB32();
        expect(pixels.getUint8(index), (expected >> 16) & 255);
        expect(pixels.getUint8(index + 1), (expected >> 8) & 255);
        expect(pixels.getUint8(index + 2), expected & 255);

        fixture.ui.hideChrome();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.getTopLeft(find.byKey(_articleProgressKey)).dy,
          inInclusiveRange(24, line.top),
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(_articleProgressKey)).dy, 24);
        expect(tester.takeException(), isNull);
      });

      for (final insetVariant in [0, 1, 2]) {
        testWidgets(
          '$platform 568x320 200% rtl=$rtl safe=$insetVariant shares the top row',
          (tester) async {
            final semantics = tester.ensureSemantics();
            _configure(tester, const Size(568, 320));
            if (insetVariant != 0) {
              tester.view.padding = FakeViewPadding(
                top: insetVariant == 2 ? 24 : 0,
                left: insetVariant == 2 ? 11 : 44,
                right: insetVariant == 2 ? 17 : 44,
                bottom: insetVariant == 2
                    ? 34
                    : platform == TargetPlatform.iOS
                    ? 21
                    : 24,
              );
            }
            final fixture = (await tester.runAsync(
              () => _Fixture.create(
                longTitle: true,
                chapterTitle: rtl
                    ? 'فصل طويل عن الكتب والقراءة والأفكار والقصص'
                    : null,
              ),
            ))!;
            addTearDown(() async {
              await tester.runAsync(fixture.dispose);
            });
            await fixture.pump(tester, platform: platform, rtl: rtl, scale: 2);
            final pill = tester.getRect(find.byKey(_pillKey));
            final dock = tester.getRect(find.byKey(_dockKey));
            final title = tester.getRect(
              find.byKey(const ValueKey('readerTopChromeLine')),
            );
            expect(pill.size, const Size(readerBrightnessChromeLength, 48));
            expect(pill.top, tester.view.padding.top + AppSpacing.xs);
            expect(pill.bottom, lessThanOrEqualTo(dock.top - AppSpacing.sm));
            expect(title.overlaps(pill), isFalse);
            expect(title.bottom, lessThanOrEqualTo(dock.top - AppSpacing.sm));
            final chapter = tester.getRect(
              find.byKey(const ValueKey('readerProgressStartLabel')),
            );
            final pageLabel = tester.getRect(
              find.byKey(const ValueKey('readerProgressPageLabel')),
            );
            expect(chapter.overlaps(pageLabel), isFalse);
            expect(chapter.bottom, lessThanOrEqualTo(dock.bottom));
            expect(pageLabel.bottom, lessThanOrEqualTo(dock.bottom));
            _expectFullTargets(tester, dock);
            final l10n = tester.element(find.byKey(_pillKey)).l10n;
            final increase = find.byTooltip(l10n.readerIncreaseBrightness);
            final decrease = find.byTooltip(l10n.readerDecreaseBrightness);
            expect(
              find.bySemanticsLabel(l10n.readerUseSystemBrightness),
              findsOneWidget,
            );
            expect(
              tester.getCenter(increase).dx,
              rtl
                  ? lessThan(tester.getCenter(decrease).dx)
                  : greaterThan(tester.getCenter(decrease).dx),
            );
            await tester.tap(increase);
            await tester.tap(decrease);
            await tester.tap(
              find.byKey(const ValueKey('readerBrightnessChromeDragArea')),
            );
            await tester.pumpAndSettle();
            expect(fixture.brightness.adjustments, [.05, -.05]);
            expect(fixture.brightness.systemRequests, 1);
            await tester.drag(
              find.byKey(const ValueKey('readerBrightnessChromeDragArea')),
              Offset(rtl ? -36 : 36, 0),
            );
            await tester.pumpAndSettle();
            expect(fixture.brightness.previews.last, greaterThan(.5));
            expect(fixture.brightness.commits, [
              fixture.brightness.previews.last,
            ]);

            fixture.brightness.previewBrightness(
              ReaderBrightnessCubit.maxBrightness,
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<AppPlainIconButton>(
                    find.ancestor(
                      of: increase,
                      matching: find.byType(AppPlainIconButton),
                    ),
                  )
                  .onPressed,
              isNull,
            );
            fixture.brightness.previewBrightness(
              ReaderBrightnessCubit.minBrightness,
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<AppPlainIconButton>(
                    find.ancestor(
                      of: decrease,
                      matching: find.byType(AppPlainIconButton),
                    ),
                  )
                  .onPressed,
              isNull,
            );

            final pillElement = tester.element(find.byKey(_pillKey));
            final sliderElement = tester.element(find.byType(AppSlider));
            fixture.ui.hideChrome();
            await tester.pumpAndSettle();
            fixture.ui.showChrome();
            await tester.pumpAndSettle();
            expect(tester.element(find.byKey(_pillKey)), same(pillElement));
            expect(tester.element(find.byType(AppSlider)), same(sliderElement));
            // Rotation changes only the arrangement, retaining control state.
            tester.view.physicalSize = const Size(320, 568);
            tester.view.padding = FakeViewPadding.zero;
            await tester.pumpAndSettle();
            expect(tester.element(find.byKey(_pillKey)), same(pillElement));
            expect(tester.element(find.byType(AppSlider)), same(sliderElement));
            expect(
              tester.getSize(find.byKey(_pillKey)).height,
              readerBrightnessChromeLength,
            );
            expect(tester.takeException(), isNull);
            semantics.dispose();
          },
        );
      }

      testWidgets('$platform 320x568 200% rtl=$rtl clears the expanded dock', (
        tester,
      ) async {
        _configure(tester, const Size(320, 568));
        tester.view.padding = const FakeViewPadding(
          top: 24,
          bottom: 34,
          left: 11,
          right: 17,
        );
        final fixture = (await tester.runAsync(
          () => _Fixture.create(longTitle: true),
        ))!;
        addTearDown(() async {
          await tester.runAsync(fixture.dispose);
        });
        await fixture.pump(tester, platform: platform, rtl: rtl, scale: 2);
        final pill = tester.getRect(find.byKey(_pillKey));
        final dock = tester.getRect(find.byKey(_dockKey));
        expect(pill.top, greaterThanOrEqualTo(24));
        expect(pill.bottom, lessThanOrEqualTo(dock.top - AppSpacing.sm));
        expect(pill.center.dy, lessThan(568 / 2));
        _expectFullTargets(tester, dock);
        final l10n = tester.element(find.byKey(_pillKey)).l10n;
        final decrease = tester.getRect(
          find.byTooltip(l10n.readerDecreaseBrightness),
        );
        await tester.tapAt(Offset(decrease.center.dx, decrease.bottom - 1));
        await tester.pumpAndSettle();
        expect(fixture.brightness.adjustments, [-.05]);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '$platform short landscape rtl=$rtl keeps its free side rail',
        (tester) async {
          _configure(tester, const Size(844, 390));
          final fixture = (await tester.runAsync(_Fixture.create))!;
          addTearDown(() async {
            await tester.runAsync(fixture.dispose);
          });
          await fixture.pump(tester, platform: platform, rtl: rtl, scale: 2);
          final pill = tester.getRect(find.byKey(_pillKey));
          final dock = tester.getRect(find.byKey(_dockKey));
          expect(pill.center.dy, 390 / 2);
          expect(
            rtl ? dock.left - pill.right : pill.left - dock.right,
            greaterThanOrEqualTo(AppSpacing.sm),
          );
          _expectFullTargets(tester, dock);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _expectFullTargets(WidgetTester tester, Rect dock) {
  final l10n = tester.element(find.byKey(_pillKey)).l10n;
  for (final target in [
    find.byTooltip(l10n.readerIncreaseBrightness),
    find.byKey(const ValueKey('readerBrightnessChromeDragArea')),
    find.byTooltip(l10n.readerDecreaseBrightness),
  ]) {
    final bounds = tester.getRect(target);
    expect(bounds.size, const Size.square(AppSizes.buttonHeight));
    expect(bounds.overlaps(dock), isFalse);
    expect(bounds.top, greaterThanOrEqualTo(tester.view.padding.top));
    expect(
      bounds.bottom,
      lessThanOrEqualTo(
        tester.view.physicalSize.height - tester.view.padding.bottom,
      ),
    );
    expect(target.hitTestable(), findsOneWidget);
  }
}

void _configure(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Fixture {
  _Fixture(this.preferences, this.bloc)
    : appearance = ReaderAppearanceCubit(
        preferencesService: preferences,
        sourceId: 'book',
      ),
      brightness = _RecordingBrightnessCubit(preferences);

  final PreferencesService preferences;
  final ReaderBloc bloc;
  final ReaderAppearanceCubit appearance;
  final _RecordingBrightnessCubit brightness;
  final ui = ReaderUiCubit()..showChrome();
  final selection = ReaderSelectionCubit();
  final articleProgress = ReaderArticleProgressCubit()..update(.5);

  static Future<_Fixture> create({
    bool longTitle = false,
    bool article = false,
    String? chapterTitle,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'de', 'ar'],
    );
    final book = Book(
      id: 'book',
      title: 'Book',
      filePath: '/book.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
    );
    final bloc = ReaderBloc(
      bookRepository: FakeBookRepository()..seedBook(book),
      highlightRepository: FakeHighlightRepository(),
      initialSource: article ? null : book,
      articleRepository: FakeArticleRepository()
        ..seedArticle(
          Article(
            id: 'article',
            title: 'Article',
            url: 'https://example.com/article',
            contentPath: '/article.json',
            addedAt: DateTime(2026),
          ),
        ),
    );
    if (article) {
      bloc.add(const ReaderSourceLoadRequested(sourceId: 'article'));
      await bloc.stream.firstWhere(
        (state) => state.status == ReaderStatus.ready,
      );
    }
    bloc.add(
      ReaderBookPositionUpdated(
        cfi: 'epubcfi(/6/4!/4/2)',
        progress: .2,
        chapterTitle:
            chapterTitle ??
            (longTitle
                ? 'Ein besonders langer Kapitelname über Bücher und Geschichten'
                : 'Chapter 2'),
        chapterCurrentPage: 1,
        chapterTotalPages: 16,
      ),
    );
    await bloc.stream.firstWhere((state) => state.chapterTitle != null);
    final fixture = _Fixture(preferences, bloc);
    fixture.brightness.previewBrightness(.5);
    return fixture;
  }

  Future<void> pump(
    WidgetTester tester, {
    required TargetPlatform platform,
    required bool rtl,
    required double scale,
    bool sharedLayout = true,
  }) async {
    await tester.pumpWidget(
      PlatformTestApp(
        platform: platform,
        brightness: rtl ? Brightness.dark : Brightness.light,
        locale: rtl ? const Locale('ar') : const Locale('de'),
        textScale: scale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: ui),
            BlocProvider.value(value: selection),
            BlocProvider.value(value: appearance),
            BlocProvider.value(value: articleProgress),
            BlocProvider<ReaderBrightnessCubit>.value(value: brightness),
          ],
          child: _ChromeHarness(sharedLayout: sharedLayout),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    await bloc.close();
    await appearance.close();
    await brightness.close();
    await ui.close();
    await selection.close();
    await articleProgress.close();
    preferences.dispose();
  }
}

class _RecordingBrightnessCubit extends ReaderBrightnessCubit {
  _RecordingBrightnessCubit(PreferencesService preferences)
    : super(
        preferencesService: preferences,
        screenControlService: const NoopScreenControlService(),
        sourceId: 'book',
      );

  final adjustments = <double>[];
  final previews = <double>[];
  final commits = <double>[];
  var systemRequests = 0;

  @override
  Future<void> changeBrightnessBy(double delta) {
    adjustments.add(delta);
    return Future<void>.value();
  }

  @override
  void previewBrightness(double value) {
    previews.add(value);
    super.previewBrightness(value);
  }

  @override
  void commitBrightness(double value) {
    commits.add(value);
  }

  @override
  Future<void> useSystemBrightness() {
    systemRequests++;
    return Future<void>.value();
  }
}

class _ChromeHarness extends StatelessWidget {
  const _ChromeHarness({required this.sharedLayout});
  final bool sharedLayout;

  @override
  Widget build(BuildContext context) {
    final brightness = ReaderBrightnessChromeDriver(
      inChromeLayout: sharedLayout,
    );
    final dock = ReaderBottomChromeDriver(
      inChromeLayout: sharedLayout,
      readerTheme: ReaderThemePreset.paper.data,
      onTocPressed: () {},
      onFontPressed: () {},
      onPageTurnPressed: () {},
      onBookmarkPressed: () {},
      onSearchPressed: () {},
      onSeekFraction: (_) {},
    );
    final top = ReaderTopChromeDriver(
      inChromeLayout: sharedLayout,
      readerTheme: ReaderThemePreset.paper.data,
    );
    final progress = ReaderArticleProgressDriver(
      inChromeLayout: sharedLayout,
      readerTheme: ReaderThemePreset.paper.data,
    );
    return RepaintBoundary(
      key: _boundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (sharedLayout)
            ReaderFloatingChromeLayout(
              brightness: brightness,
              dock: dock,
              top: top,
              progress: progress,
            )
          else ...[
            top,
            progress,
            brightness,
            dock,
          ],
        ],
      ),
    );
  }
}
