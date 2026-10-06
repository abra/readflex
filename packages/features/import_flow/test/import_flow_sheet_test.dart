import 'dart:async';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;
  var clipboardReadCount = 0;
  Future<Object?> Function()? readClipboard;

  setUp(() {
    clipboardText = null;
    clipboardReadCount = 0;
    readClipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              clipboardReadCount += 1;
              if (readClipboard != null) return readClipboard!();
              return clipboardText == null ? null : {'text': clipboardText};
            case 'Clipboard.setData':
              clipboardText = (call.arguments as Map?)?['text'] as String?;
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final systemBack in [false, true]) {
    testWidgets('form back preserves URL, systemBack=$systemBack', (
      tester,
    ) async {
      await _openArticleForm(tester);
      expect(find.text('Back'), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/draft',
      );
      tester.testTextInput.hide();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Add to Library'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      await tester.tap(find.text('Save Article'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'https://example.com/draft'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final method in ['close', 'scrim', 'drag']) {
    testWidgets('article $method dismisses the entire flow', (tester) async {
      await _openArticleForm(tester);
      switch (method) {
        case 'close':
          await tester.tap(find.byTooltip('Close'));
        case 'scrim':
          await tester.tapAt(const Offset(10, 20));
        case 'drag':
          final sheet = tester.getRect(find.byType(BottomSheet));
          await tester.dragFrom(
            Offset(sheet.center.dx, sheet.top + 10),
            const Offset(0, 450),
          );
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('terms back returns without accepting or opening the picker', (
    tester,
  ) async {
    var accepted = 0;
    var picked = 0;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isBookImportTermsAccepted: () => false,
          acceptBookImportTerms: () async {
            accepted++;
          },
          onPickBookFile: () async {
            picked++;
            return null;
          },
          onImportBook: (_, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    for (final systemBack in [false, true]) {
      await tester.tap(find.text('Upload Book'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Add to Library'), findsOneWidget);
    }
    expect(accepted, 0);
    expect(picked, 0);
  });

  testWidgets('large text and keyboard keep the import form usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final urls = <String>[];
    await tester.pumpWidget(
      _TestHost(
        textScaler: const TextScaler.linear(2),
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (url, {onStage}) async {
            urls.add(url);
            return null;
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save Article'));
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(urls, ['https://example.com/a']);
    expect(tester.takeException(), isNull);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('RTL navigation respects reduced motion=$reducedMotion', (
      tester,
    ) async {
      late ReadflexLocalizations l10n;
      await tester.pumpWidget(
        _TestHost(
          locale: const Locale('ar'),
          reducedMotion: reducedMotion,
          onOpen: (context) {
            l10n = context.l10n;
            return showImportFlowSheet(
              context,
              onPickBookFile: () async => null,
              onImportBook: (_, {onProgress}) async => null,
              onImportArticle: (_, {onStage}) async => null,
            );
          },
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(BottomSheet));
      await tester.tap(find.text(l10n.importSaveArticle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (reducedMotion) {
        expect(find.text(l10n.importAddToLibraryTitle), findsNothing);
      } else {
        final form = find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(ActionBottomSheetLayout),
        );
        expect(tester.getRect(form).left, lessThan(sheet.left));
      }
      await tester.pumpAndSettle();
      final back = find.byTooltip(l10n.commonBack);
      final close = find.byTooltip(l10n.commonClose);
      expect(
        tester.getCenter(back).dx,
        greaterThan(tester.getCenter(close).dx),
      );
      expect(tester.getSize(back), const Size(48, 48));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text(l10n.importAddToLibraryTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('paste responds at the edge of a 48px target', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    clipboardText = 'https://example.com/pasted';
    final paste = find.byKey(const ValueKey('articleUrlPasteButton'));
    expect(tester.getSize(paste).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(paste).height, greaterThanOrEqualTo(48));
    await tester.tapAt(tester.getTopLeft(paste) + const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(clipboardReadCount, 1);
    expect(find.text(clipboardText!), findsOneWidget);
  });

  testWidgets('menu shows flat book and link actions with a header close', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsOneWidget);
    expect(find.text('Upload Book'), findsOneWidget);
    expect(find.byIcon(AppIcons.book), findsOneWidget);
    expect(find.byIcon(AppIcons.link), findsOneWidget);
    expect(find.byIcon(AppIcons.chevronRight), findsNWidgets(2));
    expect(find.byType(AppActionCard), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(clipboardReadCount, 0);
    final divider = tester.getRect(find.byType(Divider));
    final row = tester.getRect(find.byKey(const ValueKey('importMenu-book')));
    expect(divider.left, row.left);
    expect(divider.right, row.right);
    final dividerWidget = tester.widget<Divider>(find.byType(Divider));
    expect(dividerWidget.color, isNull, reason: 'use the shared divider theme');
    expect(dividerWidget.thickness, isNull);
  });

  for (final locale in ReadflexSupportedLocales.locales) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('URL feedback does not move the form: $locale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          late ReadflexLocalizations l10n;
          await tester.pumpWidget(
            _TestHost(
              locale: locale,
              textScaler: TextScaler.linear(scale),
              onOpen: (context) {
                l10n = context.l10n;
                return showImportFlowSheet(
                  context,
                  onPickBookFile: () async => null,
                  onImportBook: (_, {onProgress}) async => null,
                  onImportArticle: (_, {onStage}) async => null,
                );
              },
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(l10n.importSaveArticle));
          await tester.tap(find.text(l10n.importSaveArticle));
          await tester.pumpAndSettle();
          final field = find.byType(TextField);
          final paste = find.byKey(const ValueKey('articleUrlPasteButton'));
          await tester.ensureVisible(paste);
          await tester.pumpAndSettle();
          List<Rect> geometry() {
            // Focus can scroll a narrow form; compare its content coordinates.
            final offset = Scrollable.of(tester.element(field)).position.pixels;
            final content = [
              tester.getRect(field),
              tester.getRect(find.text(l10n.importArticleHintClean)),
              tester.getRect(find.text(l10n.importArticleHintLibrary)),
            ].map((rect) => rect.translate(0, offset)).toList();
            final save = find.widgetWithText(FilledButton, l10n.commonSave);
            final footerScroll = Scrollable.maybeOf(tester.element(save));
            return [
              ...content,
              tester
                  .getRect(save)
                  .translate(0, footerScroll?.position.pixels ?? 0),
            ];
          }

          final before = geometry();
          var edits = 0;
          for (final (clipboard, message) in [
            ('invalid link', l10n.importInvalidArticleUrl),
            ('', l10n.importArticleUrlRequired),
            (null, l10n.importClipboardUnavailable),
          ]) {
            expect(find.bySemanticsLabel(message), findsNothing);
            clipboardText = clipboard;
            readClipboard = clipboard == null
                ? () async => throw PlatformException(code: 'clipboard-denied')
                : null;
            if (clipboard == '') {
              await tester.enterText(field, '');
              tester.widget<TextField>(field).onSubmitted!('');
            } else {
              await tester.tap(paste);
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(geometry(), before, reason: 'during the error animation');
            await tester.pumpAndSettle();
            expect(find.text(message), findsOneWidget);
            expect(find.bySemanticsLabel(message), findsOneWidget);
            expect(geometry(), before, reason: 'after showing the error');
            await tester.enterText(
              field,
              'https://example.com/article-${edits++}',
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(geometry(), before, reason: 'while clearing the error');
            await tester.pumpAndSettle();
            expect(find.text(message), findsNothing);
            expect(find.bySemanticsLabel(message), findsNothing);
            expect(geometry(), before, reason: 'after clearing the error');
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  for (final action in ['book', 'article']) {
    testWidgets('$action menu row responds beyond its label', (tester) async {
      var pickerCalls = 0;
      await tester.pumpWidget(
        _TestHost(
          onOpen: (context) => showImportFlowSheet(
            context,
            onPickBookFile: () async {
              pickerCalls++;
              return null;
            },
            onImportBook: (_, {onProgress}) async => null,
            onImportArticle: (_, {onStage}) async => null,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('importMenu-$action'));
      final rect = tester.getRect(row);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThan(250));
      await tester.tapAt(rect.topRight + const Offset(-2, 2));
      await tester.pumpAndSettle();
      if (action == 'book') {
        expect(pickerCalls, 1);
        expect(find.text('Add to Library'), findsOneWidget);
      } else {
        expect(find.byType(TextField), findsOneWidget);
        expect(pickerCalls, 0);
      }
    });
  }

  for (final locale in [
    const Locale('en'),
    const Locale('ru'),
    const Locale('ar'),
  ]) {
    testWidgets(
      'article hints account for validation space above and breathing room below: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late ReadflexLocalizations l10n;
        await tester.pumpWidget(
          _TestHost(
            locale: locale,
            onOpen: (context) {
              l10n = context.l10n;
              return showImportFlowSheet(
                context,
                onPickBookFile: () async => null,
                onImportBook: (_, {onProgress}) async => null,
                onImportArticle: (_, {onStage}) async => null,
              );
            },
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final sheet = tester.getRect(find.byType(BottomSheet));
        await tester.tap(find.text(l10n.importSaveArticle));
        await tester.pumpAndSettle();

        final field = tester.getRect(find.byType(TextField));
        final firstHint = tester.getRect(
          find.text(l10n.importArticleHintClean),
        );
        // The test font wraps more than the app font. Hints may scroll while
        // the footer stays fixed, but the last hint must remain reachable.
        await tester.ensureVisible(find.text(l10n.importArticleHintLibrary));
        await tester.pumpAndSettle();
        final lastHint = tester.getRect(
          find.text(l10n.importArticleHintLibrary),
        );
        final save = tester.getRect(
          find.widgetWithText(FilledButton, l10n.commonSave),
        );
        final above = firstHint.top - field.bottom;
        final below = save.top - lastHint.bottom;
        // TextField includes validation space; separate feedback from hints.
        expect(above, greaterThanOrEqualTo(AppSpacing.sm));
        expect(below, greaterThanOrEqualTo(AppSpacing.sm));
        expect(tester.getRect(find.byType(BottomSheet)), sheet);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'menu balances its free space without resizing steps: $locale',
      (tester) async {
        late ReadflexLocalizations l10n;
        await tester.pumpWidget(
          _TestHost(
            locale: locale,
            onOpen: (context) {
              l10n = context.l10n;
              return showImportFlowSheet(
                context,
                onPickBookFile: () async => null,
                onImportBook: (_, {onProgress}) async => null,
                onImportArticle: (_, {onStage}) async => null,
              );
            },
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final sheet = tester.getRect(find.byType(BottomSheet));
        final layout = tester.getRect(find.byType(ActionBottomSheetLayout));
        final header = tester.getRect(find.byType(BottomSheetHeader));
        final book = tester.getRect(
          find.byKey(const ValueKey('importMenu-book')),
        );
        final article = tester.getRect(
          find.byKey(const ValueKey('importMenu-article')),
        );
        final above = book.top - header.bottom - AppSpacing.sm;
        final below = layout.bottom - AppSpacing.lg - article.bottom;
        expect(below, closeTo(above, 1));
        expect(below, inInclusiveRange(0, AppSpacing.xl));
        expect(book.height, greaterThanOrEqualTo(88));
        expect(article.height, greaterThanOrEqualTo(88));
        await tester.tap(find.text(l10n.importSaveArticle));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(BottomSheet)), sheet);
        await tester.tap(find.byTooltip(l10n.commonBack));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(BottomSheet)), sheet);
        expect(
          tester.getRect(find.byKey(const ValueKey('importMenu-article'))),
          article,
        );
      },
    );
  }

  testWidgets(
    'RTL menu mirrors arrows and keeps close reachable at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late ReadflexLocalizations l10n;
      await tester.pumpWidget(
        _TestHost(
          locale: const Locale('ar'),
          textScaler: const TextScaler.linear(2),
          onOpen: (context) {
            l10n = context.l10n;
            return showImportFlowSheet(
              context,
              onPickBookFile: () async => null,
              onImportBook: (_, {onProgress}) async => null,
              onImportArticle: (_, {onStage}) async => null,
            );
          },
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.chevronLeft), findsNWidgets(2));
      expect(find.byIcon(AppIcons.chevronRight), findsNothing);
      final close = find.byTooltip(l10n.commonClose);
      final closeRect = tester.getRect(close);
      expect(closeRect.height, greaterThanOrEqualTo(48));
      final article = find.byKey(const ValueKey('importMenu-article'));
      await tester.ensureVisible(article);
      await tester.pumpAndSettle();
      expect(tester.getRect(close), closeRect);
      expect(close.hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(AppIcons.book)).dx,
        greaterThan(
          tester.getCenter(find.byIcon(AppIcons.chevronLeft).first).dx,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.text(l10n.importAddToLibraryTitle), findsNothing);
    },
  );

  testWidgets('offline menu disables article import action', (tester) async {
    var articleImportCalls = 0;
    var pickerCalls = 0;

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isOffline: true,
          onPickBookFile: () async {
            pickerCalls++;
            return null;
          },
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async {
            articleImportCalls += 1;
            return null;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final offlineIcon = tester.widget<Icon>(find.byIcon(AppIcons.offline));
    expect(offlineIcon.color, AppTheme.light().ext.warning);
    expect(find.byIcon(AppIcons.link), findsNothing);
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(find.byKey(const ValueKey('importMenu-article'))),
        matchesSemantics(
          label: 'Save Article',
          value: 'Needs an internet connection',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    } finally {
      semantics.dispose();
    }

    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsOneWidget);
    expect(
      find.text('Creates a clean article for offline reading.'),
      findsNothing,
    );
    expect(articleImportCalls, 0);
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();
    expect(pickerCalls, 1);
    expect(find.text('Add to Library'), findsOneWidget);
  });

  testWidgets('open menu reacts when connectivity comes back online', (
    tester,
  ) async {
    final isOfflineController = StreamController<bool>();
    addTearDown(isOfflineController.close);

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isOffline: true,
          isOfflineStream: isOfflineController.stream,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(find.byIcon(AppIcons.link), findsNothing);

    isOfflineController.add(false);
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(AppIcons.link), findsOneWidget);
    expect(find.byIcon(AppIcons.offline), findsNothing);

    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(
      find.text('Creates a clean article for offline reading.'),
      findsOneWidget,
    );
  });

  testWidgets('article url form disables save while offline', (tester) async {
    var articleImportCalls = 0;
    final isOfflineController = StreamController<bool>();
    addTearDown(isOfflineController.close);

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          isOfflineStream: isOfflineController.stream,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async {
            articleImportCalls += 1;
            return null;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final fieldBefore = tester.getRect(find.byType(TextField));
    isOfflineController.add(true);
    await tester.pump();
    await tester.pump();
    // The disabled Save is explained in the field's reserved helper slot,
    // muted (not an error) and without moving the field.
    final hint = find.text("You're offline");
    expect(hint, findsOneWidget);
    final context = tester.element(hint);
    expect(
      tester.widget<Text>(hint).style?.color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
    expect(tester.getRect(find.byType(TextField)), fieldBefore);
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(articleImportCalls, 0);

    isOfflineController.add(false);
    await tester.pump();
    await tester.pump();
    expect(hint, findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(articleImportCalls, 1);
  });

  testWidgets('article url form validates empty and invalid URL input', (
    tester,
  ) async {
    final importedUrls = <String>[];

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (url, {onStage}) async {
            importedUrls.add(url);
            return _fakeArticle(title: 'Saved article');
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
    expect(
      tester.widget<FilledButton>(saveButtonFinder).onPressed,
      isNull,
      reason: 'empty input should not be submittable from the button',
    );

    await tester.enterText(find.byType(TextField), 'oifwoeifwoeiwoie');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(saveButtonFinder).onPressed,
      isNull,
      reason: 'invalid URL input should not activate the Save button',
    );
    expect(importedUrls, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Enter a valid article URL'), findsOneWidget);
    expect(find.text('Save Article'), findsOneWidget);
    expect(find.text('Fetching article...'), findsNothing);

    await tester.enterText(find.byType(TextField), 'example.com/article');
    await tester.pump();
    expect(find.text('Enter a valid article URL'), findsNothing);

    await tester.tap(saveButtonFinder);
    await tester.pump();

    expect(importedUrls, ['https://example.com/article']);
  });

  testWidgets('header close dismisses the sheet', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Library'), findsNothing);
  });

  testWidgets('menu steps use slide transition', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pump();

    expect(find.byType(FractionalTranslation), findsWidgets);
    expect(find.text('Add to Library'), findsOneWidget);
    expect(find.text('Save Article'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('Add to Library'), findsNothing);
    expect(find.text('Save Article'), findsOneWidget);
  });

  testWidgets('article url entry shows import hints', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(
      find.text('Creates a clean article for offline reading.'),
      findsOneWidget,
    );
    expect(find.text('Keeps the original source link.'), findsOneWidget);
    expect(find.text('Adds it to your Library.'), findsOneWidget);
  });

  testWidgets('article url entry pastes a valid clipboard url', (
    tester,
  ) async {
    clipboardText = 'example.com/article';

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    final pasteButtonFinder = find.byIcon(AppIcons.paste);
    final pasteButton = tester.widget<AppPlainIconButton>(
      find.byKey(const ValueKey('articleUrlPasteButton')),
    );
    expect(pasteButton.tooltip, 'Paste URL');
    expect(
      pasteButton.color,
      tester.element(find.byType(TextField)).actionForeground,
    );
    final fieldRect = tester.getRect(find.byType(TextField));
    final pasteRect = tester.getRect(
      find.byKey(const ValueKey('articleUrlPasteButton')),
    );
    expect(pasteRect.center.dx, greaterThan(fieldRect.center.dx));
    expect(fieldRect.right - pasteRect.right, closeTo(0, 1));

    await tester.tap(pasteButtonFinder);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'https://example.com/article');
  });

  testWidgets('invalid paste shows an error without replacing the URL', (
    tester,
  ) async {
    clipboardText = 'just words';

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();

    expect(clipboardReadCount, 0);
    await tester.enterText(find.byType(TextField), 'https://example.com/keep');
    await tester.pump();

    expect(
      tester
          .widget<AppPlainIconButton>(
            find.byKey(const ValueKey('articleUrlPasteButton')),
          )
          .color,
      tester.element(find.byType(TextField)).actionForeground,
    );

    await tester.tap(find.byIcon(AppIcons.paste));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(clipboardReadCount, 1);
    expect(field.controller!.text, 'https://example.com/keep');
    expect(field.decoration!.error, isNotNull);
    expect(find.text('Enter a valid article URL'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/edited',
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.error,
      isNull,
    );
  });

  testWidgets('Edit link restores the failed URL and saves only on request', (
    tester,
  ) async {
    final urls = <String>[];
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (url, {onStage}) async {
            urls.add(url);
            return null;
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'example.com/article');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit link'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'https://example.com/article');
    expect(field.decoration!.error, isNull);
    expect(urls, ['https://example.com/article']);
    await tester.enterText(
      find.byType(TextField),
      'https://example.com/edited',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(urls, ['https://example.com/article', 'https://example.com/edited']);
  });

  testWidgets('book import has one indicator and reports real phases', (
    tester,
  ) async {
    final imported = Completer<Book?>();
    late void Function(double) reportProgress;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) {
            reportProgress = onProgress!;
            return imported.future;
          },
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Preparing book'), findsOneWidget);
    final bounds = tester.getRect(find.byType(BottomSheet));
    reportProgress(.45);
    await tester.pump();
    expect(find.text('Copying file'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    reportProgress(1);
    await tester.pump();
    expect(find.text('Finishing import'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(tester.getRect(find.byType(BottomSheet)), bounds);
    imported.complete(_fakeBook());
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'book progress label fits large text without shifting on progress',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final imported = Completer<Book?>();
      late void Function(double) reportProgress;
      await tester.pumpWidget(
        _TestHost(
          textScaler: const TextScaler.linear(2),
          onOpen: (context) => showImportFlowSheet(
            context,
            onPickBookFile: () async => File('/tmp/Test.epub'),
            onImportBook: (file, {onProgress}) {
              reportProgress = onProgress!;
              return imported.future;
            },
            onImportArticle: (_, {onStage}) async => null,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload Book'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final iconBefore = tester.getRect(
        find.byKey(const ValueKey('importFlowStatusIcon')),
      );
      reportProgress(0.45);
      await tester.pump();

      final label = tester.widget<Text>(find.text('45%'));
      final context = tester.element(find.text('45%'));
      final painter = TextPainter(
        text: TextSpan(text: label.data, style: label.style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      expect(
        tester.getSize(find.text('45%')).height,
        greaterThanOrEqualTo(painter.height),
      );
      painter.dispose();
      expect(
        tester.getRect(find.byKey(const ValueKey('importFlowStatusIcon'))),
        iconBefore,
      );
      expect(tester.takeException(), isNull);
      imported.complete(_fakeBook());
      await tester.pumpAndSettle();
    },
  );

  for (final invalidText in <String?>[null, '', 'words without a link']) {
    testWidgets(
      'empty or invalid clipboard reports an inline error: $invalidText',
      (tester) async {
        clipboardText = invalidText;
        await _openArticleForm(tester);
        await tester.tap(find.byIcon(AppIcons.paste));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, isEmpty);
        expect(field.decoration!.error, isNotNull);
        expect(find.text('Enter a valid article URL'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
              .onPressed,
          isNull,
        );
      },
    );
  }

  testWidgets('clipboard failure is recoverable without clearing typed text', (
    tester,
  ) async {
    await _openArticleForm(tester);
    await tester.enterText(find.byType(TextField), 'https://example.com/keep');
    await tester.pump();
    readClipboard = () async => throw PlatformException(code: 'unavailable');
    await tester.tap(find.byIcon(AppIcons.paste));
    await tester.pumpAndSettle();
    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'https://example.com/keep');
    expect(field.decoration!.error, isNotNull);
    expect(find.text("Couldn't paste link"), findsOneWidget);
    readClipboard = () async => {'text': 'example.com/new'};
    await tester.tap(find.byIcon(AppIcons.paste));
    await tester.pumpAndSettle();
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'https://example.com/new');
    expect(
      field.controller!.selection,
      TextSelection.collapsed(offset: field.controller!.text.length),
    );
    expect(field.decoration!.error, isNull);
  });

  for (final reply in ['example.com/stale', 'not a link']) {
    testWidgets(
      'late clipboard reply does not overwrite manual edits: $reply',
      (tester) async {
        final clipboard = Completer<Object?>();
        readClipboard = () => clipboard.future;
        await _openArticleForm(tester);
        await tester.tap(find.byIcon(AppIcons.paste));
        await tester.enterText(
          find.byType(TextField),
          'https://example.com/typed',
        );
        await tester.pump();
        clipboard.complete({'text': reply});
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, 'https://example.com/typed');
        expect(field.decoration!.error, isNull);
      },
    );
  }

  testWidgets('newer paste wins when clipboard replies arrive out of order', (
    tester,
  ) async {
    final first = Completer<Object?>();
    final second = Completer<Object?>();
    readClipboard = () =>
        clipboardReadCount == 1 ? first.future : second.future;
    await _openArticleForm(tester);
    await tester.tap(find.byIcon(AppIcons.paste));
    await tester.tap(find.byIcon(AppIcons.paste));
    second.complete({'text': 'example.com/new'});
    await tester.pumpAndSettle();
    first.complete({'text': 'example.com/old'});
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://example.com/new',
    );
  });

  testWidgets(
    'clipboard reply during Back transition does not reopen the form',
    (tester) async {
      final clipboard = Completer<Object?>();
      readClipboard = () => clipboard.future;
      await _openArticleForm(tester);
      await tester.tap(find.byIcon(AppIcons.paste));
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      clipboard.complete({'text': 'example.com/stale'});
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Save Article'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clipboard failure after closing the sheet is ignored', (
    tester,
  ) async {
    final clipboard = Completer<Object?>();
    readClipboard = () => clipboard.future;
    await _openArticleForm(tester);
    await tester.tap(find.byIcon(AppIcons.paste));
    Navigator.of(tester.element(find.byType(TextField))).pop();
    await tester.pumpAndSettle();
    clipboard.completeError(PlatformException(code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('article success fades between aligned status views', (
    tester,
  ) async {
    final importCompleter = Completer<Article?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) => importCompleter.future,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Fetching article...'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'https://example.com/a',
      ),
      findsOneWidget,
    );
    final uploadingTitleTop = tester
        .getTopLeft(
          find.text('Fetching article...'),
        )
        .dy;

    importCompleter.complete(_fakeArticle(title: 'Saved article'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('importFlowStatusTransition')),
      findsWidgets,
    );

    await tester.pumpAndSettle();

    expect(find.text('Article saved!'), findsOneWidget);
    expect(find.text('Saved article'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Article saved!')).dy,
      closeTo(uploadingTitleTop, 1),
    );
  });

  testWidgets('article upload in flight ignores scrim, drag and Back', (
    tester,
  ) async {
    final articleImportCompleter = Completer<Article?>();
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) => articleImportCompleter.future,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // Guard changes publish after the frame.
    await tester.pump();

    await tester.tapAt(const Offset(10, 20));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('importFlowStatusIcon')),
      const Offset(0, 400),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(BottomSheet), findsOneWidget);

    articleImportCompleter.complete(_fakeArticle(title: 'Saved article'));
    await tester.pumpAndSettle();
    // Done step: dismissal works again.
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('book upload status icon matches article upload position', (
    tester,
  ) async {
    final articleImportCompleter = Completer<Article?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) => articleImportCompleter.future,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final articleIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );

    articleImportCompleter.complete(_fakeArticle(title: 'Saved article'));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final bookImportCompleter = Completer<Book?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) => bookImportCompleter.future,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final bookIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );

    expect(bookIconRect.size, equals(articleIconRect.size));
    expect(bookIconRect.center.dx, closeTo(articleIconRect.center.dx, 0.1));
    expect(bookIconRect.center.dy, closeTo(articleIconRect.center.dy, 0.1));
  });

  testWidgets('book upload requires accepting terms before file picker', (
    tester,
  ) async {
    var accepted = false;
    var acceptCalls = 0;
    var pickerCalls = 0;
    var termsCalls = 0;
    var privacyCalls = 0;

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async {
            pickerCalls += 1;
            return null;
          },
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
          isBookImportTermsAccepted: () => accepted,
          acceptBookImportTerms: () async {
            acceptCalls += 1;
            accepted = true;
          },
          onOpenTerms: () async => termsCalls += 1,
          onOpenPrivacy: () async => privacyCalls += 1,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Before uploading'), findsOneWidget);
    expect(
      find.text(
        'Only upload books, comics, and documents you have the right to use in ReadFlex.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('I confirm I have the right to upload this file.'),
      findsOneWidget,
    );
    expect(find.textRange.ofSubstring('Terms'), findsOne);
    expect(find.textRange.ofSubstring('Privacy Policy'), findsOne);
    expect(pickerCalls, 0);

    var continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);

    final legalText = find.byKey(const ValueKey('importFlowLegalText'));
    await tester.ensureVisible(legalText);
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring('Terms'));
    await Scrollable.ensureVisible(tester.element(legalText), alignment: 1);
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    expect(termsCalls, 1);
    expect(privacyCalls, 1);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox).hitTestable(), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(acceptCalls, 1);
    expect(pickerCalls, 1);
    expect(accepted, isTrue);
    expect(find.text('Add to Library'), findsOneWidget);
  });

  testWidgets('cancelled book picker keeps menu open', (tester) async {
    var pickerCalls = 0;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async {
            pickerCalls += 1;
            return null;
          },
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(find.text('Add to Library'), findsOneWidget);
  });

  testWidgets('successful book import shows Done success card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) async {
            onProgress?.call(0.5);
            onProgress?.call(1.0);
            return _fakeBook();
          },
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Book added!'), findsOneWidget);
    expect(find.text('Test.epub'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('book success fades between aligned status views', (
    tester,
  ) async {
    final importCompleter = Completer<Book?>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Test.epub'),
          onImportBook: (file, {onProgress}) => importCompleter.future,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Adding book'), findsOneWidget);
    expect(find.text('Test.epub'), findsOneWidget);
    final uploadingIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );
    expect(uploadingIconRect.size, equals(const Size(56, 56)));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    importCompleter.complete(_fakeBook());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('importFlowStatusTransition')),
      findsWidgets,
    );

    await tester.pumpAndSettle();

    expect(find.text('Book added!'), findsOneWidget);
    expect(find.text('Test.epub'), findsOneWidget);

    final successIconRect = tester.getRect(
      find.byKey(const ValueKey('importFlowStatusIcon')),
    );
    expect(successIconRect.size, equals(uploadingIconRect.size));
    expect(
      successIconRect.center.dx,
      closeTo(uploadingIconRect.center.dx, 0.1),
    );
    expect(
      successIconRect.center.dy,
      closeTo(uploadingIconRect.center.dy, 0.1),
    );
  });

  testWidgets('successful comic import shows Comic added!', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Strip.cbz'),
          onImportBook: (file, {onProgress}) async => _fakeBook(
            format: BookFormat.cbz,
          ),
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Comic added!'), findsOneWidget);
    expect(find.text('Book added!'), findsNothing);
    expect(find.text('Strip.cbz'), findsOneWidget);
  });

  testWidgets('book import failure opens the picker with Choose file', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async =>
              ++picks == 1 ? File('/tmp/Bad.epub') : null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to import the book'), findsOneWidget);
    expect(find.text('Bad.epub'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(picks, 2);
    expect(find.text('Failed to import the book'), findsOneWidget);
  });

  testWidgets('book failure fades between aligned status views', (
    tester,
  ) async {
    final failureCompleter = Completer<void>();

    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => File('/tmp/Bad.epub'),
          onImportBook: (file, {onProgress}) async {
            await failureCompleter.future;
            throw const BookImportException('File type not supported');
          },
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();

    expect(find.text('Adding book'), findsOneWidget);
    expect(find.text('Bad.epub'), findsOneWidget);

    failureCompleter.complete();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('importFlowStatusTransition')),
      findsWidgets,
    );

    await tester.pumpAndSettle();

    expect(find.text('File type not supported'), findsOneWidget);
    expect(find.text('Bad.epub'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
  });

  testWidgets('paste is the shared 48dp utility action with a tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Article'));
    await tester.pumpAndSettle();
    final paste = find.byKey(const ValueKey('articleUrlPasteButton'));
    expect(tester.widget(paste), isA<AppPlainIconButton>());
    expect(tester.getSize(paste), const Size(48, 48));
    expect(find.byTooltip('Paste URL'), findsOneWidget);
    final style = tester
        .widget<IconButton>(
          find.descendant(of: paste, matching: find.byType(IconButton)),
        )
        .style!;
    expect(style.shape!.resolve({}), const CircleBorder());
  });

  testWidgets('menu rows are shared drill-in rows', (tester) async {
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) => showImportFlowSheet(
          context,
          onPickBookFile: () async => null,
          onImportBook: (file, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDrillInRow), findsNWidgets(2));
  });

  testWidgets('status steps keep the flow header and gate Close on work', (
    tester,
  ) async {
    final imported = Completer<Book?>();
    ImportFlowResult? result;
    var completed = false;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) async {
          result = await showImportFlowSheet(
            context,
            onPickBookFile: () async => File('/tmp/Test.epub'),
            onImportBook: (file, {onProgress}) => imported.future,
            onImportArticle: (_, {onStage}) async => null,
          );
          completed = true;
        },
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final menuSheet = tester.getRect(find.byType(BottomSheet));
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    IconButton closeButton() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(AppIcons.close),
        matching: find.byType(IconButton),
      ),
    );
    expect(find.text('Adding book'), findsOneWidget);
    expect(find.byType(BottomSheetHeader), findsOneWidget);
    expect(find.text('Add to Library'), findsOneWidget);
    expect(closeButton().onPressed, isNull);
    expect(
      tester.getRect(find.byType(BottomSheet)).height,
      closeTo(menuSheet.height + AppSizes.buttonHeight + AppSpacing.sm, 1),
    );

    imported.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Choose file'), findsOneWidget);
    expect(closeButton().onPressed, isNotNull);
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('done step enables Close without reporting an import', (
    tester,
  ) async {
    final imported = Completer<Book?>();
    ImportFlowResult? result;
    await tester.pumpWidget(
      _TestHost(
        onOpen: (context) async {
          result = await showImportFlowSheet(
            context,
            onPickBookFile: () async => File('/tmp/Test.epub'),
            onImportBook: (file, {onProgress}) => imported.future,
            onImportArticle: (_, {onStage}) async => null,
          );
        },
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Book'));
    await tester.pump();
    imported.complete(_fakeBook());
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    final close = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(AppIcons.close),
        matching: find.byType(IconButton),
      ),
    );
    expect(close.onPressed, isNotNull);
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(result, isNull);
  });

  Future<void> openDraftForm(WidgetTester tester) async {
    await _openArticleForm(tester);
    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    tester.testTextInput.hide();
    // The dismiss guard publishes after the frame.
    await tester.pumpAndSettle();
  }

  Finder sheetDragHandle() => find.byWidgetPredicate(
    (w) => w is Container && w.constraints?.maxWidth == 32,
  );

  for (final method in ['close', 'scrim']) {
    testWidgets('typed URL: $method asks to discard; Discard closes', (
      tester,
    ) async {
      await openDraftForm(tester);
      expect(sheetDragHandle(), findsNothing);
      if (method == 'close') {
        await tester.tap(find.byTooltip('Close'));
      } else {
        await tester.tapAt(const Offset(10, 20));
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final discard = find.widgetWithText(OutlinedButton, 'Discard');
      final style = tester.widget<OutlinedButton>(discard).style!;
      expect(
        style.foregroundColor!.resolve({}),
        Theme.of(tester.element(discard)).colorScheme.error,
      );
      expect(
        find.widgetWithText(FilledButton, 'Keep editing'),
        findsOneWidget,
      );
      // Repeated Close keeps the decision visible.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('typed URL: Keep editing restores the form and its draft', (
    tester,
  ) async {
    await openDraftForm(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(
      find.widgetWithText(TextField, 'https://example.com/a'),
      findsOneWidget,
    );
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    // Header Back from the decision does the same.
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'https://example.com/a'),
      findsOneWidget,
    );
  });

  testWidgets('typed URL: drag-down is swallowed and the draft survives', (
    tester,
  ) async {
    await openDraftForm(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.dragFrom(
      Offset(sheet.center.dx, sheet.top + 10),
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)), sheet);
    expect(
      find.widgetWithText(TextField, 'https://example.com/a'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed URL: system Back from the decision keeps the draft', (
    tester,
  ) async {
    await openDraftForm(tester);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(
      find.widgetWithText(TextField, 'https://example.com/a'),
      findsOneWidget,
    );
    // From the form, system Back is a step back; the cubit keeps the URL.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Add to Library'), findsOneWidget);
    expect(sheetDragHandle(), findsOneWidget);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('empty URL form still closes on scrim and keeps its handle', (
    tester,
  ) async {
    await _openArticleForm(tester);
    await tester.pumpAndSettle();
    expect(sheetDragHandle(), findsOneWidget);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}

Future<void> _openArticleForm(WidgetTester tester) async {
  await tester.pumpWidget(
    _TestHost(
      onOpen: (context) => showImportFlowSheet(
        context,
        onPickBookFile: () async => null,
        onImportBook: (file, {onProgress}) async => null,
        onImportArticle: (_, {onStage}) async => null,
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save Article'));
  await tester.pumpAndSettle();
}

Book _fakeBook({BookFormat format = BookFormat.epub}) => Book(
  id: 'book-1',
  title: 'Test',
  filePath: 'book.epub',
  format: format,
  addedAt: DateTime(2026),
);

Article _fakeArticle({String title = 'Article'}) => Article(
  id: 'article-1',
  title: title,
  url: 'https://example.com/a',
  contentPath: '/articles/article-1/article.json',
  addedAt: DateTime(2026),
);

class _TestHost extends StatefulWidget {
  const _TestHost({
    required this.onOpen,
    this.textScaler = TextScaler.noScaling,
    this.locale = const Locale('en'),
    this.reducedMotion = false,
  });

  final Future<void> Function(BuildContext context) onOpen;
  final TextScaler textScaler;
  final Locale locale;
  final bool reducedMotion;

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      locale: widget.locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: widget.textScaler,
          disableAnimations: widget.reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => widget.onOpen(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}
