import 'dart:async';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'golden_support.dart';

/// Status steps (uploading, done, failure) keep the menu's sheet height and
/// fit their content without scrolling in production fonts; the progress bar
/// takes the row that Done or Retry occupy afterwards.
void main() {
  setUpAll(loadUiFonts);

  Book book() => Book(
    id: 'book-1',
    title: 'Test',
    filePath: 'book.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  );

  Rect icon(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('importFlowStatusIcon')));

  double contentScrollExtent(WidgetTester tester) => Scrollable.of(
    tester.element(find.byKey(const ValueKey('importFlowStatusIcon'))),
  ).position.maxScrollExtent;

  /// Inspects intermediate frames too: equal final sizes can hide a jump.
  Future<void> expectLevelFrames(WidgetTester tester, Rect menuRect) async {
    for (var frame = 0; frame < 22; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(find.byType(BottomSheet)), menuRect);
    }
  }

  Future<void> expectSettled(WidgetTester tester, Rect menuRect) async {
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), menuRect);
    expect(contentScrollExtent(tester), 0);
    expect(tester.takeException(), isNull);
  }

  for (final locale in ReadflexSupportedLocales.locales) {
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets(
        'status steps keep the menu height ${locale.languageCode} $width',
        (tester) async {
          late BuildContext host;
          await pumpGoldenSurface(
            tester,
            VisualProfile.phone,
            (context) {
              host = context;
              return const Scaffold();
            },
            surfaceSize: Size(width, 700),
            locale: locale,
          );
          final l10n = host.l10n;

          Future<void> run({
            required Future<Book?> Function() importBook,
            required String terminalLabel,
            required void Function(Rect bar) check,
          }) async {
            final imported = Completer<Book?>();
            void Function(double)? reportProgress;
            unawaited(
              showImportFlowSheet(
                host,
                onPickBookFile: () async => File('/tmp/Test.epub'),
                onImportBook: (_, {onProgress}) {
                  reportProgress = onProgress;
                  return imported.future;
                },
                onImportArticle: (_, {onStage}) async => null,
              ),
            );
            await tester.pumpAndSettle();
            final menuRect = tester.getRect(find.byType(BottomSheet));

            await tester.tap(find.text(l10n.importUploadBook));
            await tester.pump();
            await expectLevelFrames(tester, menuRect);
            // A determinate bar lets the frame settle; the preparing phase
            // animates indefinitely.
            expect(reportProgress, isNotNull);
            reportProgress!(0.45);
            await tester.pump();
            await expectSettled(tester, menuRect);
            final uploadingIcon = icon(tester);
            final bar = tester.getRect(find.byType(LinearProgressIndicator));
            expect(
              bar.top,
              greaterThan(tester.getRect(find.text('Test.epub')).bottom),
            );
            expect(bar.bottom, lessThan(menuRect.bottom));

            imported.complete(await importBook());
            await tester.pump();
            await expectLevelFrames(tester, menuRect);
            await expectSettled(tester, menuRect);
            expect(find.text(terminalLabel), findsOneWidget);
            expect(icon(tester), uploadingIcon);
            check(bar);

            await tester.tap(find.byTooltip(l10n.commonClose));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
          }

          // Failure shows a single Retry; the header Close is the way out,
          // so no translation can stack a second command row.
          await run(
            importBook: () async => null,
            terminalLabel: l10n.importChooseFile,
            check: (bar) {
              expect(find.byType(FilledButton), findsOneWidget);
              expect(find.byType(OutlinedButton), findsNothing);
              expect(find.text(l10n.commonCancel), findsNothing);
              final sheet = tester.getRect(find.byType(BottomSheet));
              final retry = tester.getRect(
                find.widgetWithText(FilledButton, l10n.importChooseFile),
              );
              // Retry spans the gutters and takes the progress bar's row.
              expect(retry.left, sheet.left + AppSpacing.xl);
              expect(retry.right, sheet.right - AppSpacing.xl);
              expect(
                tester.getRect(find.text('Test.epub')).bottom,
                lessThan(retry.top),
              );
              expect(retry.bottom, closeTo(bar.bottom, 48));
            },
          );
          await run(
            importBook: () async => book(),
            terminalLabel: l10n.importBookAdded,
            check: (bar) {
              final done = tester.getRect(
                find.widgetWithText(FilledButton, l10n.commonDone),
              );
              expect(done.bottom, closeTo(bar.bottom, 48));
            },
          );
        },
      );
    }
  }
}
