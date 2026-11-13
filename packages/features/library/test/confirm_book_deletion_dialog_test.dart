import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/confirm_book_deletion_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

final _confirm = find.byKey(AppConfirmationDialog.confirmButtonKey);
final _keep = find.byKey(AppConfirmationDialog.cancelButtonKey);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final locale in [
      const Locale('en'),
      const Locale('de'),
      const Locale('ar'),
    ]) {
      for (final count in [1, 7]) {
        final largeText = locale.languageCode != 'en';
        testWidgets('$platform deletion confirms $count items and preserves '
            'learning data ($locale / ${largeText ? 200 : 100}%)', (
          tester,
        ) async {
          BookDeletionScope? result;
          var completed = false;
          final strings = await _openDialog(
            tester,
            platform: platform,
            locale: locale,
            textScale: largeText ? 2 : 1,
            size: largeText ? const Size(320, 568) : const Size(390, 844),
            count: count,
            onResult: (value) {
              result = value;
              completed = true;
            },
          );
          expect(
            find.byType(CupertinoAlertDialog),
            platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(AlertDialog),
            platform == TargetPlatform.android ? findsOneWidget : findsNothing,
          );
          expect(find.byType(BottomSheet), findsNothing);
          for (final label in [
            strings.libraryDeleteItemsTitle(count),
            strings.libraryDeleteItemsBody(count),
          ]) {
            final text = find.text(label);
            expect(text, findsOneWidget);
            expect(
              tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
              isFalse,
            );
          }
          expect(find.byType(Checkbox), findsNothing);
          expect(find.text(strings.commonCancel), findsNothing);
          for (final target in [_keep, _confirm]) {
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            final bounds = tester.getRect(target);
            expect(bounds.width, greaterThanOrEqualTo(48));
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(target.hitTestable(), findsOneWidget);
          }
          if (platform == TargetPlatform.iOS) {
            final keepAction = tester.widget<CupertinoDialogAction>(
              find.descendant(
                of: _keep,
                matching: find.byType(CupertinoDialogAction),
                matchRoot: true,
              ),
            );
            final deleteAction = tester.widget<CupertinoDialogAction>(
              find.descendant(
                of: _confirm,
                matching: find.byType(CupertinoDialogAction),
                matchRoot: true,
              ),
            );
            expect(keepAction.isDefaultAction, isTrue);
            expect(deleteAction.isDestructiveAction, isTrue);
          }
          await tester.tap(_confirm);
          await tester.pumpAndSettle();
          expect(completed, isTrue);
          expect(result, BookDeletionScope.keepLearningData);
          expect(find.byType(AppConfirmationDialog), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('$platform Keep cancels without a deletion result', (
      tester,
    ) async {
      BookDeletionScope? result = BookDeletionScope.keepLearningData;
      var completed = false;
      await _openDialog(
        tester,
        platform: platform,
        count: 3,
        onResult: (value) {
          result = value;
          completed = true;
        },
      );
      await tester.tap(_keep);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byType(AppConfirmationDialog), findsNothing);
    });

    testWidgets('$platform dismissal follows its native scrim policy', (
      tester,
    ) async {
      BookDeletionScope? result;
      var completed = false;
      await _openDialog(
        tester,
        platform: platform,
        onResult: (value) {
          result = value;
          completed = true;
        },
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(AppConfirmationDialog), findsOneWidget);
        expect(completed, isFalse);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byType(AppConfirmationDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform tablet deletion uses a dialog above the Library', (
      tester,
    ) async {
      await _openDialog(
        tester,
        platform: platform,
        count: 42,
        size: const Size(1032, 1376),
        onResult: (_) {},
      );
      expect(find.byType(AppConfirmationDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getCenter(_confirm).dy, lessThan(1376 * .75));
      expect(tester.getCenter(_keep).dy, lessThan(1376 * .75));
      await tester.tap(_keep);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<ReadflexLocalizations> _openDialog(
  WidgetTester tester, {
  required TargetPlatform platform,
  required ValueChanged<BookDeletionScope?> onResult,
  int count = 1,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PlatformTestApp(
      platform: platform,
      locale: locale,
      textScale: textScale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      home: Builder(
        builder: (context) => Center(
          child: AppButton(
            onPressed: () async => onResult(
              await showConfirmBookDeletionDialog(context, count: count),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  final strings = tester.element(find.text('Open')).l10n;
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return strings;
}
