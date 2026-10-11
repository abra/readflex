import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reader/reader.dart';
import 'package:readflex/app/app_system_ui_mode.dart';
import 'package:readflex/app/routing.dart';
import 'package:readflex/app/screens/onboarding_selection_sample.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import '../support/ui_test_app.dart';

/// Onboarding draws the reader's text selection menu. This keeps the picture
/// honest: its commands must be the reader's own, composed in `routing.dart`,
/// in the same order, with the same glyphs and labels.
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

  testWidgets('onboarding menu commands match the reader selection menu', (
    tester,
  ) async {
    final route = router.configuration.routes.whereType<GoRoute>().singleWhere(
      (route) => route.path == AppRoutes.readerPath,
    );
    final location = AppRoutes.reader(app.book!.id);
    final state = GoRouterState(
      router.configuration,
      uri: Uri.parse(location),
      matchedLocation: location,
      fullPath: AppRoutes.readerPath,
      pathParameters: {'sourceId': app.book!.id},
      pageKey: const ValueKey('reader'),
    );

    late List<TextAction> readerActions;
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            final page =
                route.pageBuilder!(builderContext, state)
                    as CustomTransitionPage<void>;
            // Inspect route wiring without mounting a native WebView.
            final reader = switch (page.child) {
              final AppBottomSystemOverlayVisibility android =>
                android.child as ReaderScreen,
              final content => content as ReaderScreen,
            };
            readerActions = reader.textActions;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // The reader puts its one color highlight action beside the swatches and
    // the rest, in order, in the menu's command row.
    expect(readerActions.whereType<ColorHighlightTextAction>(), hasLength(1));
    final commands = readerActions
        .where((action) => action is! ColorHighlightTextAction)
        .toList();
    final l10n = ReadflexLocalizations.of(context)!;

    expect(
      [for (final action in onboardingSelectionMenuActions) action.icon],
      [for (final action in commands) action.icon],
    );
    expect(
      [for (final action in onboardingSelectionMenuActions) action.label(l10n)],
      [for (final action in commands) action.labelFor(context)],
    );
  });
}
