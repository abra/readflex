import 'dart:convert';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_comic_pages.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  final items = List.generate(
    500,
    (i) => ReaderTocItem(label: 'file-$i.jpg', href: '$i', level: 0),
  );
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('pages are lazy and reveal current page: $locale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <int>[];
        ReaderTocItem? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: ReaderComicPages(
                items: items,
                currentIndex: 246,
                pageProgressionRtl: locale.languageCode == 'en',
                loadThumbnail: (index) async {
                  requests.add(index);
                  return bytes;
                },
                onSelected: (item) => selected = item,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ReaderComicPages));
        final label = context.l10n.readerPageNumber(247);
        expect(find.text(label).hitTestable(), findsOneWidget);
        expect(requests.length, lessThan(10));
        expect(requests.every((index) => index >= 246 && index < 256), isTrue);
        if (scale == 1) {
          final next = context.l10n.readerPageNumber(248);
          final left = tester.getCenter(find.text(label)).dx;
          final right = tester.getCenter(find.text(next)).dx;
          expect(
            left > right,
            locale.languageCode == 'en',
            reason:
                'Page order follows the book, independently of the app locale',
          );
        }
        await tester.tap(find.text(label));
        expect(selected, items[246]);
        expect(find.text('file-246.jpg'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('an asynchronously loaded TOC still reveals the saved page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final toc = ValueNotifier<List<ReaderTocItem>>([]);
    addTearDown(toc.dispose);
    final requests = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ValueListenableBuilder<List<ReaderTocItem>>(
            valueListenable: toc,
            builder: (_, pages, _) => ReaderComicPages(
              items: pages,
              currentIndex: 246,
              onSelected: (_) {},
              loadThumbnail: (index) async {
                requests.add(index);
                return bytes;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    toc.value = items;
    await tester.pumpAndSettle();
    expect(find.text('Page 247').hitTestable(), findsOneWidget);
    expect(requests.every((index) => index >= 246 && index < 256), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
