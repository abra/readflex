import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_external_link_prompt.dart';
import 'package:reader/src/reader_external_link_sheet.dart';
import 'package:toast_service/toast_service.dart';

/// A link leaves the reader only through the link sheet: Open hands it to the
/// host, Copy copies it, anything else keeps the reader where it is.
void main() {
  const wiki = 'https://en.wikipedia.org/wiki/Lewis_and_Clark_Expedition';

  late List<String> opened;
  late List<String?> clipboard;
  late bool clipboardFails;
  ValueChanged<String>? report;

  setUp(() {
    opened = [];
    clipboard = [];
    clipboardFails = false;
    report = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardFails) {
              throw PlatformException(code: 'unavailable');
            }
            clipboard.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpPrompt(
    WidgetTester tester, {
    bool canOpen = true,
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ToastWrapper(
        child: MaterialApp(
          locale: locale,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ReaderExternalLinkPrompt(
              onOpen: canOpen ? opened.add : null,
              builder: (context, onExternalLink) {
                report = onExternalLink;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapLink(WidgetTester tester, String url) async {
    report!(url);
    await tester.pumpAndSettle();
  }

  Finder sheet() => find.byType(ReaderExternalLinkSheet);

  testWidgets('a link opens only after Open, exactly as reported', (
    tester,
  ) async {
    await pumpPrompt(tester);
    const url = 'https://ru.wikipedia.org/wiki/%D0%AD%D0%BA%D1%81';
    await tapLink(tester, url);
    expect(sheet(), findsOneWidget);
    expect(find.text('Open link?'), findsOneWidget);
    expect(find.text('ru.wikipedia.org'), findsOneWidget);
    expect(find.text('https://ru.wikipedia.org/wiki/Экс'), findsOneWidget);
    expect(opened, isEmpty);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, [url]);
    expect(sheet(), findsNothing);
    expect(clipboard, isEmpty);
  });

  testWidgets('closing, the scrim and Back keep the reader in place', (
    tester,
  ) async {
    await pumpPrompt(tester);
    await tapLink(tester, wiki);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(sheet(), findsNothing);

    await tapLink(tester, wiki);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(sheet(), findsNothing);

    await tapLink(tester, wiki);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(sheet(), findsNothing);
    expect(opened, isEmpty);
    expect(clipboard, isEmpty);
  });

  testWidgets('Copy link copies the link without opening it', (tester) async {
    await pumpPrompt(tester);
    await tapLink(tester, wiki);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(clipboard, [wiki]);
    expect(opened, isEmpty);
    expect(sheet(), findsNothing);
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(toastSuccessDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed copy says so', (tester) async {
    clipboardFails = true;
    await pumpPrompt(tester);
    await tapLink(tester, wiki);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(find.text('Could not copy'), findsOneWidget);
    expect(opened, isEmpty);
    await tester.pump(toastErrorDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('a second link while the sheet is open is dropped', (
    tester,
  ) async {
    await pumpPrompt(tester);
    report!(wiki);
    report!('https://example.com/other');
    await tester.pumpAndSettle();
    expect(sheet(), findsOneWidget);
    expect(find.text('en.wikipedia.org'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    // Once it closes, the next link asks again.
    await tapLink(tester, 'https://example.com/other');
    expect(find.text('example.com'), findsOneWidget);
  });

  testWidgets('email links ask too and open through the host', (
    tester,
  ) async {
    await pumpPrompt(tester);
    await tapLink(tester, 'mailto:editor@river.example');
    expect(find.text('editor@river.example'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, ['mailto:editor@river.example']);
  });

  testWidgets('links the reader does not open show nothing', (tester) async {
    await pumpPrompt(tester);
    for (final url in ['javascript:alert(1)', 'file:///etc/hosts', '']) {
      await tapLink(tester, url);
      expect(sheet(), findsNothing, reason: url);
    }
  });

  testWidgets('without a host to open links the page gets no callback', (
    tester,
  ) async {
    await pumpPrompt(tester, canOpen: false);
    expect(report, isNull);
  });

  testWidgets('the address reads left to right in an RTL interface', (
    tester,
  ) async {
    await pumpPrompt(tester, locale: const Locale('ar'));
    await tapLink(
      tester,
      'https://ar.wikipedia.org/wiki/%D8%A8%D8%B9%D8%AB%D8%A9',
    );
    final title = tester.getRect(find.text('فتح الرابط؟'));
    final target = tester.getRect(
      find.byKey(const ValueKey('reader-external-link-target')),
    );
    final address = tester.getRect(
      find.byKey(const ValueKey('reader-external-link-address')),
    );
    // The heading follows the interface; the address keeps its own start.
    expect(title.right, 390 - AppSpacing.xl);
    expect(target.left, AppSpacing.xl);
    expect(address.left, AppSpacing.xl);
    expect(
      tester
          .renderObject<RenderParagraph>(
            find.byKey(const ValueKey('reader-external-link-target')),
          )
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('the target is never shortened; the address stops at three '
      'lines', (tester) async {
    await pumpPrompt(tester);
    const long =
        'https://login.secure-account-verify.example.net/session/redirect'
        '?continue=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FLewis_and_Clark'
        '&utm_source=ebook&utm_medium=footnote&utm_campaign=river-2026';
    await tapLink(tester, long);
    final target = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('reader-external-link-target')),
    );
    final address = tester.widget<Text>(
      find.byKey(const ValueKey('reader-external-link-address')),
    );
    expect(target.didExceedMaxLines, isFalse);
    expect(
      target.text.toPlainText(),
      'login.secure-account-verify.example.net',
    );
    expect(address.maxLines, 3);
    expect(address.overflow, TextOverflow.ellipsis);
  });

  testWidgets('large text on a small phone keeps both actions reachable', (
    tester,
  ) async {
    await pumpPrompt(
      tester,
      locale: const Locale('de'),
      size: const Size(320, 568),
      scale: 2,
    );
    await tapLink(tester, 'https://de.wikipedia.org/wiki/Lewis-und-Clark');
    for (final label in ['Öffnen', 'Link kopieren']) {
      await tester.ensureVisible(find.text(label));
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    expect(opened, ['https://de.wikipedia.org/wiki/Lewis-und-Clark']);
  });

  testWidgets('the sheet announces a heading and named buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPrompt(tester);
    await tapLink(tester, wiki);
    expect(
      tester.getSemantics(find.text('Open link?')).flagsCollection.isHeader,
      isTrue,
    );
    for (final label in ['Open', 'Copy link']) {
      expect(
        find.semantics.byLabel(label),
        findsOneWidget,
        reason: label,
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
