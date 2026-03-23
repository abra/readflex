import 'package:bloc_test/bloc_test.dart';
import 'package:dictionary/src/dictionary_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_dictionary_repository.dart';

final _entry1 = DictionaryEntry(
  id: '1',
  word: 'hello',
  translation: 'привет',
  addedAt: DateTime(2026, 1, 1),
);

final _entry2 = DictionaryEntry(
  id: '2',
  word: 'world',
  translation: 'мир',
  addedAt: DateTime(2026, 1, 2),
);

void main() {
  group('DictionaryBloc', () {
    late FakeDictionaryRepository repository;

    setUp(() {
      repository = FakeDictionaryRepository();
    });

    blocTest<DictionaryBloc, DictionaryState>(
      'emits loading then success with entries',
      setUp: () => repository.seed([_entry1, _entry2]),
      build: () => DictionaryBloc(dictionaryRepository: repository),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      expect: () => [
        const DictionaryState(status: DictionaryStatus.loading),
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
          filteredEntries: [_entry1, _entry2],
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'emits success with empty list when no entries',
      build: () => DictionaryBloc(dictionaryRepository: repository),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      expect: () => [
        const DictionaryState(status: DictionaryStatus.loading),
        const DictionaryState(status: DictionaryStatus.success),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => DictionaryBloc(dictionaryRepository: repository),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      expect: () => [
        const DictionaryState(status: DictionaryStatus.loading),
        const DictionaryState(status: DictionaryStatus.failure),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'search filters entries by query',
      build: () => DictionaryBloc(dictionaryRepository: repository),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
        filteredEntries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(const DictionarySearchChanged('hello')),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
          filteredEntries: [_entry1],
          searchQuery: 'hello',
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'search by translation also works',
      build: () => DictionaryBloc(dictionaryRepository: repository),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
        filteredEntries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(const DictionarySearchChanged('мир')),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
          filteredEntries: [_entry2],
          searchQuery: 'мир',
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'delete entry removes it and reloads',
      setUp: () => repository.seed([_entry1, _entry2]),
      build: () => DictionaryBloc(dictionaryRepository: repository),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(DictionaryEntryDeleted(_entry1.id)),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry2],
          filteredEntries: [_entry2],
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'delete emits failure when repository throws',
      setUp: () {
        repository.seed([_entry1]);
        repository.shouldThrow = true;
      },
      build: () => DictionaryBloc(dictionaryRepository: repository),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1],
      ),
      act: (bloc) => bloc.add(DictionaryEntryDeleted(_entry1.id)),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.failure,
          entries: [_entry1],
        ),
      ],
    );
  });

  group('DictionaryState', () {
    test('isEmpty is true when no entries', () {
      const state = DictionaryState();
      expect(state.isEmpty, isTrue);
    });

    test('filteredEntries returns all when query is empty', () {
      final state = DictionaryState(
        entries: [_entry1, _entry2],
        filteredEntries: [_entry1, _entry2],
      );
      expect(state.filteredEntries, hasLength(2));
    });
  });
}
