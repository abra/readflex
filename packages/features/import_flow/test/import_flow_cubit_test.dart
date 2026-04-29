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
        const ImportFlowBookDone(filename: 'My Book.epub'),
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

Book _fakeBook() => Book(
  id: 'book-1',
  title: 'Test',
  filePath: 'book.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
);
