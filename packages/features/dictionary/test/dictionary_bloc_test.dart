import 'package:bloc_test/bloc_test.dart';
import 'package:dictionary/src/dictionary_bloc.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dictionary_repository.dart';
import 'helpers/fake_fsrs_repository.dart';

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

final _entry3 = DictionaryEntry(
  id: '3',
  word: 'serendipity',
  translation: 'удача',
  addedAt: DateTime(2026, 1, 3),
);

void main() {
  group('DictionaryBloc', () {
    late FakeDictionaryRepository repository;
    late FakeFsrsRepository fsrsRepository;

    setUp(() {
      repository = FakeDictionaryRepository();
      fsrsRepository = FakeFsrsRepository();
    });

    blocTest<DictionaryBloc, DictionaryState>(
      'emits loading then success with entries',
      setUp: () => repository.seed([_entry1, _entry2]),
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      expect: () => [
        DictionaryState(status: DictionaryStatus.loading),
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'emits success with empty list when no entries',
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      expect: () => [
        DictionaryState(status: DictionaryStatus.loading),
        DictionaryState(status: DictionaryStatus.success),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      expect: () => [
        DictionaryState(status: DictionaryStatus.loading),
        DictionaryState(status: DictionaryStatus.failure),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'search filters entries by query',
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(const DictionarySearchChanged('hello')),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
          searchQuery: 'hello',
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.filteredEntries, [_entry1]);
      },
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'search by translation also works',
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(const DictionarySearchChanged('мир')),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
          searchQuery: 'мир',
        ),
      ],
      verify: (bloc) {
        expect(bloc.state.filteredEntries, [_entry2]);
      },
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'delete entry removes it and reloads',
      setUp: () => repository.seed([_entry1, _entry2]),
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(DictionaryEntryDeleted(_entry1.id)),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry2],
          deletionVersion: 1,
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'bulk delete removes every id and reloads once',
      setUp: () => repository.seed([_entry1, _entry2, _entry3]),
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2, _entry3],
      ),
      act: (bloc) => bloc.add(
        DictionaryEntriesDeleted({_entry1.id, _entry3.id}),
      ),
      verify: (bloc) {
        expect(bloc.state.status, DictionaryStatus.success);
        expect(bloc.state.entries.map((e) => e.id), [_entry2.id]);
      },
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'filter changed emits new filter state',
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1, _entry2],
      ),
      act: (bloc) => bloc.add(
        const DictionaryFilterChanged(DictionaryFilter.mastered),
      ),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.success,
          entries: [_entry1, _entry2],
          filter: DictionaryFilter.mastered,
        ),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'add entry persists then reloads',
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(status: DictionaryStatus.success),
      act: (bloc) => bloc.add(
        const DictionaryEntryAdded(word: 'gusto', translation: 'удовольствие'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, DictionaryStatus.success);
        expect(bloc.state.entries, hasLength(1));
        expect(bloc.state.entries.first.word, 'gusto');
        expect(bloc.state.entries.first.translation, 'удовольствие');
      },
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'add entry emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(status: DictionaryStatus.success),
      act: (bloc) => bloc.add(
        const DictionaryEntryAdded(word: 'gusto', translation: 'удовольствие'),
      ),
      expect: () => [
        DictionaryState(status: DictionaryStatus.failure),
      ],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'filter changed to same value is a no-op',
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        filter: DictionaryFilter.recent,
      ),
      act: (bloc) => bloc.add(
        const DictionaryFilterChanged(DictionaryFilter.recent),
      ),
      expect: () => <DictionaryState>[],
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'delete emits failure when repository throws',
      setUp: () {
        repository.seed([_entry1]);
        repository.shouldThrow = true;
      },
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1],
      ),
      act: (bloc) => bloc.add(DictionaryEntryDeleted(_entry1.id)),
      expect: () => [
        DictionaryState(
          status: DictionaryStatus.failure,
          entries: [_entry1],
          deletionVersion: 1,
        ),
      ],
    );

    // Same toast-discriminator contract as the catalog: every dispatched
    // delete must bump deletionVersion exactly once, success or fail —
    // otherwise overlapping deletes can mis-attribute the toast.
    blocTest<DictionaryBloc, DictionaryState>(
      'delete entry bumps deletionVersion on success',
      setUp: () => repository.seed([_entry1]),
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(
        status: DictionaryStatus.success,
        entries: [_entry1],
      ),
      act: (bloc) => bloc.add(DictionaryEntryDeleted(_entry1.id)),
      verify: (bloc) => expect(bloc.state.deletionVersion, 1),
    );

    blocTest<DictionaryBloc, DictionaryState>(
      'DictionaryLoadRequested does NOT bump deletionVersion',
      setUp: () => repository.seed([_entry1]),
      build: () => DictionaryBloc(
        dictionaryRepository: repository,
        fsrsRepository: fsrsRepository,
      ),
      seed: () => DictionaryState(deletionVersion: 5),
      act: (bloc) => bloc.add(const DictionaryLoadRequested()),
      verify: (bloc) => expect(bloc.state.deletionVersion, 5),
    );
  });

  group('DictionaryState', () {
    test('isEmpty is true when no entries', () {
      final state = DictionaryState();
      expect(state.isEmpty, isTrue);
    });

    // Mirrors the catalog cache test: `late final` should evaluate
    // _compute once per state instance and reuse the same `List`
    // reference across reads. Earlier the getter ran filter +
    // lowercase-search on every BlocBuilder rebuild.
    test('filteredEntries is cached across reads of one state instance', () {
      final state = DictionaryState(entries: [_entry1, _entry2]);
      final firstRead = state.filteredEntries;
      final secondRead = state.filteredEntries;
      expect(identical(firstRead, secondRead), isTrue);
    });

    test('filteredEntries returns all when query is empty', () {
      final state = DictionaryState(entries: [_entry1, _entry2]);
      expect(state.filteredEntries, hasLength(2));
    });

    test('filteredEntries filters by word', () {
      final state = DictionaryState(
        entries: [_entry1, _entry2],
        searchQuery: 'hello',
      );
      expect(state.filteredEntries, [_entry1]);
    });

    test('filteredEntries filters by translation', () {
      final state = DictionaryState(
        entries: [_entry1, _entry2],
        searchQuery: 'мир',
      );
      expect(state.filteredEntries, [_entry2]);
    });

    test('filter Mastered keeps only mastered entries', () {
      final state = DictionaryState(
        entries: [_entry1, _entry2, _entry3],
        masteredIds: const {'1', '3'},
        filter: DictionaryFilter.mastered,
      );
      expect(state.filteredEntries, [_entry1, _entry3]);
    });

    test('filter Learning keeps only non-mastered entries', () {
      final state = DictionaryState(
        entries: [_entry1, _entry2, _entry3],
        masteredIds: const {'1', '3'},
        filter: DictionaryFilter.learning,
      );
      expect(state.filteredEntries, [_entry2]);
    });

    test('filter Recent sorts by addedAt desc and caps at recentLimit', () {
      // Build N+1 entries so we can verify the cap.
      final entries = [
        for (var i = 0; i < DictionaryState.recentLimit + 2; i++)
          DictionaryEntry(
            id: 'e$i',
            word: 'w$i',
            translation: 't$i',
            addedAt: DateTime(2026, 1, i + 1),
          ),
      ];
      final state = DictionaryState(
        entries: entries,
        filter: DictionaryFilter.recent,
      );
      expect(
        state.filteredEntries,
        hasLength(DictionaryState.recentLimit),
      );
      // First result is the newest by addedAt.
      expect(
        state.filteredEntries.first.id,
        entries.last.id,
      );
    });

    test('filter and search compose: filter first, then search', () {
      // Two mastered entries, one unmastered. Search "world" hits an
      // unmastered entry — filter should drop it before search.
      final state = DictionaryState(
        entries: [_entry1, _entry2, _entry3],
        masteredIds: const {'1', '3'},
        filter: DictionaryFilter.mastered,
        searchQuery: 'world',
      );
      expect(state.filteredEntries, isEmpty);
    });

    test('learningCount is total minus mastered', () {
      final state = DictionaryState(
        entries: [_entry1, _entry2, _entry3],
        masteredIds: const {'1'},
      );
      expect(state.masteredCount, 1);
      expect(state.learningCount, 2);
    });
  });
}
