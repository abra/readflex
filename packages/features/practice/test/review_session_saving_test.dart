import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/practice.dart';
import 'package:practice/src/review_session_bloc.dart';

import 'helpers/controlled_review_repository.dart';
import 'helpers/practice_harness.dart';

void main() {
  late PracticeHarness h;
  setUp(() async => h = await PracticeHarness.create());
  tearDown(() => h.dispose());
  for (final highlight in [false, true]) {
    for (final largeRtl in [false, true]) {
      for (final reduceMotion in [false, true]) {
        testWidgets(
          'saving ${highlight ? 'highlight' : 'word'} retains its card and disables actions${largeRtl ? ' on RTL phone at 200%' : ''}${reduceMotion ? ' with reduced motion' : ''}',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(disableAnimations: reduceMotion);
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
            final semantics = tester.ensureSemantics();
            try {
              await h.addBook('book');
              if (highlight) {
                await h.addHighlight(
                  'book',
                  'A saved passage that remains visible while its review is stored.',
                );
              } else {
                await h.addWord('word', sourceId: 'book');
              }
              final repository = ControlledReviewRepository(h);
              repository.recordGate = repository.gate;
              addTearDown(repository.release);
              await tester.pumpWidget(
                h.app(
                  ReviewSessionScreen(
                    fsrsRepository: repository,
                    dictionaryRepository: h.dictionary,
                    highlightRepository: h.highlights,
                    bookRepository: h.books,
                    articleRepository: h.articles,
                    preferencesService: h.preferences,
                    onOpenInSource: (_, _) async {},
                  ),
                  locale: Locale(largeRtl ? 'ar' : 'en'),
                  textScaler: TextScaler.linear(largeRtl ? 2 : 1),
                ),
              );
              await settle(tester);
              if (!highlight) {
                await tester.tap(
                  find.byKey(const ValueKey('reviewShowAnswer')),
                );
                await tester.pumpAndSettle();
              }
              final bloc = tester
                  .element(find.byType(ReviewSessionControls))
                  .read<ReviewSessionBloc>();
              final id = bloc.state.current!.itemId;
              final card = find.byKey(ValueKey('reviewCard-$id'));
              final cardElement = tester.element(card);
              final rating = find.byKey(
                ValueKey(highlight ? 'reviewRate-keep' : 'reviewRate-good'),
              );
              final controlsBounds = tester.getRect(
                find.byType(ReviewSessionControls),
              );
              await tester.tap(rating);
              await tester.pump();
              expect(repository.recordStarted.isCompleted, isTrue);
              await tester.pump();

              expect(tester.element(card), same(cardElement));
              expect(
                tester.getRect(find.byType(ReviewSessionControls)),
                controlsBounds,
              );
              expect(
                tester
                    .widget<ReviewSessionControls>(
                      find.byType(ReviewSessionControls),
                    )
                    .isSaving,
                isTrue,
              );
              for (final button in tester.widgetList<ReviewRatingButton>(
                find.byType(ReviewRatingButton),
              )) {
                expect(button.onPressed, isNull);
              }
              final node = tester.getSemantics(rating);
              expect(node.flagsCollection.isEnabled, Tristate.isFalse);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isFalse,
              );
              expect(
                tester
                    .widget<AppPlainIconButton>(
                      find.byKey(const ValueKey('reviewMenu')),
                    )
                    .onPressed,
                isNull,
              );
              final progress = find.byKey(const ValueKey('reviewProgress'));
              expect(
                TickerMode.valuesOf(tester.element(progress)).enabled,
                !reduceMotion,
              );
              expect(tester.getRect(progress).height, 3);
              if (reduceMotion) {
                await tester.pumpAndSettle();
                expect(tester.binding.hasScheduledFrame, isFalse);
              }
              expect(
                tester
                    .widget<AppPlainIconButton>(
                      find.byKey(const ValueKey('reviewClose')),
                    )
                    .onPressed,
                isNotNull,
              );
              expect(
                tester
                    .widget<AppLinearProgressIndicator>(
                      find.byKey(const ValueKey('reviewProgress')),
                    )
                    .value,
                isNull,
              );
              expect(
                Directionality.of(tester.element(rating)),
                largeRtl ? TextDirection.rtl : TextDirection.ltr,
              );
              expect(tester.getRect(rating).height, greaterThanOrEqualTo(48));
              expect(tester.takeException(), isNull);
              await tester.tap(rating);
              await tester.pump();
              repository.release();
              await settle(tester);
              expect(bloc.state.status, ReviewSessionStatus.completed);
              expect(repository.persistedRatings, hasLength(1));
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
