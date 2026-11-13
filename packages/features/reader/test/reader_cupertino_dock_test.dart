import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

const _portrait = Size(1032, 1376);
const _landscape = Size(1376, 1032);
const _dockKey = ValueKey('readerChromeDock');
const _stripKey = ValueKey('readerChromeCapsule');
const _startKey = ValueKey('readerProgressStartLabel');
const _pageKey = ValueKey('readerProgressPageLabel');

void main() {
  setUpAll(_loadFonts);

  for (final brightness in Brightness.values) {
    for (final language in ['en', 'ru', 'de', 'ar']) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'native iPad dock keeps complete actions across rotation '
          '${brightness.name} $language x$scale',
          (tester) async {
            final fixture = (await tester.runAsync(
              () => _DockFixture.create(rtl: language == 'ar'),
            ))!;
            addTearDown(fixture.dispose);
            _configureView(tester, _portrait);
            await fixture.pump(
              tester,
              brightness: brightness,
              locale: Locale(language),
              scale: scale,
            );
            final sliderElement = tester.element(
              find.byType(cupertino.CupertinoSlider),
            );
            for (final size in [_portrait, _landscape]) {
              tester.view.physicalSize = size;
              await tester.pumpAndSettle();
              expect(find.byType(cupertino.CupertinoApp), findsOneWidget);
              final context = tester.element(find.byKey(_dockKey));
              expect(MediaQuery.sizeOf(context), size);
              expect(context.text.labelLarge.fontSize, 17);
              expect(
                Directionality.of(context),
                language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              );
              final captions = find.descendant(
                of: find.byKey(_stripKey),
                matching: find.byType(Text),
              );
              if (scale == 1) expect(captions, findsNWidgets(5));
              if (scale == 2) expect(captions, findsNothing);
              if (captions.evaluate().isEmpty) {
                _expectIconActions(tester, count: 5);
              } else {
                _expectCompleteCaptions(tester);
              }
              _expectProgressAlignment(tester, rtl: language == 'ar');
              _expectAppPalette(tester);
              expect(
                tester.element(find.byType(cupertino.CupertinoSlider)),
                same(sliderElement),
              );
              expect(fixture.bloc.state.document!.readingProgress, .2);
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  for (final size in [const Size(800, 1280), const Size(320, 568)]) {
    testWidgets('native dock keeps icon actions in a $size window', (
      tester,
    ) async {
      final fixture = (await tester.runAsync(
        () => _DockFixture.create(rtl: true),
      ))!;
      addTearDown(fixture.dispose);
      _configureView(tester, size);
      await fixture.pump(tester, locale: const Locale('ar'), scale: 2);
      _expectIconActions(tester, count: 5);
      _expectProgressAlignment(tester, rtl: true);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('native dock actions keep callbacks and semantics x$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = (await tester.runAsync(_DockFixture.create))!;
        addTearDown(fixture.dispose);
        _configureView(tester, _portrait);
        await fixture.pump(tester, scale: scale);
        final context = tester.element(find.byKey(_dockKey));
        final l10n = context.l10n;
        for (final (tooltip, caption) in [
          (l10n.readerBack, l10n.readerBack),
          (l10n.readerContents, l10n.readerContents),
          (l10n.readerFontAction, l10n.readerAppearanceTitle),
          (l10n.readerRemoveBookmark, l10n.readerBookmark),
          (l10n.readerSearchAction, l10n.readerSearchAction),
        ]) {
          final target = find.byTooltip(tooltip);
          expect(target.hitTestable(), findsOneWidget);
          final nativeButton = find.descendant(
            of: target,
            matching: find.byType(cupertino.CupertinoButton),
          );
          expect(nativeButton, findsOneWidget);
          final node = tester.getSemantics(nativeButton);
          expect(node.flagsCollection.isButton, isTrue, reason: tooltip);
          expect(
            node.flagsCollection.isEnabled,
            Tristate.isTrue,
            reason: tooltip,
          );
          expect(
            '${node.label} ${node.tooltip}',
            contains(scale == 1 ? caption : tooltip),
          );
        }
        for (final label in [
          l10n.readerContents,
          l10n.readerFontAction,
          l10n.readerRemoveBookmark,
          l10n.readerSearchAction,
        ]) {
          await tester.tap(find.byTooltip(label));
          await tester.pumpAndSettle();
        }
        expect(fixture.pressed, [
          'contents',
          'appearance',
          'bookmark',
          'search',
        ]);
        final slider = tester.getRect(find.byType(cupertino.CupertinoSlider));
        await tester.tapAt(
          Offset(slider.left + slider.width * .75, slider.center.dy),
        );
        await tester.pumpAndSettle();
        expect(fixture.seeks, hasLength(1));
        expect(fixture.seeks.single, greaterThan(.7));
        expect(fixture.ui.state.chromeVisible, isTrue);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final active in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'native bookmark retains its action color active=$active '
        '${brightness.name}',
        (tester) async {
          final fixture = (await tester.runAsync(
            () => _DockFixture.create(bookmarked: active),
          ))!;
          addTearDown(fixture.dispose);
          _configureView(tester, _portrait);
          await fixture.pump(tester, brightness: brightness);
          final context = tester.element(find.byKey(_dockKey));
          final tooltip = active
              ? context.l10n.readerRemoveBookmark
              : context.l10n.readerBookmark;
          final button = tester.widget<AppButton>(
            find.descendant(
              of: find.byTooltip(tooltip),
              matching: find.byType(AppButton),
            ),
          );
          expect(
            button.foregroundColor,
            active ? context.actionForeground : context.colors.onSurface,
          );
          _expectCompleteCaptions(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _configureView(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 24, bottom: 20)
    ..viewPadding = const FakeViewPadding(top: 24, bottom: 20);
  addTearDown(tester.view.reset);
}

void _expectIconActions(WidgetTester tester, {required int count}) {
  final strip = find.byKey(_stripKey);
  expect(tester.getSize(strip).height, 60);
  expect(
    find.descendant(of: strip, matching: find.byType(AppButton)),
    findsNothing,
  );
  final actions = find.descendant(
    of: strip,
    matching: find.byType(AppPlainIconButton),
  );
  expect(actions, findsNWidgets(count));
  final centers = <double>[];
  for (final action in actions.evaluate()) {
    final finder = find.byWidget(action.widget);
    final bounds = tester.getRect(finder);
    expect(bounds.width, closeTo(48, .01));
    expect(bounds.height, closeTo(48, .01));
    expect(bounds.center.dy, closeTo(tester.getRect(strip).center.dy, .01));
    expect((action.widget as AppPlainIconButton).tooltip, isNotEmpty);
    centers.add(bounds.center.dx);
  }
  for (var i = 1; i < centers.length; i++) {
    expect(
      (centers[i] - centers[i - 1]).abs(),
      closeTo(tester.getSize(strip).width / count, .01),
    );
  }
}

void _expectCompleteCaptions(WidgetTester tester) {
  final buttons = find.descendant(
    of: find.byKey(_stripKey),
    matching: find.byType(AppButton),
  );
  expect(buttons, findsNWidgets(5));
  final iconCenters = <double>[];
  final baselines = <double>[];
  for (final element in buttons.evaluate()) {
    final button = find.byWidget(element.widget);
    final bounds = tester.getRect(button);
    expect(bounds.width, greaterThanOrEqualTo(48));
    expect(bounds.height, greaterThanOrEqualTo(48));
    final text = find.descendant(of: button, matching: find.byType(Text));
    final caption = tester.widget<Text>(text);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(caption.maxLines, 1, reason: caption.data);
    expect(caption.style!.fontSize, 17, reason: caption.data);
    expect(paragraph.didExceedMaxLines, isFalse, reason: caption.data);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: caption.data!.length),
    );
    expect(boxes, isNotEmpty, reason: caption.data);
    // Arabic fallback runs can have different vertical metrics on one line.
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(-.01), reason: caption.data);
      expect(
        box.right,
        lessThanOrEqualTo(paragraph.size.width + .01),
        reason: caption.data,
      );
    }
    final textBounds = tester.getRect(text);
    expect(textBounds.left, greaterThanOrEqualTo(bounds.left - .01));
    expect(textBounds.right, lessThanOrEqualTo(bounds.right + .01));
    expect(textBounds.top, greaterThanOrEqualTo(bounds.top - .01));
    expect(textBounds.bottom, lessThanOrEqualTo(bounds.bottom + .01));
    baselines.add(
      paragraph.localToGlobal(Offset.zero).dy +
          paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!,
    );
    final glyph = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (widget) => widget is Icon || widget is CustomPaint,
      ),
    );
    expect(glyph, findsOneWidget);
    iconCenters.add(tester.getRect(glyph).center.dy);
  }
  for (final center in iconCenters.skip(1)) {
    expect(center, closeTo(iconCenters.first, .01));
  }
  for (final baseline in baselines.skip(1)) {
    expect(baseline, closeTo(baselines.first, .01));
  }
}

void _expectProgressAlignment(WidgetTester tester, {required bool rtl}) {
  final slider = tester.getRect(find.byType(cupertino.CupertinoSlider));
  final start = tester.getRect(find.byKey(_startKey));
  final page = tester.getRect(find.byKey(_pageKey));
  // Cupertino paints the track 8dp from its box; its thumb center travels 22dp in.
  expect(slider.height, 48);
  expect(
    rtl ? start.right : start.left,
    closeTo(rtl ? slider.right - 8 : slider.left + 8, .01),
  );
  expect(
    rtl ? page.left : page.right,
    closeTo(rtl ? slider.left + 8 : slider.right - 8, .01),
  );
  expect(
    tester
        .renderObject<RenderParagraph>(find.byKey(_pageKey))
        .didExceedMaxLines,
    isFalse,
  );
  expect(page.bottom, lessThanOrEqualTo(slider.top + .01));
}

void _expectAppPalette(WidgetTester tester) {
  final context = tester.element(find.byKey(_dockKey));
  final surface = tester.widget<AppSurface>(find.byKey(_dockKey));
  expect(surface.role, AppSurfaceRole.floatingToolbar);
  expect(surface.borderRadius, BorderRadius.circular(AppRadius.xl));
  final appearance = AppSurfaceAppearance.resolve(context, surface.role!);
  for (final key in [_startKey, _pageKey]) {
    final color = tester.widget<Text>(find.byKey(key)).style!.color!;
    expect(color, context.colors.onSurfaceVariant);
    for (final page in [const Color(0xFF000000), const Color(0xFFFFFFFF)]) {
      final fill = Color.alphaBlend(appearance.color, page);
      final ink = Color.alphaBlend(color, fill).computeLuminance();
      final background = fill.computeLuminance();
      expect(
        (math.max(ink, background) + .05) / (math.min(ink, background) + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  }
}

Future<void> _loadFonts() async {
  final font = await rootBundle.load(
    'packages/component_library/fonts/Geist-Variable.ttf',
  );
  for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
    await (FontLoader(family)..addFont(Future.value(font))).load();
  }
  var directory = Directory.current;
  var arabic = File('${directory.path}/test/fonts/NotoSansArabic.ttf');
  while (!arabic.existsSync() && directory.parent.path != directory.path) {
    directory = directory.parent;
    arabic = File('${directory.path}/test/fonts/NotoSansArabic.ttf');
  }
  await (FontLoader('Noto Sans Arabic')..addFont(
        Future.value(ByteData.sublistView(await arabic.readAsBytes())),
      ))
      .load();
}

class _DockFixture {
  _DockFixture({
    required this.preferences,
    required this.bloc,
    required this.appearance,
  });

  final PreferencesService preferences;
  final ReaderBloc bloc;
  final ReaderAppearanceCubit appearance;
  final ui = ReaderUiCubit()..showChrome();
  final selection = ReaderSelectionCubit();
  final pressed = <String>[];
  final seeks = <double>[];

  static Future<_DockFixture> create({
    bool rtl = false,
    bool bookmarked = true,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en', 'ru', 'de', 'ar'],
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
      initialSource: book,
    );
    bloc.add(
      ReaderBookPositionUpdated(
        cfi: 'epubcfi(/6/4!/4/2)',
        progress: .2,
        chapterTitle: rtl ? 'الفصل الثاني' : 'Chapter 2',
        chapterCurrentPage: 1,
        chapterTotalPages: 16,
        currentPageBookmarked: bookmarked,
        pageProgressionRtl: rtl,
      ),
    );
    await bloc.stream.firstWhere((state) => state.chapterTitle != null);
    return _DockFixture(
      preferences: preferences,
      bloc: bloc,
      appearance: ReaderAppearanceCubit(
        preferencesService: preferences,
        sourceId: book.id,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      PlatformTestApp(
        platform: TargetPlatform.iOS,
        brightness: brightness,
        locale: locale,
        textScale: scale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: ui),
            BlocProvider.value(value: selection),
            BlocProvider.value(value: appearance),
          ],
          child: Stack(
            fit: StackFit.expand,
            children: [
              ReaderBottomChromeDriver(
                readerTheme: brightness == Brightness.light
                    ? ReaderThemePreset.night.data
                    : ReaderThemePreset.paper.data,
                onTocPressed: () => pressed.add('contents'),
                onFontPressed: () => pressed.add('appearance'),
                onPageTurnPressed: () => pressed.add('pageTurn'),
                onBookmarkPressed: () => pressed.add('bookmark'),
                onSearchPressed: () => pressed.add('search'),
                onSeekFraction: seeks.add,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    await bloc.close();
    await ui.close();
    await selection.close();
    await appearance.close();
    preferences.dispose();
  }
}
