import 'dart:ui' show SemanticsAction, Tristate;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_capsule_action_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

Future<void> _pumpAction(
  WidgetTester tester, {
  required Animation<double> progress,
  TargetPlatform platform = TargetPlatform.android,
  bool searchActive = false,
  Locale locale = const Locale('en'),
  VoidCallback? onAddPressed,
  VoidCallback? onSearchClosed,
}) async {
  await tester.pumpWidget(
    PlatformTestApp(
      platform: platform,
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      home: Center(
        child: LibraryCapsuleActionButton(
          progress: progress,
          searchActive: searchActive,
          onAddPressed: onAddPressed,
          onSearchClosed: onSearchClosed,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _opacityOf(WidgetTester tester, IconData icon) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byIcon(icon),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('plus and chevron cross-fade without changing glyph geometry', (
    tester,
  ) async {
    for (final progress in [0.0, .5, 1.0]) {
      await _pumpAction(
        tester,
        progress: AlwaysStoppedAnimation(progress),
        onAddPressed: () {},
      );
      expect(_opacityOf(tester, AppIcons.add), 1 - progress);
      expect(_opacityOf(tester, AppIcons.chevronRight), progress);
      expect(tester.getSize(find.byIcon(AppIcons.add)), const Size.square(24));
      expect(
        tester.getSize(find.byIcon(AppIcons.chevronRight)),
        const Size.square(24),
      );
      expect(
        tester.getCenter(find.byIcon(AppIcons.add)),
        tester.getCenter(find.byIcon(AppIcons.chevronRight)),
      );
    }
  });

  testWidgets('the closing chevron follows the reading direction', (
    tester,
  ) async {
    for (final (locale, chevron, other) in const [
      (Locale('en'), AppIcons.chevronRight, AppIcons.chevronLeft),
      (Locale('ar'), AppIcons.chevronLeft, AppIcons.chevronRight),
    ]) {
      await _pumpAction(
        tester,
        progress: const AlwaysStoppedAnimation(1),
        searchActive: true,
        locale: locale,
        onSearchClosed: () {},
      );
      expect(find.byIcon(chevron), findsOneWidget);
      expect(find.byIcon(other), findsNothing);
      expect(_opacityOf(tester, chevron), 1);
    }
  });

  testWidgets('progress updates retain the button and both static glyphs', (
    tester,
  ) async {
    final progress = AnimationController(vsync: tester);
    addTearDown(progress.dispose);
    await _pumpAction(tester, progress: progress, onAddPressed: () {});
    final button = tester.widget<AppIconButton>(find.byType(AppIconButton));
    final plus = tester.element(find.byIcon(AppIcons.add));
    final chevron = tester.element(find.byIcon(AppIcons.chevronRight));
    progress.value = .5;
    await tester.pump();
    expect(
      tester.widget<AppIconButton>(find.byType(AppIconButton)),
      same(button),
    );
    expect(tester.element(find.byIcon(AppIcons.add)), same(plus));
    expect(tester.element(find.byIcon(AppIcons.chevronRight)), same(chevron));
    expect(_opacityOf(tester, AppIcons.add), .5);
    expect(_opacityOf(tester, AppIcons.chevronRight), .5);
    expect(tester.getSize(find.byType(AppIconButton)), const Size.square(48));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform exposes the current action and disabled state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var additions = 0;
        var closures = 0;
        var expectedAdditions = 0;
        var expectedClosures = 0;
        Rect? originalBounds;
        Element? originalButton;
        for (final searchActive in [false, true, false]) {
          for (final enabled in [true, false]) {
            await _pumpAction(
              tester,
              platform: platform,
              progress: AlwaysStoppedAnimation(searchActive ? 1 : 0),
              searchActive: searchActive,
              onAddPressed: enabled ? () => additions++ : null,
              onSearchClosed: enabled ? () => closures++ : null,
            );
            final button = find.byKey(
              const ValueKey('libraryCapsuleActionButton'),
            );
            final nativeButton = find.descendant(
              of: button,
              matching: find.byType(
                platform == TargetPlatform.iOS ? CupertinoButton : IconButton,
              ),
            );
            originalButton ??= tester.element(nativeButton);
            expect(tester.element(nativeButton), same(originalButton));
            final l10n = tester.element(button).l10n;
            final label = searchActive
                ? l10n.commonBack
                : l10n.importAddToLibraryTitle;
            final data = tester.getSemantics(button).getSemanticsData();
            expect('${data.label} ${data.tooltip}', contains(label));
            expect(data.flagsCollection.isButton, isTrue);
            expect(
              data.flagsCollection.isEnabled,
              enabled ? Tristate.isTrue : Tristate.isFalse,
            );
            expect(data.hasAction(SemanticsAction.tap), enabled);
            expect(tester.getSize(button), const Size.square(48));
            originalBounds ??= tester.getRect(button);
            expect(tester.getRect(button), originalBounds);
            await tester.tap(button);
            await tester.pumpAndSettle();
            if (enabled) {
              if (searchActive) {
                expectedClosures++;
              } else {
                expectedAdditions++;
              }
            }
            expect(additions, expectedAdditions);
            expect(closures, expectedClosures);
          }
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
