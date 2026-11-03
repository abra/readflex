import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:toast_service/toast_service.dart';

import 'practice_bloc.dart';
import 'practice_page_header.dart';
import 'practice_settings_sheet.dart';
import 'practice_source_cover.dart';
import 'practice_source_summary.dart';

part 'practice_hub_sections.dart';

/// Starts a review session. [sourceId] narrows it to one source; [ahead]
/// reviews cards before they are due. Completes when the session closes.
typedef PracticeStartReview =
    Future<void> Function({String? sourceId, bool ahead});

/// The Practice section, pushed above the Library: its name and the back
/// chevron in the app bar, then what is due today, the Vocabulary and Highlights
/// collections and each source's share. Review stays within thumb reach on a
/// phone and alongside the due overview on a wide workspace.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({
    required this.fsrsRepository,
    required this.dictionaryRepository,
    required this.highlightRepository,
    required this.bookRepository,
    required this.preferencesService,
    required this.onStartReview,
    required this.onWordsPressed,
    required this.onHighlightsPressed,
    this.articleRepository,
    super.key,
  });

  final FsrsRepository fsrsRepository;
  final DictionaryRepository dictionaryRepository;
  final HighlightRepository highlightRepository;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final PreferencesService preferencesService;
  final PracticeStartReview onStartReview;
  final Future<void> Function() onWordsPressed;
  final Future<void> Function() onHighlightsPressed;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('PracticeScreen');
    return BlocProvider(
      create: (_) => PracticeBloc(
        fsrsRepository: fsrsRepository,
        dictionaryRepository: dictionaryRepository,
        highlightRepository: highlightRepository,
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        preferencesService: preferencesService,
      )..add(const PracticeLoadRequested()),
      child: _PracticeView(
        onSettingsPressed: () => showPracticeSettingsSheet(
          context: context,
          preferencesService: preferencesService,
        ),
        onStartReview: onStartReview,
        onWordsPressed: onWordsPressed,
        onHighlightsPressed: onHighlightsPressed,
      ),
    );
  }
}

class _PracticeView extends StatefulWidget {
  const _PracticeView({
    required this.onSettingsPressed,
    required this.onStartReview,
    required this.onWordsPressed,
    required this.onHighlightsPressed,
  });

  final Future<void> Function() onSettingsPressed;
  final PracticeStartReview onStartReview;
  final Future<void> Function() onWordsPressed;
  final Future<void> Function() onHighlightsPressed;

