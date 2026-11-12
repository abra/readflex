import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:practice/practice.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

void main() {
  testWidgets('completing an iOS review fades out without a moving page edge', (
    tester,
  ) async {
    final app = await _pumpPractice(tester, TargetPlatform.iOS);
    await tapUi(tester, find.byKey(const ValueKey('practiceStartReview')));
    await waitForUi(
      tester,
      () => find.byKey(const ValueKey('reviewWord')).evaluate().isNotEmpty,
      description: 'review word',
    );
    final review = find.byType(ReviewSessionScreen);
    final route = ModalRoute.of(tester.element(review))! as PageRoute<void>;
    expect(route.settings, isA<CustomTransitionPage<void>>());
    expect(route.fullscreenDialog, isTrue);
    expect(route.transitionDuration, AppMotion.short);
    expect(route.reverseTransitionDuration, AppMotion.short);
    await tapUi(tester, find.byKey(const ValueKey('reviewShowAnswer')));
    await tapUi(tester, find.byKey(const ValueKey('reviewRate-good')));
    await waitForUi(
      tester,
      () => find
          .byKey(const ValueKey('reviewSummaryTitle'))
          .evaluate()
          .isNotEmpty,
      description: 'completed session',
    );
    await tester.pumpAndSettle();

    final done = find.byKey(const ValueKey('reviewDone'));
    final restingRect = tester.getRect(done);
    final fade = find.ancestor(
      of: review,
      matching: find.byType(FadeTransition),
    );
    await tester.tap(done);
    var previousFrame = 0;
    var previousOpacity = 1.0;
    for (final elapsed in [0, 16, 64, 112]) {
      await tester.pump(Duration(milliseconds: elapsed - previousFrame));
      previousFrame = elapsed;
      expect(done, findsOneWidget);
      expect(
        tester.getRect(done),
        restingRect,
        reason: 'The outgoing review must stay in place at ${elapsed}ms',
      );
      final opacity = tester.widget<FadeTransition>(fade).opacity.value;
      if (elapsed > 0) expect(opacity, lessThan(previousOpacity));
      previousOpacity = opacity;
      expect(tester.takeException(), isNull);
    }

    await tester.pumpAndSettle();
    await waitForUi(
      tester,
      () => find.text('Review ahead').evaluate().isNotEmpty,
      description: 'updated Practice hub',
    );
    expect(done, findsNothing);
    expect(find.byKey(const ValueKey('reviewSummaryTitle')), findsNothing);
    expect(find.text('Review ahead'), findsOneWidget);
    expect(find.text('All caught up'), findsWidgets);
    final stats = await tester.runAsync(app.fsrsRepository.getStats);
    expect(stats!.due, 0);
    expect(tester.takeException(), isNull);
    await unmountUi(tester);
  });

  for (final (platform, reduceMotion) in [
    (TargetPlatform.macOS, false),
    (TargetPlatform.iOS, true),
    (TargetPlatform.android, false),
  ]) {
    testWidgets(
      'review route and Close: $platform, reduced motion $reduceMotion',
      (
        tester,
      ) async {
        await _pumpPractice(tester, platform, reduceMotion: reduceMotion);
        await tapUi(tester, find.byKey(const ValueKey('practiceStartReview')));
        await waitForUi(
          tester,
          () => find.byKey(const ValueKey('reviewWord')).evaluate().isNotEmpty,
          description: 'review word',
        );
        final review = find.byType(ReviewSessionScreen);
        final route = ModalRoute.of(tester.element(review))! as PageRoute<void>;
        expect(route.fullscreenDialog, isTrue);
        if (platform == TargetPlatform.android) {
          expect(route.settings, isA<MaterialPage<void>>());
        } else {
          expect(route.settings, isA<CustomTransitionPage<void>>());
          final duration = reduceMotion ? Duration.zero : AppMotion.short;
          expect(route.transitionDuration, duration);
          expect(route.reverseTransitionDuration, duration);
        }
        await tapUi(tester, find.byKey(const ValueKey('reviewClose')));
        await tester.pumpAndSettle();
        expect(review, findsNothing);
        expect(find.text('Start review'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmountUi(tester);
      },
    );
  }
}

Future<UiTestApp> _pumpPractice(
  WidgetTester tester,
  TargetPlatform platform, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final app = (await tester.runAsync(UiTestApp.create))!;
  addTearDown(app.dispose);
  await tester.runAsync(
    () => app.dictionaryRepository.addEntry(
      word: 'reading',
      translation: 'Lesen',
      sourceId: app.book!.id,
      sourceType: SourceType.book,
      anchorText: 'reading',
    ),
  );
  final router = buildRouter(
    deps: app.dependencies,
    initialLocation: AppRoutes.practice,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light().copyWith(platform: platform),
      locale: const Locale('en'),
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      routerConfig: router,
    ),
  );
  await waitForUi(
    tester,
    () => find.byKey(const ValueKey('practiceTodayCard')).evaluate().isNotEmpty,
    description: 'Practice hub',
  );
  return app;
}
