import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:library_feature/library_feature.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/reading_fixture.dart';
import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

const _url = 'https://example.com/articles/reading';
const _filename = 'A Small Book About Reading.epub';

void main() {
  setUpAll(loadUiFonts);
  late UiTestApp app;
  setUp(() async {
    app = await UiTestApp.create();
  });
  tearDown(() => app.dispose());

  for (final (name, profile, locale, size) in [
    ('phone', VisualProfile.phone, const Locale('en'), const Size(390, 844)),
    ('phoneRu', VisualProfile.phone, const Locale('ru'), const Size(390, 844)),
    ('dark', VisualProfile.dark, const Locale('en'), const Size(390, 844)),
    (
      'largeText',
      VisualProfile.largeText,
      const Locale('de'),
      const Size(320, 568),
    ),
    (
      'phoneRtl',
      VisualProfile.tabletRtl,
      const Locale('ar'),
      const Size(390, 844),
    ),
    (
      'landscape',
      VisualProfile.landscape,
      const Locale('en'),
      const Size(844, 390),
    ),
  ]) {
    testWidgets('import recovery and progress $name', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'not a URL'};
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      late BuildContext host;
      await pumpGoldenSurface(
        tester,
        profile,
        (context) {
          host = context;
          return LibraryScreen(
            bookRepository: app.bookRepository,
            articleRepository: app.articleRepository,
            collectionRepository: app.collectionRepository,
            preferencesService: app.preferencesService,
            onSourcePressed: (_, {onSourceOpened}) async {},
            onAddPressed: ({required onImported}) async {},
          );
        },
        surfaceSize: size,
        locale: locale,
      );
      await waitForUi(
        tester,
        () => find.text(ReadingFixture.bookTitle).evaluate().isNotEmpty,
        description: 'isolated Library fixture',
      );
      await tester.pumpAndSettle();
      final l10n = host.l10n;

      Future<void> snapshot(String scene) async {
        expect(tester.takeException(), isNull, reason: '$name/$scene');
        expect(tester.view.physicalSize, size);
        await expectLater(
          find.byKey(goldenBoundary),
          matchesGoldenFile('goldens/$name/import-$scene.png'),
        );
      }

      Future<void> tapLabel(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      final imported = Completer<Book?>();
      var pickerCalls = 0;
      final offline = StreamController<bool>();
      addTearDown(offline.close);
      unawaited(
        showImportFlowSheet(
          host,
          isOfflineStream: offline.stream,
          onPickBookFile: () async =>
              ++pickerCalls == 1 ? File('/tmp/$_filename') : null,
          onImportBook: (_, {onProgress}) {
            onProgress!(0.45);
            return imported.future;
          },
          onImportArticle: (_, {onStage}) async => null,
        ),
      );
      await tester.pumpAndSettle();
      final menuRect = tester.getRect(find.byType(BottomSheet));
      if (profile.scale == 1) {
        expect(menuRect.height, lessThanOrEqualTo(300));
      }
      await snapshot('menu');
      offline.add(true);
      await tester.pumpAndSettle();
      await snapshot('menu-offline');
      offline.add(false);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.importUploadBook));
      await tester.tap(find.text(l10n.importUploadBook));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await snapshot('book-progress');
      final progress = tester.renderObject<RenderParagraph>(find.text('45%'));
      expect(progress.didExceedMaxLines, isFalse);
      if (profile.scale > 1) expect(progress.size.height, greaterThan(16));

      imported.complete(null);
      await tester.pumpAndSettle();
      _expectReadableActions(tester);
      final choose = tester.getRect(
        find.widgetWithText(FilledButton, l10n.importChooseFile),
      );
      final cancel = tester.getRect(
        find.widgetWithText(OutlinedButton, l10n.commonCancel),
      );
      if (name == 'largeText') {
        expect(choose.top, greaterThan(cancel.bottom));
      } else if (name == 'phone') {
        expect(choose.top, cancel.top);
      }
      await snapshot('book-failure');
      await tapLabel(l10n.importChooseFile);
      expect(pickerCalls, 2);
      expect(find.text(l10n.importBookImportFailed), findsOneWidget);
      await tapLabel(l10n.commonCancel);

      final urls = <String>[];
      unawaited(
        showImportFlowSheet(
          host,
          onPickBookFile: () async => null,
          onImportBook: (_, {onProgress}) async => null,
          onImportArticle: (url, {onStage}) async {
            urls.add(url);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tapLabel(l10n.importSaveArticle);
      expect(tester.getRect(find.byType(BottomSheet)), menuRect);
      if (profile.scale == 1) {
        expect(
          Scrollable.of(
            tester.element(find.byType(EditableText).last),
          ).position.maxScrollExtent,
          0,
          reason: 'the normal-sized URL form fits without scrolling',
        );
        // TextField also includes invisible validation space. Compare the
        // visible input container, not that larger widget, to the hint group.
        final input = InputDecorator.containerOf(
          tester.element(find.byType(EditableText).last),
        )!;
        final inputBottom = input
            .localToGlobal(Offset(0, input.size.height))
            .dy;
        final above =
            tester.getRect(find.text(l10n.importArticleHintClean)).top -
            inputBottom;
        final below =
            tester
                .getRect(find.widgetWithText(FilledButton, l10n.commonSave))
                .top -
            tester.getRect(find.text(l10n.importArticleHintLibrary)).bottom;
        expect(above, inInclusiveRange(16, 32));
        expect(below, inInclusiveRange(16, 32));
        expect(above, closeTo(below, 8));
      }
      await snapshot('article-entry');
      await tester.ensureVisible(
        find.byKey(const ValueKey('articleUrlPasteButton')),
      );
      List<Rect> formGeometry() => [
        tester.getRect(find.byType(TextField).last),
        tester.getRect(find.text(l10n.importArticleHintClean)),
        tester.getRect(find.text(l10n.importArticleHintLibrary)),
        tester.getRect(find.widgetWithText(FilledButton, l10n.commonSave)),
      ];
      final beforeError = formGeometry();
      await tester.tap(find.byKey(const ValueKey('articleUrlPasteButton')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).decoration!.error,
        isNotNull,
      );
      expect(find.text(l10n.importInvalidArticleUrl), findsOneWidget);
      expect(formGeometry(), beforeError);
      await snapshot('invalid-paste');
      await tester.enterText(find.byType(TextField).last, _url);
      await tester.pump();
      await tapLabel(l10n.commonSave);
      _expectReadableActions(tester);
      await snapshot('article-failure');
      await tapLabel(l10n.importEditLink);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, _url);
      expect(field.decoration!.error, isNull);
      expect(urls, [_url]);
      expect(
        Directionality.of(tester.element(find.byType(TextField).last)),
        locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await snapshot('article-edit');
      await unmountUi(tester);
    }, tags: ['golden']);
  }
}

void _expectReadableActions(WidgetTester tester) {
  for (final type in [FilledButton, OutlinedButton]) {
    final button = find.byType(type).last;
    final text = find.descendant(of: button, matching: find.byType(Text));
    expect(
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
      isFalse,
    );
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(button.hitTestable(), findsOneWidget);
  }
}
