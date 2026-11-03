import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'practice_item.dart';
import 'practice_page_header.dart';
import 'practice_word_sheet.dart';
import 'practice_words_cubit.dart';
import 'review_interval_label.dart';

/// Opens [sourceId] in the reader, at [cfiRange] when known.
typedef PracticeOpenInSource =
    Future<void> Function(String sourceId, String? cfiRange);

/// Every saved word: search, All / Learning / Mastered, and a sheet with the
/// saved meaning, the sentence and Open in book.
class PracticeWordsScreen extends StatelessWidget {
  const PracticeWordsScreen({
    required this.dictionaryRepository,
    required this.fsrsRepository,
    required this.bookRepository,
    required this.onOpenInSource,
    this.articleRepository,
    super.key,
  });

  final DictionaryRepository dictionaryRepository;
  final FsrsRepository fsrsRepository;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final PracticeOpenInSource onOpenInSource;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('PracticeWordsScreen');
    return BlocProvider(
      create: (_) => PracticeWordsCubit(
        dictionaryRepository: dictionaryRepository,
        fsrsRepository: fsrsRepository,
        bookRepository: bookRepository,
        articleRepository: articleRepository,
      )..load(),
      child: _PracticeWordsView(onOpenInSource: onOpenInSource),
    );
  }
}

class _PracticeWordsView extends StatefulWidget {
  const _PracticeWordsView({required this.onOpenInSource});

  final PracticeOpenInSource onOpenInSource;

  @override
  State<_PracticeWordsView> createState() => _PracticeWordsViewState();
}

class _PracticeWordsViewState extends State<_PracticeWordsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openWord(PracticeWordItem word) async {
    final cubit = context.read<PracticeWordsCubit>();
    final outcome = await showPracticeWordSheet(
      context,
      word: word,
      canOpenInSource: word.sourceId != null,
    );
    if (!mounted) return;
    switch (outcome) {
      case PracticeWordSheetOutcome.open:
        final sourceId = word.sourceId;
        if (sourceId == null) return;
        await widget.onOpenInSource(sourceId, word.cfiRange);
        if (mounted) await cubit.load();
      case PracticeWordSheetOutcome.remove:
        await cubit.remove(word);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        excludeHeaderSemantics: true,
        titleSpacing: 0,
        title: PracticePageHeader(title: l10n.practiceWordsTitle),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: AppContentFrame(
          maxWidth: 960,
          child: BlocBuilder<PracticeWordsCubit, PracticeWordsState>(
            builder: (context, state) {
              final cubit = context.read<PracticeWordsCubit>();
              final visible = state.visible;
              return switch (state.status) {
                PracticeWordsStatus.initial || PracticeWordsStatus.loading =>
                  const CenteredCircularProgressIndicator(),
                PracticeWordsStatus.failure => ErrorState(
                  message: l10n.practiceLoadFailed,
                  retryLabel: l10n.commonRetry,
                  onRetry: cubit.load,
                ),
                PracticeWordsStatus.ready => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: _PracticeWordsToolbar(
                        search: SearchField(
                          hintText: l10n.practiceSearchWords,
                          clearButtonSemanticsLabel: l10n.commonClearSearch,
                          controller: _search,
                          onChanged: cubit.setQuery,
                        ),
                        filter: AppChoiceControl<PracticeWordsFilter>(
                          key: const ValueKey('practiceWordsFilter'),
                          selected: state.filter,
                          onChanged: cubit.setFilter,
                          options: [
                            AppChoiceOption(
                              value: PracticeWordsFilter.all,
                              label: l10n.practiceFilterAll,
                            ),
                            AppChoiceOption(
                              value: PracticeWordsFilter.learning,
                              label: l10n.practiceFilterLearning,
                            ),
                            AppChoiceOption(
                              value: PracticeWordsFilter.mastered,
                              label: l10n.practiceFilterMastered,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: state.words.isEmpty
                          ? EmptyState(
                              icon: AppIcons.words,
                              message: l10n.practiceWordsEmptyTitle,
                              subtitle: l10n.practiceWordsEmptyBody,
                            )
                          : visible.isEmpty
                          ? EmptyState(
                              message: l10n.practiceNoMatches,
                              compact: true,
                            )
                          : ListView.separated(
                              key: const ValueKey('practiceWordsList'),
                              padding: EdgeInsets.only(
                                bottom: appBottomSafeInset(context),
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                child: Divider(height: 1),
                              ),
                              itemBuilder: (context, index) => PracticeWordRow(
                                word: visible[index],
                                onPressed: () => _openWord(visible[index]),
                              ),
                            ),
                    ),
                  ],
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _PracticeWordsToolbar extends StatelessWidget {
  const _PracticeWordsToolbar({required this.search, required this.filter});

  final Widget search;
  final Widget filter;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal =
          constraints.maxWidth >= 760 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.3;
      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: horizontal
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        spacing: horizontal ? AppSpacing.xl : AppSpacing.md,
        children: [
          for (final child in [search, filter])
            Flexible(
              flex: horizontal ? 1 : 0,
              fit: horizontal ? FlexFit.tight : FlexFit.loose,
              child: child,
            ),
        ],
      );
    },
  );
}

/// Each saved word keeps its own reading direction, separate from its meaning
/// and the source and due date below.
class PracticeWordRow extends StatelessWidget {
  const PracticeWordRow({
    required this.word,
    required this.onPressed,
    super.key,
  });

  final PracticeWordItem word;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final entry = word.entry;
    final direction = Bidi.detectRtlDirectionality(entry.word)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final due = reviewDueLabel(
      l10n,
      word.fsrs.nextReviewAt,
      isNew: word.isNew,
      now: DateTime.now(),
    );
    final meta = [?word.sourceTitle, due].join(' · ');
    return Semantics(
      button: true,
      enabled: true,
      label: '${entry.word} · ${entry.translation}',
      value: meta,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('practiceWord-${entry.id}'),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.word,
                style: text.titleMedium.copyWith(
                  letterSpacing: 0,
                  color: colors.onSurface,
                ),
                textDirection: direction,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                entry.translation,
                textDirection: Bidi.detectRtlDirectionality(entry.translation)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
