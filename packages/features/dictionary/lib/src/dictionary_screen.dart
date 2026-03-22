import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import 'dictionary_bloc.dart';

/// Dictionary tab: browse saved words and phrases.
class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({
    required this.dictionaryRepository,
    super.key,
  });

  final DictionaryRepository dictionaryRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DictionaryBloc(dictionaryRepository: dictionaryRepository)
            ..add(const DictionaryLoadRequested()),
      child: const DictionaryView(),
    );
  }
}

class DictionaryView extends StatelessWidget {
  const DictionaryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.large,
              vertical: Spacing.small,
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search words...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (query) => context.read<DictionaryBloc>().add(
                DictionarySearchChanged(query),
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<DictionaryBloc, DictionaryState>(
        builder: (context, state) {
          return switch (state.status) {
            DictionaryStatus.initial || DictionaryStatus.loading =>
              const CenteredCircularProgressIndicator(),
            DictionaryStatus.failure => ErrorState(
              message: 'Failed to load dictionary',
              retryLabel: 'Retry',
              onRetry: () => context.read<DictionaryBloc>().add(
                const DictionaryLoadRequested(),
              ),
            ),
            DictionaryStatus.success =>
              state.isEmpty
                  ? const EmptyState(
                      message:
                          'No saved words yet.\nTranslate text while reading to add words.',
                    )
                  : _EntryList(entries: state.filteredEntries),
          };
        },
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<DictionaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(message: 'No matches found.');
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Spacing.xxxLarge),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: Spacing.large),
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          onDismissed: (_) => context.read<DictionaryBloc>().add(
            DictionaryEntryDeleted(entry.id),
          ),
          child: ListTile(
            title: Text(
              entry.word,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(entry.translation),
            trailing: entry.usageExamples.isNotEmpty
                ? const Icon(Icons.format_quote, size: 16)
                : null,
          ),
        );
      },
    );
  }
}
