import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:reader_webview/reader_webview.dart';

/// Cubit tests. Fakes record callback invocations so we assert state
/// transitions without touching the real file picker or repository.
void main() {
  group('ImportFlowCubit', () {
    blocTest<ImportFlowCubit, ImportFlowState>(
      'starts in menu',
      build: _buildCubit,
      verify: (cubit) => expect(cubit.state, isA<ImportFlowMenu>()),
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'cancelled file picker keeps cubit in menu',
      build: () => _buildCubit(pickBookFile: () async => null),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => <ImportFlowState>[],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'book import emits indeterminate uploading then progress, then done',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/test/My Book.epub'),
        importBook: (file, {onProgress}) async {
          onProgress?.call(0.0);
          onProgress?.call(0.5);
          onProgress?.call(1.0);
          return _fakeBook();
        },
      ),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => [
        const ImportFlowBookUploading(filename: 'My Book.epub'),
        const ImportFlowBookUploading(filename: 'My Book.epub', progress: 0.0),
        const ImportFlowBookUploading(filename: 'My Book.epub', progress: 0.5),
        const ImportFlowBookUploading(filename: 'My Book.epub', progress: 1.0),
        const ImportFlowBookDone(
          filename: 'My Book.epub',
          format: BookFormat.epub,
        ),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'comic import propagates cbz format into the done state',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/Strip.cbz'),
        importBook: (file, {onProgress}) async => _fakeBook(
          format: BookFormat.cbz,
        ),
      ),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => [
        const ImportFlowBookUploading(filename: 'Strip.cbz'),
        const ImportFlowBookDone(
          filename: 'Strip.cbz',
          format: BookFormat.cbz,
        ),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'book import emits failure when callback returns null',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/x.epub'),
        importBook: (file, {onProgress}) async => null,
      ),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => [
        const ImportFlowBookUploading(filename: 'x.epub'),
        const ImportFlowFailure(
          message: 'Failed to import the book',
          filename: 'x.epub',
        ),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'book import emits failure when callback throws',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/x.epub'),
        importBook: (file, {onProgress}) async => throw Exception('boom'),
      ),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => [
        const ImportFlowBookUploading(filename: 'x.epub'),
        const ImportFlowFailure(
          message: 'Failed to import the book',
          filename: 'x.epub',
        ),
      ],
    );

    // BookImportException carries the JS-side reason ("File type not
    // supported", etc.) — the failure UI should surface that instead of
    // the generic "Failed to import the book" string.
    blocTest<ImportFlowCubit, ImportFlowState>(
      'book import surfaces BookImportException.message in failure state',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/junk.epub'),
        importBook: (file, {onProgress}) async {
          throw const BookImportException('File type not supported');
        },
      ),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => [
        const ImportFlowBookUploading(filename: 'junk.epub'),
        const ImportFlowFailure(
          message: 'File type not supported',
          filename: 'junk.epub',
        ),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'backToMenu resets from any state',
      build: _buildCubit,
      seed: () => const ImportFlowFailure(message: 'Failed to import the book'),
      act: (cubit) => cubit.backToMenu(),
      expect: () => [const ImportFlowMenu()],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'article import emits URL entry, uploading, then done',
      build: () => _buildCubit(
        importArticle: (url) async => _fakeArticle(title: 'Saved article'),
      ),
      act: (cubit) async {
        cubit.showArticleUrlEntry();
        await cubit.importArticle('https://example.com/article');
      },
      expect: () => [
        const ImportFlowArticleUrlEntry(),
        const ImportFlowArticleUploading(url: 'https://example.com/article'),
        const ImportFlowArticleDone(title: 'Saved article'),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'article import accepts pasted domain without scheme',
      build: () => _buildCubit(
        importArticle: (url) async {
          expect(url, 'https://habr.com/ru/articles/1029802/');
          return _fakeArticle(title: 'Saved article');
        },
      ),
      act: (cubit) => cubit.importArticle('habr.com/ru/articles/1029802/'),
      expect: () => [
        const ImportFlowArticleUploading(
          url: 'https://habr.com/ru/articles/1029802/',
        ),
        const ImportFlowArticleDone(title: 'Saved article'),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'article import rejects invalid URLs without calling import callback',
      build: () => _buildCubit(
        importArticle: (_) async => throw StateError('should not be called'),
      ),
      act: (cubit) => cubit.importArticle('not a url'),
      expect: () => [
        const ImportFlowFailure(
          message: 'Enter a valid article URL',
          retryTarget: ImportFlowRetryTarget.article,
        ),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'article import surfaces ArticleImportException.message in failure state',
      build: () => _buildCubit(
        importArticle: (_) async {
          throw const ArticleImportException(
            'Could not extract article content',
          );
        },
      ),
      act: (cubit) => cubit.importArticle('https://example.com/article'),
      expect: () => [
        const ImportFlowArticleUploading(url: 'https://example.com/article'),
        const ImportFlowFailure(
          message: 'Could not extract article content',
          filename: 'https://example.com/article',
          retryTarget: ImportFlowRetryTarget.article,
        ),
      ],
    );

    // "Try again" on the failure screen wires straight to
    // pickAndImportBook (no detour through the menu). From an
    // ImportFlowFailure seed we expect the same uploading→done sequence
    // a fresh pick would produce.
    blocTest<ImportFlowCubit, ImportFlowState>(
      'pickAndImportBook from failure re-runs the import',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/retry.epub'),
        importBook: (file, {onProgress}) async => _fakeBook(),
      ),
      seed: () => const ImportFlowFailure(message: 'Failed to import the book'),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => [
        const ImportFlowBookUploading(filename: 'retry.epub'),
        const ImportFlowBookDone(
          filename: 'retry.epub',
          format: BookFormat.epub,
        ),
      ],
    );

    // If the user opens the picker from the failure screen and cancels,
    // the cubit should stay on the failure view — not silently bounce
    // back to the menu.
    blocTest<ImportFlowCubit, ImportFlowState>(
      'pickAndImportBook from failure stays on failure when picker cancels',
      build: () => _buildCubit(pickBookFile: () async => null),
      seed: () => const ImportFlowFailure(message: 'Failed to import the book'),
      act: (cubit) => cubit.pickAndImportBook(),
      expect: () => <ImportFlowState>[],
    );

    // The user can dismiss the bottom sheet (drag-down, scrim tap,
    // back gesture) at any time during a long byte-copy import. The
    // sheet's BlocProvider closes the cubit, but the in-flight future
    // resumes and tries to emit. Without isClosed guards we'd throw
    // "Cannot emit new states after calling close()" — once for each
    // onProgress callback and once for the final done/failure emit.
    test('emit calls after close() do not throw', () async {
      final importCompleter = Completer<Book?>();
      final progressFromCubit = <double>[];
      late void Function(double) capturedOnProgress;

      final cubit = ImportFlowCubit(
        onPickBookFile: () async => File('/tmp/in_progress.epub'),
        onImportBook: (file, {onProgress}) {
          capturedOnProgress = onProgress!;
          return importCompleter.future;
        },
        onImportArticle: (_) async => null,
      );

      // Kick off the import; it'll park awaiting the completer.
      final pendingPick = cubit.pickAndImportBook();
      // Yield so the cubit reaches the await on _onImportBook.
      await Future<void>.delayed(Duration.zero);

      // User dismisses the sheet — BlocProvider closes the cubit.
      await cubit.close();

      // Now simulate two things that would have raced before the fix:
      //   1. an onProgress callback firing through a chunk write
      //   2. the import resolving (success path)
      // Both used to call emit on a closed cubit and throw StateError.
      expect(
        () => capturedOnProgress(0.5),
        returnsNormally,
        reason: 'onProgress emit must be guarded by isClosed',
      );
      progressFromCubit.add(0.5);
      importCompleter.complete(_fakeBook());
      await pendingPick;
      // pickAndImportBook returns Future<void>; if anything threw,
      // awaiting it would propagate. Reaching this line means the
      // post-close emits no-op'd cleanly.
      expect(progressFromCubit, [0.5]);
    });

    test('emit calls after close() on the failure path do not throw', () async {
      final importCompleter = Completer<Book?>();
      final cubit = ImportFlowCubit(
        onPickBookFile: () async => File('/tmp/will_fail.epub'),
        onImportBook: (file, {onProgress}) => importCompleter.future,
        onImportArticle: (_) async => null,
      );
      final pending = cubit.pickAndImportBook();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      // Resolve the import as a failure (returns null).
      importCompleter.complete(null);
      // Awaiting the original call should not propagate StateError.
      await expectLater(pending, completes);
    });

    // Re-entry guard: double-tapping the menu's "Upload Book" tile
    // (or the failure screen's "Try again" button) used to launch two
    // platform pickers concurrently and race on cubit state when both
    // resolved. The flag in `pickAndImportBook` makes the second call
    // a no-op while the first picker is still open.
    test(
      'pickAndImportBook ignores re-entry while picker is in flight',
      () async {
        final pickerCompleter = Completer<File?>();
        var pickCount = 0;

        final cubit = _buildCubit(
          pickBookFile: () async {
            pickCount++;
            return pickerCompleter.future;
          },
        );

        // Fire two calls without awaiting between them.
        final first = cubit.pickAndImportBook();
        final second = cubit.pickAndImportBook();

        // Pump microtasks so the first call has actually entered
        // `_onPickBookFile`. Without this, both awaited futures could
        // synchronously bypass our flag.
        await Future<void>.delayed(Duration.zero);

        // Only one picker was opened — the second tap was rejected.
        expect(pickCount, 1);

        // User cancels (returns null). Both Futures should complete; the
        // cubit stays on the menu since nothing was selected.
        pickerCompleter.complete(null);
        await first;
        await second;
        expect(cubit.state, isA<ImportFlowMenu>());
        await cubit.close();
      },
    );

    // Chunked byte-copy on a large book can fire `onProgress` hundreds
    // of times per second; each emit re-renders the uploading view.
    // The cubit coalesces sub-1%-delta updates so the emit frequency
    // is bounded by visible progress, not by writer cadence.
    blocTest<ImportFlowCubit, ImportFlowState>(
      'coalesces sub-1% onProgress emits',
      build: () => _buildCubit(
        pickBookFile: () async => File('/tmp/big.epub'),
        importBook: (file, {onProgress}) async {
          // Fire 50 micro-progress steps in the [0.50, 0.504] band —
          // each step is 0.0001, well below the 1% threshold. Without
          // coalescing this floods 50+ emits.
          for (var i = 0; i <= 50; i++) {
            onProgress?.call(0.50 + i * 0.0001);
          }
          // End-of-copy 1.0 always passes through.
          onProgress?.call(1.0);
          return _fakeBook();
        },
      ),
      act: (cubit) => cubit.pickAndImportBook(),
      verify: (cubit) {
        expect(cubit.state, isA<ImportFlowBookDone>());
      },
      // Bound on emit count: 1 indeterminate uploading + a couple of
      // bucketed progress emits + done. Asserting ≤6 leaves room for
      // legitimate state changes but catches regressions where the 50-
      // step storm passes through unfiltered.
      expect: () => predicate<List<ImportFlowState>>(
        (states) => states.length <= 6,
        'emits ≤ 6 states (coalesces 50 sub-1% progress steps)',
      ),
    );
  });
}

ImportFlowCubit _buildCubit({
  PickBookFile? pickBookFile,
  ImportBookFile? importBook,
  ImportArticleUrl? importArticle,
}) {
  return ImportFlowCubit(
    onPickBookFile: pickBookFile ?? () async => null,
    onImportBook: importBook ?? (file, {onProgress}) async => null,
    onImportArticle: importArticle ?? (_) async => null,
  );
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
  url: 'https://example.com/article',
  contentPath: '/articles/article-1/article.json',
  addedAt: DateTime(2026),
);
