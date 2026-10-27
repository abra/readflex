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
import 'practice_source_cover.dart';
import 'practice_source_summary.dart';

part 'practice_hub_sections.dart';

/// Starts a review session. [sourceId] narrows it to one source; [ahead]
/// reviews cards before they are due. Completes when the session closes.
typedef PracticeStartReview =
    Future<void> Function({String? sourceId, bool ahead});

/// The Practice section, pushed above the Library: its name and the back
/// chevron in the app bar, then what is due today, the Vocabulary and Highlights
/// collections, each source's share, and Start review floating at the bottom.
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
        onStartReview: onStartReview,
        onWordsPressed: onWordsPressed,
        onHighlightsPressed: onHighlightsPressed,
      ),
    );
  }
}

class _PracticeView extends StatefulWidget {
  const _PracticeView({
    required this.onStartReview,
    required this.onWordsPressed,
    required this.onHighlightsPressed,
  });

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<PracticeBloc, PracticeState>(
      builder: (context, state) {
        final ready = state.status == PracticeStatus.ready;
        final showStart = ready && !state.hasNothing;
        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(),
            title: Text(l10n.practiceTitle),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          // The button arrives in the same frame as the content it belongs
          // to; Material's default would scale and turn it in on its own.
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: showStart
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
    required this.onWordsPressed,
    required this.onHighlightsPressed,
    required this.onSourcePressed,
  });

  final PracticeState state;
  final VoidCallback onWordsPressed;
  final VoidCallback onHighlightsPressed;
  final ValueChanged<PracticeSourceSummary> onSourcePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stats = state.stats;
    return ListView(
      key: const ValueKey('practiceContent'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        practiceContentBottomPadding(context),
      ),
      children: [
        if (state.hasNothing)
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
          )
        else ...[
          PracticeTodayCard(
            due: state.due,
            dueWords: stats.dueOf(ReviewableType.dictionary),
            dueHighlights: state.reviewHighlights
                ? stats.dueOf(ReviewableType.highlight)
                : 0,
            newToday: stats.newReviewedToday,
            streakDays: stats.streakDays,
            reviewedLast7Days: stats.reviewedLast7Days,
            total: state.total,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSettingsSection(
            title: l10n.practiceSectionCollections,
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
          if (state.sources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSettingsSection(
              title: l10n.practiceSectionBySource,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final summary in state.sources)
                    PracticeSourceRow(
                      key: ValueKey('practiceSource-${summary.source.id}'),
                      summary: summary,
                      onPressed: () => onSourcePressed(summary),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

const _rowPadding = EdgeInsets.symmetric(vertical: AppSpacing.xs);
