import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

import '../packages/features/reader/test/helpers/fake_book_repository.dart';
import '../packages/features/reader/test/helpers/fake_highlight_repository.dart';
import 'support/reader_test_platform.dart';

void main() {
  for (final outcome in ['loading', 'failed', 'complete']) {
    testWidgets(
      'closing reader persists only settled initial position ($outcome)',
      (tester) async {
        final previous = InAppWebViewPlatform.instance;
        final platform = ReaderTestPlatform();
        InAppWebViewPlatform.instance = platform;
        addTearDown(() {
          if (previous != null) InAppWebViewPlatform.instance = previous;
        });
        final saved = Book(
          id: 'restoring-book',
          title: 'Restoring book',
          filePath: '/books/a.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
          currentCfi: 'epubcfi(/6/32!/4/12/1:1125)',
          readingProgress: 0.47,
        );
        final repository = FakeBookRepository()..seedBook(saved);
        final bloc = ReaderBloc(
          bookRepository: repository,
          highlightRepository: FakeHighlightRepository(),
          initialSource: saved,
        );
        addTearDown(() => tester.runAsync(bloc.close));
        await tester.pumpWidget(
          MaterialApp(
            home: BookReaderWebView(
              serverBaseUri: Uri.parse('http://127.0.0.1:1234/r/token/'),
              bookFilePath: saved.filePath,
              initialCfi: saved.currentCfi,
              initialProgress: saved.readingProgress,
              onPositionChanged: (position) => bloc.add(
                ReaderBookPositionUpdated(
                  cfi: position.cfi,
                  progress: position.fraction,
                ),
              ),
            ),
          ),
        );
        final handlers = platform.views.single.controller.handlers;
        handlers['onRelocated']!([
          {'cfi': 'epubcfi(/6/32!/4/2/1:0)', 'percentage': 0.43},
        ]);
        await tester.pump(const Duration(seconds: 1));
        expect(repository.updateCallCount, 0);
        if (outcome == 'failed') {
          handlers['onReaderLoadFailed']!([]);
          handlers['onLoadEnd']!([]);
          await tester.pump();
          expect(repository.updateCallCount, 0);
        } else if (outcome == 'complete') {
          handlers['onRelocated']!([
            {'cfi': saved.currentCfi, 'percentage': saved.readingProgress},
          ]);
          handlers['onLoadEnd']!([]);
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(bloc.close);
        expect(repository.books.single.currentCfi, saved.currentCfi);
        expect(repository.books.single.readingProgress, saved.readingProgress);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
