import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';

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
        const ImportFlowFailure(message: 'Failed to import the book'),
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
        const ImportFlowFailure(message: 'Failed to import the book'),
      ],
    );

    blocTest<ImportFlowCubit, ImportFlowState>(
      'backToMenu resets from any state',
      build: _buildCubit,
      seed: () => const ImportFlowFailure(message: 'Failed to import the book'),
      act: (cubit) => cubit.backToMenu(),
      expect: () => [const ImportFlowMenu()],
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
  });
}

ImportFlowCubit _buildCubit({
  PickBookFile? pickBookFile,
  ImportBookFile? importBook,
}) {
  return ImportFlowCubit(
    onPickBookFile: pickBookFile ?? () async => null,
    onImportBook: importBook ?? (file, {onProgress}) async => null,
  );
}

Book _fakeBook({BookFormat format = BookFormat.epub}) => Book(
  id: 'book-1',
  title: 'Test',
  filePath: 'book.epub',
  format: format,
  addedAt: DateTime(2026),
);
