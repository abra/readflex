import 'package:dictionary/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/app_system_ui_mode.dart';
import 'package:readflex/app/routing.dart';
import 'package:translate/translate.dart';

import '../support/ui_test_app.dart';

void main() {
  late UiTestApp app;
  late GoRouter router;

  setUp(() async {
    app = await UiTestApp.create();
    await app.readerServer.start();
    router = buildRouter(deps: app.dependencies);
  });
  tearDown(() async {
    router.dispose();
    await app.dispose();
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scenario in ['none', 'book', 'callback', 'both', 'mismatched']) {
      testWidgets(
        'reader route preserves arguments and page policy: $platform/$scenario',
        (tester) async {
          var opened = 0;
          void onOpened() => opened++;
          var saved = 0;
          void onSaved() => saved++;
          final hasBook = ['book', 'both', 'mismatched'].contains(scenario);
          final hasCallback = [
            'callback',
            'both',
            'mismatched',
          ].contains(scenario);
          final sourceId = scenario == 'mismatched'
              ? 'different-book'
              : app.book!.id;
          final payload = scenario == 'none'
              ? null
              : ReaderRouteArguments(
                  initialSource: hasBook ? app.book : null,
                  onSourceOpened: hasCallback ? onOpened : null,
                  onReadingPositionSaved: hasCallback ? onSaved : null,
                );
          final location = AppRoutes.reader(sourceId);
          final route = router.configuration.routes
              .whereType<GoRoute>()
              .singleWhere((route) => route.path == AppRoutes.readerPath);
          final state = GoRouterState(
            router.configuration,
            uri: Uri.parse(location),
            matchedLocation: location,
            fullPath: AppRoutes.readerPath,
            pathParameters: {'sourceId': sourceId},
            pageKey: const ValueKey('reader'),
            extra: payload,
          );
          late CustomTransitionPage<void> page;
          late ReaderScreen reader;
          await tester.pumpWidget(
            Builder(
              builder: (context) {
                page =
                    route.pageBuilder!(context, state)
                        as CustomTransitionPage<void>;
                // Inspect route wiring without mounting a native WebView in a widget test.
                final content = page.child;
                if (platform == TargetPlatform.android) {
                  expect(content, isA<AppBottomSystemOverlayVisibility>());
                  expect(
                    (content as AppBottomSystemOverlayVisibility).visible,
                    isFalse,
                  );
                  reader = content.child as ReaderScreen;
                } else {
                  reader = content as ReaderScreen;
                }
                return const SizedBox.shrink();
              },
            ),
          );

          expect(page.fullscreenDialog, isTrue);
          expect(page.transitionDuration, Duration.zero);
          expect(page.reverseTransitionDuration, Duration.zero);
          expect(page.key, state.pageKey);
          expect(reader.sourceId, sourceId);
          expect(
            reader.initialSource,
            hasBook && scenario != 'mismatched' ? same(app.book) : isNull,
          );
          expect(reader.onSourceOpened, hasCallback ? same(onOpened) : isNull);
          reader.onSourceOpened?.call();
          expect(opened, hasCallback ? 1 : 0);
          expect(
            reader.onReadingPositionSaved,
            hasCallback ? same(onSaved) : isNull,
          );
          reader.onReadingPositionSaved?.call();
          expect(saved, hasCallback ? 1 : 0);
          expect(reader.textActions, hasLength(4));
          // A word already in the target language opens the definition from
          // the very dictionary action the menu offers.
          final translate = reader.textActions
              .whereType<TranslateAction>()
              .single;
          final dictionary = reader.textActions
              .whereType<DictionaryAction>()
              .single;
          expect(translate.onDefine, dictionary.onExecute);
          expect(reader.serverBaseUri, app.readerServer.baseUri);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
