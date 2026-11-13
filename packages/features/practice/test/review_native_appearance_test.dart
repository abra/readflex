import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoScrollbar;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:practice/practice.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/practice_harness.dart';

final _card = find.byKey(const ValueKey('reviewStudyCard'));
final _source = find.byKey(const ValueKey('reviewLocation'));
final _viewport = find.byKey(const ValueKey('reviewCardViewport'));
final _panel = find.byKey(const ValueKey('reviewControlsPanel'));
final _keep = find.byKey(const ValueKey('reviewRate-keep'));
final _showLess = find.byKey(const ValueKey('reviewRate-showLess'));

void main() {
  setUpAll(() async {
    for (final family in ['Literata', 'Geist']) {
      await (FontLoader(family)..addFont(
            rootBundle.load(
              'packages/component_library/fonts/$family-Variable.ttf',
            ),
          ))
          .load();
    }
    var root = Directory.current;
    while (!File('${root.path}/test/fonts/NotoSansArabic.ttf').existsSync()) {
      if (root.parent.path == root.path) {
        throw StateError('Arabic test font not found');
      }
      root = root.parent;
    }
    final arabic = await File(
      '${root.path}/test/fonts/NotoSansArabic.ttf',
    ).readAsBytes();
    await (FontLoader('Noto Sans Arabic')..addFont(
          Future.value(ByteData.sublistView(arabic)),
        ))
        .load();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets('$platform short Highlight retains a quiet card and native '
          'dock in $brightness', (tester) async {
        const size = Size(390, 844);
        await _openSession(
          tester,
          platform: platform,
          brightness: brightness,
          size: size,
          locale: const Locale('de'),
          quote: 'Lesen schafft Raum für neue Gedanken.',
        );
        final surface = tester.widget<AppSurface>(_card);
        final context = tester.element(_card);
        final appearance = AppSurfaceAppearance.resolve(
          context,
          AppSurfaceRole.reviewCard,
        );
        expect(surface.role, AppSurfaceRole.reviewCard);
        expect(surface.color, isNull);
        expect(surface.shape, isNull);
        expect(
          appearance.shape,
          platform == TargetPlatform.iOS
              ? isA<RoundedSuperellipseBorder>()
              : isA<RoundedRectangleBorder>(),
        );
        expect(appearance.elevation, 0);
        expect(appearance.shadows, isEmpty);
        final quote = tester.widget<Text>(
          find.byKey(const ValueKey('reviewQuote')),
        );
        expect(quote.style!.fontWeight, FontWeight.w400);
        expect(quote.style!.fontFamily, AppTypography.fontFamilySerif);
        expect(quote.style!.backgroundColor, isNull);
        expect(quote.style!.background, isNull);
        expect(_position(tester).maxScrollExtent, 0);
        expect(
          tester.getSize(find.byKey(const ValueKey('reviewSourceCover'))),
          const Size(40, 60),
        );
        expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
        expect(
          tester.getRect(_card).bottom,
          lessThan(tester.getRect(_panel).top),
        );
        _expectDockPolicy(tester, platform);
        _expectRatingTargets(tester, size);
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in [320.0, 390.0]) {
      for (final locale in [const Locale('de'), const Locale('ar')]) {
        testWidgets('$platform long Highlight keeps source and actions fixed '
            'at $width / 200% / $locale', (tester) async {
          final size = Size(width, width == 320 ? 568 : 844);
          final rtl = locale.languageCode == 'ar';
          final sentence = rtl
              ? 'القراءة تمنحنا وقتا لفهم الأفكار وربط الكلمات بتجربتنا اليومية.'
              : 'Lesen gibt uns Zeit, Gedanken zu verstehen und mit eigenen Erfahrungen zu verbinden.';
          final quote = List.filled(24, sentence).join('\n\n');
          final note = rtl ? 'ملاحظة ختامية.' : 'Eine abschließende Notiz.';
          await _openSession(
            tester,
            platform: platform,
            brightness: rtl ? Brightness.dark : Brightness.light,
            size: size,
            locale: locale,
            textScale: 2,
            quote: quote,
            note: note,
          );
          final quoteFinder = find.byKey(const ValueKey('reviewQuote'));
          final quoteText = tester.widget<Text>(quoteFinder);
          final paragraph = tester.renderObject<RenderParagraph>(quoteFinder);
          expect(quoteText.data, quote);
          expect(quoteText.maxLines, isNull);
          expect(quoteText.overflow, isNull);
          expect(
            quoteText.style!.fontSize,
            tester.element(_card).text.bodyLarge.fontSize,
          );
          expect(
            paragraph.textScaler.scale(quoteText.style!.fontSize!),
            quoteText.style!.fontSize! * 2,
          );
          expect(
            quoteText.textDirection,
            rtl ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            tester.widget<AppSurface>(_card).role,
            AppSurfaceRole.reviewCard,
          );
          final sourceBounds = tester.getRect(_source);
          final cardBounds = tester.getRect(_card);
          final panelBounds = tester.getRect(_panel);
          final keepBounds = tester.getRect(_keep);
          final lessBounds = tester.getRect(_showLess);
          final clipBounds = tester.getRect(
            find.byKey(const ValueKey('reviewCardClip')),
          );
          expect(clipBounds.top, greaterThan(sourceBounds.bottom));
          expect(clipBounds.bottom, lessThan(cardBounds.bottom));
          expect(cardBounds.bottom, lessThan(panelBounds.top));
          expect(
            find.byType(CupertinoScrollbar),
            platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(Scrollbar),
            platform == TargetPlatform.android ? findsOneWidget : findsNothing,
          );
          _expectDockPolicy(tester, platform);
          _expectRatingTargets(tester, size);
          final position = _position(tester);
          expect(position.maxScrollExtent, greaterThan(0));
          await tester.drag(_viewport, const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(0));
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.getRect(_source), sourceBounds);
          expect(tester.getRect(_card), cardBounds);
          expect(tester.getRect(_panel), panelBounds);
          expect(tester.getRect(_keep), keepBounds);
          expect(tester.getRect(_showLess), lessBounds);
          expect(
            find.byKey(const ValueKey('reviewNote')).hitTestable(),
            findsOneWidget,
          );
          _expectRatingTargets(tester, size);
          await tester.tap(_keep);
          await settle(tester);
          final done = find.byKey(const ValueKey('reviewDone'));
          final doneBounds = tester.getRect(done);
          expect(done.hitTestable(), findsOneWidget);
          expect(doneBounds.height, greaterThanOrEqualTo(48));
          expect(doneBounds.bottom, greaterThan(size.height - 80));
          expect(
            tester
                .widget<AppSurface>(
                  find.byKey(const ValueKey('reviewSummaryCard')),
                )
                .role,
            AppSurfaceRole.reviewCard,
          );
          final summary = find.byKey(const ValueKey('reviewSummaryViewport'));
          await tester.drag(summary, const Offset(0, -160));
          await tester.pumpAndSettle();
          expect(tester.getRect(done), doneBounds);
          expect(done.hitTestable(), findsOneWidget);
          _expectDockPolicy(tester, platform);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Future<void> _openSession(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Brightness brightness,
  required Size size,
  required Locale locale,
  required String quote,
  String? note,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = (await tester.runAsync(PracticeHarness.create))!;
  addTearDown(harness.dispose);
  await tester.runAsync(() async {
    await harness.addBook(
      'native-highlight',
      title: locale.languageCode == 'ar'
          ? 'كتاب القراءة'
          : 'Ein Buch zum Lesen',
    );
    await harness.addHighlight('native-highlight', quote, note: note);
  });
  await tester.pumpWidget(
    PlatformTestApp(
      platform: platform,
      brightness: brightness,
      locale: locale,
      textScale: textScale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      home: ReviewSessionScreen(
        fsrsRepository: harness.fsrs,
        dictionaryRepository: harness.dictionary,
        highlightRepository: harness.highlights,
        bookRepository: harness.books,
        preferencesService: harness.preferences,
        onOpenInSource: (_, _) async {},
      ),
    ),
  );
  await settle(tester);
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _viewport, matching: find.byType(Scrollable)).first,
    )
    .position;

void _expectRatingTargets(WidgetTester tester, Size size) {
  for (final action in [_keep, _showLess]) {
    final rect = tester.getRect(action);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(size.width));
    expect(rect.bottom, lessThanOrEqualTo(size.height));
    expect(action.hitTestable(), findsOneWidget);
  }
}

void _expectDockPolicy(WidgetTester tester, TargetPlatform platform) {
  final surface = tester.widget<AppSurface>(_panel);
  expect(surface.color, tester.element(_panel).colors.surface);
  expect(
    surface.elevation,
    platform == TargetPlatform.iOS ? 0 : AppElevation.level1,
  );
  expect(
    find.descendant(of: _panel, matching: find.byType(AppDivider)),
    platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
  );
  final materials = find.descendant(
    of: _panel,
    matching: find.byType(Material),
  );
  if (platform == TargetPlatform.iOS) {
    expect(materials, findsNothing);
  } else {
    expect(
      tester.widget<Material>(materials.first).elevation,
      AppElevation.level1,
    );
  }
  final clip = tester.widget<ClipRect>(
    find.byKey(const ValueKey('reviewControlsShadowClip')),
  );
  final size = tester.getSize(_panel);
  final bounds = clip.clipper!.getClip(size);
  expect(bounds.top, lessThan(0));
  expect(bounds.bottom, size.height);
}
