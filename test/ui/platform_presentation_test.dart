import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:domain_models/domain_models.dart' show SourceType;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:onboarding/onboarding.dart';
import 'package:pagecraft/all_formats.dart' show TextPagesView;
import 'package:readflex/app/readflex_platform_app.dart';
import 'package:readflex/app/routing.dart';
import 'package:reader/src/reader_contents_tab_bar.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart' show loadUiFonts;

void main() {
  setUpAll(() async {
    await loadUiFonts();
    // Portable glyph metrics for layout contracts, not native SF rasterization.
    // Real platform typography is inspected separately in device/review captures.
    final font = await rootBundle.load(
      'packages/component_library/fonts/Geist-Variable.ttf',
    );
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(Future.value(font))).load();
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final (locale, size) in [
      (const Locale('de'), const Size(320, 568)),
      (const Locale('ar'), const Size(390, 844)),
    ]) {
      testWidgets('production ${platform.name} onboarding stays usable at '
          '200% in $locale', (tester) async {
        _configureView(tester, platform: platform, size: size, scale: 2);
        final app = (await tester.runAsync(
          () => UiTestApp.create(withBook: false, onboardingCompleted: false),
        ))!;
        addTearDown(app.dispose);
        await tester.runAsync(
          () =>
              app.preferencesService.update((p) => p.copyWith(locale: locale)),
        );
        await tester.pumpWidget(app.widgetAt(AppRoutes.root));
        await waitForUi(
          tester,
          () => find.byType(OnboardingScreen).evaluate().isNotEmpty,
          description: 'localized onboarding',
        );
        await tester.pumpAndSettle();
        _expectPlatformRoot(platform);
        final context = tester.element(find.byType(OnboardingScreen));
        final l10n = context.l10n;
        expect(
          Directionality.of(context),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        final add = find.widgetWithText(AppButton, l10n.onboardingAddBook);
        final later = find.widgetWithText(AppButton, l10n.onboardingNotNow);
        final addBefore = tester.getRect(add);
        final laterBefore = tester.getRect(later);
        for (final action in [add, later]) {
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(action).left, greaterThanOrEqualTo(16));
          expect(
            tester.getRect(action).right,
            lessThanOrEqualTo(size.width - 16),
          );
        }
        for (final element
            in find
                .descendant(
                  of: find.byType(OnboardingScreen),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason:
                'Truncated onboarding label: ${paragraph.text.toPlainText()}',
          );
        }
        final scroll = find.descendant(
          of: find.byType(OnboardingScreen),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.scrollUntilVisible(
          find.text(l10n.onboardingFeatureHighlightsDescription),
          180,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.onboardingFeatureHighlightsDescription).hitTestable(),
          findsOneWidget,
        );
        expect(tester.getRect(add), addBefore);
        expect(tester.getRect(later), laterBefore);
        expect(tester.takeException(), isNull);

        await tapUi(tester, later);
        await waitForUi(
          tester,
          () => find
              .byKey(const ValueKey('libraryHeaderDisplayButton'))
              .evaluate()
              .isNotEmpty,
          description: 'Library after onboarding completion',
        );
        expect(app.preferencesService.current.onboardingCompleted, isTrue);
        _expectPlatformRoot(platform);
        await unmountUi(tester);
      });
    }

    testWidgets('production ${platform.name} Library opens its platform modal '
        'and Practice chrome', (tester) async {
      _configureView(tester, platform: platform);
      final app = (await tester.runAsync(UiTestApp.create))!;
      addTearDown(app.dispose);
      await tester.runAsync(
        () => app.highlightRepository.addHighlight(
          sourceId: app.book!.id,
          sourceType: SourceType.book,
          text: 'A saved passage for the platform navigation contract.',
        ),
      );
      await tester.pumpWidget(app.widget);
      final display = find.byKey(const ValueKey('libraryHeaderDisplayButton'));
      await tapUi(tester, display);
      await tester.pumpAndSettle();
      _expectPlatformRoot(platform);
      final native = platform == TargetPlatform.iOS;
      final surface = native
          ? find.byType(cupertino.CupertinoPopupSurface)
          : find.byType(material.BottomSheet);
      expect(surface, findsOneWidget);
      final modalContext = tester.element(surface);
      final route = ModalRoute.of(modalContext)!;
      final l10n = modalContext.l10n;
      if (native) {
        expect(route, isA<cupertino.CupertinoModalPopupRoute<void>>());
        expect(
          tester.widget<cupertino.CupertinoPopupSurface>(surface).blurSigma,
          0,
        );
        expect(modalContext.appTheme.sheetColor.a, 1);
        expect(tester.getSize(surface).width, 390 - 16);
        expect(tester.getRect(surface).bottom, 844 - 34);
        expect(
          tester.getCenter(find.text(l10n.libraryDisplayTitle)).dx,
          tester.getCenter(surface).dx,
        );
      } else {
        expect(route, isA<material.ModalBottomSheetRoute<void>>());
      }
      final close = find.byTooltip(l10n.commonClose);
      expect(tester.getSize(close), const Size(48, 48));
      await tapUi(tester, find.text(l10n.libraryDisplayList));
      expect(app.preferencesService.current.libraryLayoutMode, 'list');
      await tapUi(tester, close);
      await tester.pumpAndSettle();
      expect(surface, findsNothing);

      final libraryContext = tester.element(display);
      GoRouter.of(libraryContext).push<void>(AppRoutes.practice);
      final today = find.byKey(const ValueKey('practiceTodayCard'));
      await waitForUi(
        tester,
        () => today.evaluate().isNotEmpty,
        description: 'Practice ready',
      );
      await tester.pumpAndSettle();
      final settings = find.byKey(const ValueKey('practiceSettingsButton'));
      expect(settings.hitTestable(), findsOneWidget);
      final bar = native
          ? find.byType(cupertino.CupertinoNavigationBar)
          : find.byType(material.AppBar);
      expect(bar, findsOneWidget);
      expect(tester.getSize(bar).height, (native ? 44 : 52) + 47);
      expect(tester.getSize(settings).height, native ? 44 : 48);
      expect(
        tester.getSize(find.byType(AppBackButton)).height,
        native ? 44 : 48,
      );
      expect(
        tester.getRect(today).top,
        greaterThanOrEqualTo(tester.getRect(bar).bottom),
      );
      await tapUi(tester, find.byType(AppBackButton));
      expect(display.hitTestable(), findsOneWidget);
      expect(app.preferencesService.current.libraryLayoutMode, 'list');
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    });

    testWidgets(
      'production ${platform.name} Reader Contents uses platform tabs '
      'without replacing the reader',
      (tester) async {
        _configureView(tester, platform: platform);
        final app = (await tester.runAsync(UiTestApp.create))!;
        addTearDown(app.dispose);
        await tester.pumpWidget(app.widgetAt(AppRoutes.reader(app.book!.id)));
        final pages = find.byType(TextPagesView);
        await waitForUi(
          tester,
          () =>
              pages.evaluate().isNotEmpty &&
              tester.widget<TextPagesView>(pages).controller.isReady,
          description: 'parsed book pages',
        );
        final readerState = tester.state(pages);
        final l10n = tester.element(pages).l10n;
        final contents = find.byTooltip(l10n.readerContents);
        if (contents.hitTestable().evaluate().isEmpty) {
          await tester.tap(pages);
          await tester.pumpAndSettle();
        }
        await tapUi(tester, contents);
        final tabs = find.byType(ReaderContentsTabBar);
        await waitForUi(
          tester,
          () => tabs.hitTestable().evaluate().isNotEmpty,
          description: 'Contents tabs',
        );
        await tester.pumpAndSettle();
        _expectPlatformRoot(platform);
        final tabContext = tester.element(tabs);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(material.TabBar), findsNothing);
          expect(find.byType(AppChoiceControl<int>), findsOneWidget);
          if (find
              .byType(cupertino.CupertinoSlidingSegmentedControl<int>)
              .evaluate()
              .isEmpty) {
            // A phone may need wrapped native choices instead of segments.
            expect(
              find.descendant(
                of: tabs,
                matching: find.byType(cupertino.CupertinoButton),
              ),
              findsNWidgets(3),
            );
          }
        } else {
          expect(find.byType(material.TabBar), findsOneWidget);
        }
        await tapUi(
          tester,
          find.descendant(of: tabs, matching: find.text(l10n.readerHighlights)),
        );
        expect(material.DefaultTabController.of(tabContext).index, 2);
        await tapUi(tester, find.byTooltip(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(tabs, findsNothing);
        expect(tester.state(pages), same(readerState));
        expect(tester.takeException(), isNull);
        await unmountUi(tester);
      },
    );
  }
}

void _configureView(
  WidgetTester tester, {
  required TargetPlatform platform,
  Size size = const Size(390, 844),
  double scale = 1,
}) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 47, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _expectPlatformRoot(TargetPlatform platform) {
  expect(find.byType(ReadflexPlatformApp), findsOneWidget);
  expect(
    find.byType(cupertino.CupertinoApp),
    platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(material.MaterialApp),
    platform == TargetPlatform.android ? findsOneWidget : findsNothing,
  );
}
