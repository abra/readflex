import 'dart:ui' show SemanticsAction, Tristate;

import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

import '../test_support/platform_test_app.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final confirmed in [false, true]) {
      testWidgets('$platform returns an explicit confirmation=$confirmed', (
        tester,
      ) async {
        final results = <bool?>[];
        await _open(tester, platform: platform, onResult: results.add);
        final dialog = find.byType(AppConfirmationDialog);
        final context = tester.element(dialog);
        expect(
          find.descendant(of: dialog, matching: find.byType(AppSurface)),
          findsNothing,
        );
        for (final key in [
          AppConfirmationDialog.cancelButtonKey,
          AppConfirmationDialog.confirmButtonKey,
        ]) {
          final rect = tester.getRect(find.byKey(key));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(cupertino.CupertinoAlertDialog), findsOneWidget);
          expect(find.byType(material.AlertDialog), findsNothing);
          final actions = tester.widgetList<cupertino.CupertinoDialogAction>(
            find.byType(cupertino.CupertinoDialogAction),
          );
          expect(actions.first.isDefaultAction, isTrue);
          expect(actions.first.isDestructiveAction, isFalse);
          expect(actions.last.isDefaultAction, isFalse);
          expect(actions.last.isDestructiveAction, isTrue);
          expect(actions.last.textStyle!.color, context.colors.error);
        } else {
          expect(find.byType(material.AlertDialog), findsOneWidget);
          expect(find.byType(cupertino.CupertinoAlertDialog), findsNothing);
          final action = tester.widget<AppButton>(
            find.byKey(AppConfirmationDialog.confirmButtonKey),
          );
          expect(action.variant, AppButtonVariant.text);
          expect(action.foregroundColor, context.colors.error);
          expect(
            tester
                .widget<AppButton>(
                  find.byKey(AppConfirmationDialog.cancelButtonKey),
                )
                .autofocus,
            isTrue,
          );
        }
        await tester.tap(
          find.byKey(
            confirmed
                ? AppConfirmationDialog.confirmButtonKey
                : AppConfirmationDialog.cancelButtonKey,
          ),
        );
        await tester.pumpAndSettle();
        expect(results, [confirmed]);
        expect(dialog, findsNothing);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform keeps Cancel as the default keyboard command', (
      tester,
    ) async {
      final results = <bool?>[];
      await _open(tester, platform: platform, onResult: results.add);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(find.byType(AppConfirmationDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform exposes one enabled action per label at $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final results = <bool?>[];
          await _open(
            tester,
            platform: platform,
            scale: scale,
            copy: _german,
            onResult: results.add,
          );
          for (final label in [_german.cancel, _german.confirm]) {
            expect(find.bySemanticsLabel(label), findsOneWidget);
            final data = tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData();
            expect(data.flagsCollection.isButton, isTrue, reason: '$data');
            expect(
              data.flagsCollection.isEnabled,
              Tristate.isTrue,
              reason: '$data',
            );
            expect(data.hasAction(SemanticsAction.tap), isTrue);
          }
          final confirm = tester.getSemantics(
            find.bySemanticsLabel(_german.confirm),
          );
          confirm.owner!.performAction(confirm.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(results, [true]);
          expect(find.byType(AppConfirmationDialog), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }

    testWidgets('$platform retains its scrim policy and system Back cancels', (
      tester,
    ) async {
      final results = <bool?>[];
      await _open(tester, platform: platform, onResult: results.add);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(AppConfirmationDialog), findsOneWidget);
        expect(results, isEmpty);
      } else {
        expect(results, [null]);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(results, platform == TargetPlatform.iOS ? [null] : [null, null]);
      expect(find.byType(AppConfirmationDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$platform captures a nested dark theme on the root navigator',
      (
        tester,
      ) async {
        final results = <bool?>[];
        await _open(
          tester,
          platform: platform,
          nestedDark: true,
          onResult: results.add,
          size: const Size(1024, 768),
        );
        final dialogContext = tester.element(
          find.byType(AppConfirmationDialog),
        );
        final root = Navigator.of(dialogContext, rootNavigator: true);
        final opener = tester.element(find.text('Open'));
        final nested = Navigator.of(opener);
        expect(nested, isNot(same(root)));
        expect(Navigator.of(dialogContext), same(root));
        expect(dialogContext.colors.brightness, Brightness.dark);
        expect(material.Theme.of(dialogContext).brightness, Brightness.dark);
        if (platform == TargetPlatform.iOS) {
          expect(
            cupertino.CupertinoTheme.of(dialogContext).brightness,
            Brightness.dark,
          );
        }
        expect(root.canPop(), isTrue);
        await tester.tap(find.byKey(AppConfirmationDialog.confirmButtonKey));
        await tester.pumpAndSettle();
        expect(results, [true]);
        expect(root.canPop(), isFalse);
        expect(nested.canPop(), isFalse);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$platform ignores a repeated confirmation during exit', (
      tester,
    ) async {
      final results = <bool?>[];
      await _open(tester, platform: platform, onResult: results.add);
      final dialog = tester.widget<AppConfirmationDialog>(
        find.byType(AppConfirmationDialog),
      );
      dialog.onConfirm();
      dialog.onConfirm();
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      for (final copy in [_german, _arabic]) {
        testWidgets('$platform long ${copy.direction} alert stays reachable '
            'at320dp/200% $brightness', (tester) async {
          final results = <bool?>[];
          await _open(
            tester,
            platform: platform,
            brightness: brightness,
            scale: 2,
            copy: copy,
            onResult: results.add,
          );
          final dialog = find.byType(AppConfirmationDialog);
          expect(Directionality.of(tester.element(dialog)), copy.direction);
          for (final label in [copy.cancel, copy.confirm]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(label),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          final scrollable = find
              .ancestor(
                of: find.text(copy.message),
                matching: find.byType(Scrollable),
              )
              .first;
          final state = tester.state<ScrollableState>(scrollable);
          expect(state.position.maxScrollExtent, greaterThan(0));
          await tester.drag(scrollable, const Offset(0, -150));
          await tester.pumpAndSettle();
          expect(state.position.pixels, greaterThan(0));
          state.position.jumpTo(state.position.maxScrollExtent);
          await tester.pump();
          expect(
            state.position.pixels,
            state.position.maxScrollExtent,
          );
          final action = find.byKey(AppConfirmationDialog.confirmButtonKey);
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          final rect = tester.getRect(action);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.center.dy, inInclusiveRange(0, 568));
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(results, [true]);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final features in [
      const FakeAccessibilityFeatures(reduceMotion: true),
      const FakeAccessibilityFeatures(disableAnimations: true),
    ]) {
      testWidgets('$platform reduced motion settles alert on its first frame '
          '$features', (tester) async {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            features;
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final results = <bool?>[];
        await _open(
          tester,
          platform: platform,
          onResult: results.add,
          settle: false,
        );
        final context = tester.element(find.byType(AppConfirmationDialog));
        final route = ModalRoute.of(context)!;
        expect(route.animation!.status, AnimationStatus.completed);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(AppConfirmationDialog), findsNothing);
        expect(results, [null]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

typedef _DialogCopy = ({
  String title,
  String message,
  String confirm,
  String cancel,
  TextDirection direction,
});

const _english = (
  title: 'Delete this book?',
  message: 'Learning data will be kept.',
  confirm: 'Delete',
  cancel: 'Keep',
  direction: TextDirection.ltr,
);
final _german = (
  title: 'Ausgewählte Bücher aus der Bibliothek entfernen?',
  message: List.filled(
    30,
    'Ihre gespeicherten Lernfortschritte bleiben erhalten.',
  ).join(' '),
  confirm: 'Ausgewählte Bücher löschen',
  cancel: 'Ausgewählte Bücher behalten',
  direction: TextDirection.ltr,
);
final _arabic = (
  title: 'هل تريد حذف الكتب المحددة من المكتبة؟',
  message: List.filled(30, 'سيتم الاحتفاظ ببيانات التعلم الخاصة بك.').join(' '),
  confirm: 'حذف الكتب المحددة',
  cancel: 'الاحتفاظ بالكتب المحددة',
  direction: TextDirection.rtl,
);

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  required ValueChanged<bool?> onResult,
  Brightness brightness = Brightness.light,
  double scale = 1,
  _DialogCopy copy = _english,
  Size size = const Size(320, 568),
  bool nestedDark = false,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final opener = Directionality(
    textDirection: copy.direction,
    child: _DialogOpener(copy: copy, onResult: onResult),
  );
  await tester.pumpWidget(
    PlatformTestApp(
      platform: platform,
      brightness: brightness,
      textScale: scale,
      home: nestedDark
          ? Navigator(
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => AppPlatformTheme(
                  platform: platform,
                  brightness: Brightness.dark,
                  child: opener,
                ),
              ),
            )
          : opener,
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

class _DialogOpener extends StatelessWidget {
  const _DialogOpener({required this.copy, required this.onResult});

  final _DialogCopy copy;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) => Center(
    child: AppButton(
      onPressed: () async {
        final result = await showAppConfirmationDialog(
          context,
          title: copy.title,
          message: copy.message,
          confirmLabel: copy.confirm,
          cancelLabel: copy.cancel,
          destructive: true,
        );
        onResult(result);
      },
      child: const Text('Open'),
    ),
  );
}
