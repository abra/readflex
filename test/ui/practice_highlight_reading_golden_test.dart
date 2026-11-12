import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/routing.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

import 'package:preferences_service/preferences_service.dart';

/// The complete reading card stays visible while its passage and note scroll.
/// Real app routes and repositories keep the source, frame and actions covered.
void main() {
  setUpAll(loadUiFonts);

  for (final (name, profile, size, scale) in const [
    ('phone', VisualProfile.phone, Size(390, 844), 1.0),
    ('phone', VisualProfile.dark, Size(390, 844), 1.0),
    ('phone-rtl-large', VisualProfile.tabletRtl, Size(320, 568), 2.0),
    ('tablet', VisualProfile.phone, Size(800, 1280), 1.0),
  ]) {
    testWidgets('highlight reading ${profile.name} $name', (tester) async {
      final shadowsDisabled = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = shadowsDisabled);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      final rtl = profile.locale.languageCode == 'ar';
      final paragraph = rtl
          ? 'القراءة تتيح لنا فهم الفكرة وربطها بتجاربنا. '
                'تساعدنا العودة إلى النص على التأمل في معناه.'
          : 'Returning to a passage should leave room to read the whole '
                'thought. The surrounding sentences help us connect a new '
                'idea with something we already understand. A calm page '
                'keeps attention on the text and makes it easy to return '
                'to the source.';
      final ending = rtl ? 'نهاية المقتطف.' : 'The end of the passage.';
      final note = rtl ? 'فكرة تستحق التأمل.' : 'An idea worth reflecting on.';
      final quote = [
        for (var index = 0; index < (rtl ? 2 : 4); index++)
          size.width >= 800 ? List.filled(5, paragraph).join(' ') : paragraph,
        ending,
      ].join('\n\n');
      await tester.runAsync(() async {
        await app.preferencesService.update(
          (preferences) => preferences.copyWith(
            locale: profile.locale,
            themeMode: profile.brightness == Brightness.dark
                ? AppThemeMode.dark
                : AppThemeMode.light,
          ),
        );
        await app.highlightRepository.addHighlight(
          sourceId: app.book!.id,
          sourceType: SourceType.book,
          text: quote,
          note: note,
          chapterTitle: rtl ? 'الفصل الأول' : 'Chapter One',
          cfiRange: 'epubcfi(/6/2!/4/4,/1:0,/1:${quote.length})',
        );
      });

      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: goldenBoundary,
            child: app.widgetAt(AppRoutes.practiceReview),
          ),
        );
        final quoteFinder = find.byKey(const ValueKey('reviewQuote'));
        await waitForUi(
          tester,
          () => quoteFinder.evaluate().isNotEmpty,
          description: 'long highlight review',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('reviewShowAnswer')), findsNothing);
        final quoteText = tester.widget<Text>(quoteFinder);
        final quoteParagraph = tester.renderObject<RenderParagraph>(
          quoteFinder,
        );
        expect(quoteParagraph.text.toPlainText(), quote);
        expect(quoteText.maxLines, isNull);
        expect(quoteParagraph.didExceedMaxLines, isFalse);
        expect(
          quoteText.textDirection,
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        final location = find.byKey(const ValueKey('reviewLocation'));
        final locationBounds = tester.getRect(location);
        expect(
          locationBounds.bottom,
          lessThan(tester.getRect(quoteFinder).top),
        );
        final sourceAction = find.byKey(const ValueKey('reviewOpenInBook'));
        final sourceActionBounds = tester.getRect(sourceAction);
        expect(sourceAction.hitTestable(), findsOneWidget);

        final frame = find.byKey(const ValueKey('reviewStudyCard'));
        final frameBounds = tester.getRect(frame);
        final outerViewport = tester.getRect(
          find.byKey(const ValueKey('reviewHighlightViewport')),
        );
        expect(frameBounds.top, greaterThan(outerViewport.top));
        expect(frameBounds.left, greaterThanOrEqualTo(outerViewport.left));
        expect(frameBounds.right, lessThanOrEqualTo(outerViewport.right));
        expect(frameBounds.bottom, lessThan(outerViewport.bottom));
        expect(frameBounds.width, lessThanOrEqualTo(640));
        final frameClip = tester.widget<ClipRRect>(
          find.descendant(of: frame, matching: find.byType(ClipRRect)).first,
        );
        expect(frameClip.borderRadius, BorderRadius.circular(AppRadius.lg));

        final clip = find.byKey(const ValueKey('reviewCardClip'));
        final panel = find.byKey(const ValueKey('reviewControlsPanel'));
        final clipBounds = tester.getRect(clip);
        final panelBounds = tester.getRect(panel);
        expect(clipBounds.top, greaterThan(locationBounds.bottom));
        expect(clipBounds.left, greaterThan(frameBounds.left));
        expect(clipBounds.right, lessThan(frameBounds.right));
        expect(clipBounds.bottom, lessThan(frameBounds.bottom));
        expect(frameBounds.bottom, lessThan(panelBounds.top));
        expect(clipBounds.bottom, lessThan(panelBounds.top));
        final keep = find.byKey(const ValueKey('reviewRate-keep'));
        final showLess = find.byKey(const ValueKey('reviewRate-showLess'));
        final controls = [tester.getRect(keep), tester.getRect(showLess)];
        for (final rating in [keep, showLess]) {
          expect(rating.hitTestable(), findsOneWidget);
          expect(tester.getSize(rating).height, greaterThanOrEqualTo(48));
        }

        final viewport = find.byKey(const ValueKey('reviewCardViewport'));
        final scrollable = find
            .descendant(
              of: viewport,
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        final scrollbar = tester.widget<Scrollbar>(
          find.byKey(const ValueKey('reviewHighlightScrollbar')),
        );
        expect(scrollbar.thumbVisibility, isTrue);
        expect(scrollbar.controller!.position, same(position));
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        expect(tester.getRect(frame), frameBounds);
        expect(tester.getRect(location), locationBounds);
        expect(tester.getRect(sourceAction), sourceActionBounds);
        expect(sourceAction.hitTestable(), findsOneWidget);
        expect(tester.getRect(clip), clipBounds);
        expect(tester.getRect(panel), panelBounds);
        expect(tester.getRect(keep), controls[0]);
        expect(tester.getRect(showLess), controls[1]);
        await expectUiGolden(tester, profile, 'highlight-reading-$name-mid');

        final lastLine = quoteParagraph.getBoxesForSelection(
          TextSelection(
            baseOffset: quote.length - ending.length,
            extentOffset: quote.length,
          ),
        );
        expect(lastLine, isNotEmpty);
        final lastQuoteBounds = MatrixUtils.transformRect(
          quoteParagraph.getTransformTo(null),
          lastLine.last.toRect(),
        );
        position.jumpTo(
          (position.pixels +
                  lastQuoteBounds.bottom -
                  clipBounds.bottom +
                  AppSpacing.xs)
              .clamp(0.0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        for (final box in lastLine) {
          final bounds = MatrixUtils.transformRect(
            quoteParagraph.getTransformTo(null),
            box.toRect(),
          );
          expect(bounds.top, greaterThanOrEqualTo(clipBounds.top));
          expect(bounds.bottom, lessThanOrEqualTo(clipBounds.bottom));
        }

        // The complete quote and note remain reachable independently, including
        // compact windows that cannot show both endings at the same time.
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        final noteFinder = find.byKey(const ValueKey('reviewNote'));
        expect(tester.widget<Text>(noteFinder).data, note);
        final noteParagraph = tester.renderObject<RenderParagraph>(noteFinder);
        final lastNoteLine = noteParagraph.getBoxesForSelection(
          TextSelection(baseOffset: note.length - 1, extentOffset: note.length),
        );
        expect(lastNoteLine, isNotEmpty);
        for (final box in lastNoteLine) {
          final bounds = MatrixUtils.transformRect(
            noteParagraph.getTransformTo(null),
            box.toRect(),
          );
          expect(bounds.top, greaterThanOrEqualTo(clipBounds.top));
          expect(bounds.bottom, lessThanOrEqualTo(clipBounds.bottom));
        }
        expect(tester.getRect(frame), frameBounds);
        expect(tester.getRect(location), locationBounds);
        expect(tester.getRect(sourceAction), sourceActionBounds);
        expect(sourceAction.hitTestable(), findsOneWidget);
        expect(tester.getRect(clip), clipBounds);
        expect(tester.getRect(panel), panelBounds);
        expect(keep.hitTestable(), findsOneWidget);
        expect(showLess.hitTestable(), findsOneWidget);
        await expectUiGolden(tester, profile, 'highlight-reading-$name-end');
        expect(tester.takeException(), isNull);
      } finally {
        debugDisableShadows = shadowsDisabled;
        await unmountUi(tester);
      }
    }, tags: ['golden']);
  }
}