  @override
  State<_PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<_PracticeView> {
  void _refresh() =>
      context.read<PracticeBloc>().add(const PracticeLoadRequested());

  Future<void> _after(Future<void> Function() action) async {
    await action();
    if (mounted) _refresh();
  }

  /// Settings change what counts as due, so the hub reloads after them.
  Future<void> _openSettings() => _after(widget.onSettingsPressed);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<PracticeBloc, PracticeState>(
      builder: (context, state) {
        final ready = state.status == PracticeStatus.ready;
        final showStart = ready && !state.hasNothing;
        final wide =
            AppWindowSize.isWide(context) &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.5;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            excludeHeaderSemantics: true,
            titleSpacing: 0,
            title: PracticePageHeader(
              title: l10n.practiceTitle,
              trailing: AppPlainIconButton(
                key: const ValueKey('practiceSettingsButton'),
                icon: AppIcons.settings,
                tooltip: l10n.practiceSettingsTitle,
                color: context.colors.onSurface,
                onPressed: _openSettings,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: AppContentFrame(
              maxWidth: wide ? AppSizes.pageContentMaxWidth : 720,
              child: switch (state.status) {
                PracticeStatus.initial || PracticeStatus.loading =>
                  const CenteredCircularProgressIndicator(),
                PracticeStatus.failure => ErrorState(
                  message: l10n.practiceLoadFailed,
                  retryLabel: l10n.commonRetry,
                  onRetry: _refresh,
                ),
                PracticeStatus.ready => _PracticeContent(
                  state: state,
                  wide: wide,
                  onStartReview: () => _after(
                    () => widget.onStartReview(ahead: state.due == 0),
                  ),
                  onWordsPressed: () => _after(widget.onWordsPressed),
                  onHighlightsPressed: () => _after(widget.onHighlightsPressed),
                  onSourcePressed: (summary) => _after(
                    () => widget.onStartReview(
                      sourceId: summary.source.id,
                      ahead: summary.due == 0,
                    ),
                  ),
                ),
              },
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          // The button arrives in the same frame as the content it belongs
          // to; Material's default would scale and turn it in on its own.
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: showStart && !wide
              ? ToastAvoidArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PracticeStartButton(
                      ahead: state.due == 0,
                      onPressed: () => _after(
                        () => widget.onStartReview(ahead: state.due == 0),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// Share of the window the empty state is centred in, as in Library.
const double _emptyStateHeightShare = 0.6;

/// Bottom padding for the hub list: the last row ends a 16dp gap above the
/// Start review button, which floats 8dp above the Scaffold's 16dp margin.
double practiceContentBottomPadding(BuildContext context) =>
    AppSizes.buttonHeight +
    AppSpacing.sm +
    AppSpacing.lg +
    AppSpacing.lg +
    MediaQuery.paddingOf(context).bottom;

class _PracticeContent extends StatelessWidget {
  const _PracticeContent({
    required this.state,
    required this.wide,
    required this.onStartReview,
    required this.onWordsPressed,
    required this.onHighlightsPressed,
    required this.onSourcePressed,
  });

  final PracticeState state;
  final bool wide;
  final VoidCallback onStartReview;
  final VoidCallback onWordsPressed;
  final VoidCallback onHighlightsPressed;
  final ValueChanged<PracticeSourceSummary> onSourcePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.hasNothing) {
      return ListView(
        key: const ValueKey('practiceContent'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Centred in the space under the app bar, as Library's first-run
          // state is; the minimum height keeps it there on a short window.
          // No command: back leads to the Library, where saving starts.
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height * _emptyStateHeightShare,
            ),
            child: AppFirstRunState(
              key: const ValueKey('practiceEmptyState'),
              icon: AppIcons.practice,
              title: l10n.practiceNothingTitle,
              subtitle: l10n.practiceNothingBody,
            ),
          ),
        ],
      );
    }
    final support = _PracticeSupport(
      key: const PageStorageKey('practiceSourceList'),
      state: state,
      includeOverview: !wide,
      onWordsPressed: onWordsPressed,
      onHighlightsPressed: onHighlightsPressed,
      onSourcePressed: onSourcePressed,
    );
    if (!wide) return support;
    return Padding(
      key: const ValueKey('practiceWideWorkspace'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              primary: false,
              child: _PracticeOverview(
                state: state,
                onStartReview: onStartReview,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(flex: 6, child: support),
        ],
      ),
    );
  }
}

const _rowPadding = EdgeInsets.symmetric(vertical: AppSpacing.xs);

class _PracticeOverview extends StatelessWidget {
  const _PracticeOverview({required this.state, this.onStartReview});

  final PracticeState state;
  final VoidCallback? onStartReview;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    return PracticeTodayCard(
      due: state.due,
      dueWords: stats.dueOf(ReviewableType.dictionary),
      dueHighlights: state.reviewHighlights
          ? stats.dueOf(ReviewableType.highlight)
          : 0,
      newToday: stats.newReviewedToday,
      streakDays: stats.streakDays,
      reviewedLast7Days: stats.reviewedLast7Days,
      total: state.total,
      action: onStartReview == null
          ? null
          : PracticeStartButton(
              ahead: state.due == 0,
              onPressed: onStartReview!,
              floating: false,
            ),
    );
  }
}

class _PracticeSupport extends StatelessWidget {
  const _PracticeSupport({
    required this.state,
    required this.includeOverview,
    required this.onWordsPressed,
    required this.onHighlightsPressed,
    required this.onSourcePressed,
    super.key,
  });

  final PracticeState state;
  final bool includeOverview;
  final VoidCallback onWordsPressed;
  final VoidCallback onHighlightsPressed;
  final ValueChanged<PracticeSourceSummary> onSourcePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CustomScrollView(
      key: const ValueKey('practiceContent'),
      primary: true,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            includeOverview ? AppSpacing.lg : 0,
            includeOverview ? AppSpacing.md : 0,
            includeOverview ? AppSpacing.lg : 0,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (includeOverview) ...[
                  _PracticeOverview(state: state),
                  const SizedBox(height: AppSpacing.xl),
                ],
                _PracticeCollections(
                  state: state,
                  onWordsPressed: onWordsPressed,
                  onHighlightsPressed: onHighlightsPressed,
                ),
                if (state.sources.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.practiceSectionBySource,
                      style: context.text.labelMedium.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            includeOverview ? AppSpacing.lg : 0,
            0,
            includeOverview ? AppSpacing.lg : 0,
            includeOverview
                ? practiceContentBottomPadding(context)
                : AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.builder(
            itemCount: state.sources.length,
            itemBuilder: (context, index) {
              final summary = state.sources[index];
              return PracticeSourceRow(
                key: ValueKey('practiceSource-${summary.source.id}'),
                summary: summary,
                onPressed: () => onSourcePressed(summary),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PracticeCollections extends StatelessWidget {
  const _PracticeCollections({
    required this.state,
    required this.onWordsPressed,
    required this.onHighlightsPressed,
  });

  final PracticeState state;
  final VoidCallback onWordsPressed;
  final VoidCallback onHighlightsPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = state.stats;
    return AppSettingsSection(
      title: l10n.practiceSectionCollections,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDrillInRow(
                key: const ValueKey('practiceWords'),
                icon: AppIcons.words,
                title: l10n.practiceWordsTitle,
                subtitle: l10n.practiceCollectionCounts(
                  stats.totalOf(ReviewableType.dictionary),
                  stats.dueOf(ReviewableType.dictionary),
                ),
                padding: _rowPadding,
                onTap: onWordsPressed,
              ),
              const Divider(height: 1),
              AppDrillInRow(
                key: const ValueKey('practiceHighlights'),
                icon: AppIcons.highlight,
                title: l10n.practiceHighlightsTitle,
                subtitle: l10n.practiceCollectionCounts(
                  stats.totalOf(ReviewableType.highlight),
                  stats.dueOf(ReviewableType.highlight),
                ),
                padding: _rowPadding,
                onTap: onHighlightsPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
