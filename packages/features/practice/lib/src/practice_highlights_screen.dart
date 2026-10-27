import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:readflex_localizations/readflex_localizations.dart';

import 'practice_highlight_tint.dart';
import 'practice_highlights_cubit.dart';
import 'practice_item.dart';
import 'review_interval_label.dart';

/// Every text highlight, grouped by source: search, a colour filter, and a
/// row per passage that opens it in its source.
class PracticeHighlightsScreen extends StatelessWidget {
  const PracticeHighlightsScreen({
    required this.highlightRepository,
    required this.fsrsRepository,
    required this.bookRepository,
    required this.onOpenInSource,
    this.articleRepository,
    super.key,
  });

  final HighlightRepository highlightRepository;
  final FsrsRepository fsrsRepository;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final Future<void> Function(Highlight highlight) onOpenInSource;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('PracticeHighlightsScreen');
    return BlocProvider(
      create: (_) => PracticeHighlightsCubit(
        highlightRepository: highlightRepository,
        fsrsRepository: fsrsRepository,
        bookRepository: bookRepository,
        articleRepository: articleRepository,
      )..load(),
      child: _PracticeHighlightsView(onOpenInSource: onOpenInSource),
    );
  }
}

class _PracticeHighlightsView extends StatefulWidget {
  const _PracticeHighlightsView({required this.onOpenInSource});

  final Future<void> Function(Highlight highlight) onOpenInSource;

  @override
  State<_PracticeHighlightsView> createState() =>
      _PracticeHighlightsViewState();
}

class _PracticeHighlightsViewState extends State<_PracticeHighlightsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Highlight highlight) async {
    final cubit = context.read<PracticeHighlightsCubit>();
    await widget.onOpenInSource(highlight);
    if (mounted) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.practiceHighlightsTitle),
      ),
      body: BlocBuilder<PracticeHighlightsCubit, PracticeHighlightsState>(
        builder: (context, state) {
          final cubit = context.read<PracticeHighlightsCubit>();
          return switch (state.status) {
            PracticeHighlightsStatus.initial ||
            PracticeHighlightsStatus.loading =>
              const CenteredCircularProgressIndicator(),
            PracticeHighlightsStatus.failure => ErrorState(
              message: l10n.practiceLoadFailed,
              retryLabel: l10n.commonRetry,
              onRetry: cubit.load,
            ),
            PracticeHighlightsStatus.ready => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: SearchField(
                    hintText: l10n.practiceSearchHighlights,
                    clearButtonSemanticsLabel: l10n.commonClearSearch,
                    controller: _search,
                    onChanged: cubit.setQuery,
                  ),
                ),
                PracticeColorFilterRow(
                  selected: state.color,
                  onSelected: cubit.setColor,
                ),
                Expanded(
                  child: state.highlights.isEmpty
                      ? EmptyState(
                          icon: AppIcons.highlight,
                          message: l10n.practiceHighlightsEmptyTitle,
                          subtitle: l10n.practiceHighlightsEmptyBody,
                        )
                      : state.groups.isEmpty
                      ? EmptyState(
                          message: l10n.practiceNoMatches,
                          compact: true,
                        )
                      : _GroupedHighlightList(
                          groups: state.groups,
                          onOpen: _open,
                        ),
                ),
              ],
            ),
          };
        },
      ),
    );
  }
}

/// All colours or one, as chips on one scrolling line.
class PracticeColorFilterRow extends StatelessWidget {
  const PracticeColorFilterRow({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final HighlightColor? selected;
  final ValueChanged<HighlightColor?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          AppFilterChip(
            key: const ValueKey('practiceColor-all'),
            label: l10n.practiceFilterAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final color in HighlightColor.values)
            AppFilterChip(
              key: ValueKey('practiceColor-${color.name}'),
              label: practiceHighlightColorLabel(l10n, color),
              selected: selected == color,
              onTap: () => onSelected(color),
            ),
        ],
      ),
    );
  }
}

class _GroupedHighlightList extends StatelessWidget {
  const _GroupedHighlightList({required this.groups, required this.onOpen});

  final List<PracticeHighlightGroup> groups;
  final ValueChanged<Highlight> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final group in groups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              group.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.serif(
                textStyle: context.text.titleMedium,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ),
      );
      for (final item in group.items) {
        rows.add(
          PracticeHighlightRow(
            key: ValueKey('practiceHighlight-${item.itemId}'),
            item: item,
            onPressed: () => onOpen(item.highlight),
          ),
        );
      }
    }
    return ListView(
      key: const ValueKey('practiceHighlightsList'),
      padding: EdgeInsets.only(bottom: appBottomSafeInset(context)),
      children: rows,
    );
  }
}

const int _quoteMaxLines = 3;
const int _noteMaxLines = 2;

/// One passage: the quote on its colour, the note below, then the chapter
/// and when it is due. Tap opens it in its source.
class PracticeHighlightRow extends StatelessWidget {
  const PracticeHighlightRow({
    required this.item,
    required this.onPressed,
    super.key,
  });

  final PracticeHighlightItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final colors = context.colors;
    final highlight = item.highlight;
    final quote = highlight.text.trim();
    final note = highlight.note?.trim();
    final hasNote = note != null && note.isNotEmpty;
    final direction = Bidi.detectRtlDirectionality(quote)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final due = reviewDueLabel(
      l10n,
      item.fsrs.nextReviewAt,
      isNew: item.isNew,
      now: DateTime.now(),
    );
    final chapter = highlight.chapterTitle?.trim();
    final meta = [
      if (chapter != null && chapter.isNotEmpty) chapter,
      due,
    ].join(' · ');
    return Semantics(
      button: true,
      label: quote,
      value: [?note, meta].join(', '),
      onTapHint: l10n.practiceOpenInBook,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: quote,
                  style: text.bodyMedium.copyWith(
                    color: colors.onSurface,
                    backgroundColor: practiceHighlightTint(
                      context,
                      highlight.color,
                    ),
                  ),
                ),
                textDirection: direction,
                maxLines: _quoteMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasNote) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  note,
                  maxLines: _noteMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall.copyWith(color: colors.onSurface),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
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
