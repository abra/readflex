import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoScrollbar,
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        showCupertinoModalPopup;
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'practice_item.dart';
import 'practice_source_cover.dart';
import 'review_interval_label.dart';
import 'review_session_bloc.dart';

part 'review_session_cards.dart';
part 'review_session_controls.dart';
part 'review_session_highlight_card.dart';

const double _reviewWorkspaceMaxWidth = 960;
const double _reviewCardMaxWidth = 640;

/// A full-screen review session above Practice: words reveal an answer before
/// Again / Hard / Good; highlights offer Keep / Show less immediately.
/// Ends with the session's numbers.
class ReviewSessionScreen extends StatelessWidget {
  const ReviewSessionScreen({
    required this.fsrsRepository,
    required this.dictionaryRepository,
    required this.highlightRepository,
    required this.bookRepository,
    required this.preferencesService,
    required this.onOpenInSource,
    this.articleRepository,
    this.sourceId,
    this.ahead = false,
    super.key,
  });

  final FsrsRepository fsrsRepository;
  final DictionaryRepository dictionaryRepository;
  final HighlightRepository highlightRepository;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final PreferencesService preferencesService;

  /// Opens the card's source at its passage.
  final Future<void> Function(String sourceId, String? cfiRange) onOpenInSource;
  final String? sourceId;
  final bool ahead;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ReviewSessionScreen');
    return BlocProvider(
      create: (_) => ReviewSessionBloc(
        fsrsRepository: fsrsRepository,
        dictionaryRepository: dictionaryRepository,
        highlightRepository: highlightRepository,
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        preferencesService: preferencesService,
        sourceId: sourceId,
        ahead: ahead,
      )..add(const ReviewSessionStarted()),
      child: _ReviewSessionView(onOpenInSource: onOpenInSource),
    );
  }
}

class _ReviewSessionView extends StatelessWidget {
  const _ReviewSessionView({required this.onOpenInSource});

  final Future<void> Function(String sourceId, String? cfiRange) onOpenInSource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ReviewSessionBloc, ReviewSessionState>(
      builder: (context, state) {
        final bloc = context.read<ReviewSessionBloc>();
        final current = state.current;
        return AppScaffold(
          body: SafeArea(
            child: AppContentFrame(
              maxWidth: _reviewWorkspaceMaxWidth,
              child: switch (state.status) {
                ReviewSessionStatus.loading =>
                  const CenteredCircularProgressIndicator(),
                ReviewSessionStatus.failure => ErrorState(
                  message: l10n.practiceLoadFailed,
                  retryLabel: l10n.commonRetry,
                  onRetry: () => bloc.add(const ReviewSessionStarted()),
                  secondaryLabel: l10n.commonClose,
                  onSecondary: () => Navigator.of(context).pop(),
                ),
                ReviewSessionStatus.empty => EmptyState(
                  icon: AppIcons.practice,
                  message: l10n.practiceCaughtUp,
                  subtitle: l10n.practiceCaughtUpBody,
                  action: AppButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: AppButtonLabel(l10n.commonDone),
                  ),
                ),
                ReviewSessionStatus.completed => ReviewSessionSummary(
                  reviewed: state.reviewed,
                  known: state.known,
                  again: state.again.length,
                  onDone: () => Navigator.of(context).pop(),
                  onReviewAgain: () =>
                      bloc.add(const ReviewSessionAgainRequested()),
                ),
                ReviewSessionStatus.reviewing when current != null => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReviewSessionTopBar(
                      isSaving: state.isSaving,
                      position: state.index + 1,
                      total: state.items.length,
                      canOpenInSource: current.sourceId != null,
                      onClose: () => Navigator.of(context).pop(),
                      onOpenInSource: () =>
                          onOpenInSource(current.sourceId!, current.cfiRange),
                      onRemove: () => bloc.add(
                        ReviewSessionCardRemoved(state.cardIdentity!),
                      ),
                    ),
                    Expanded(
                      child: switch (current) {
                        PracticeWordItem() => _ReviewWordCardViewport(
                          key: ValueKey('reviewViewport-${current.itemId}'),
                          child: ReviewWordCard(
                            key: ValueKey('reviewCard-${current.itemId}'),
                            item: current,
                            revealed: state.revealed,
                          ),
                        ),
                        PracticeHighlightItem() => _ReviewHighlightViewport(
                          key: ValueKey('reviewViewport-${current.itemId}'),
                          child: ReviewHighlightCard(
                            key: ValueKey('reviewCard-${current.itemId}'),
                            item: current,
                            onOpenInSource:
                                current.sourceId == null || state.isSaving
                                ? null
                                : () => onOpenInSource(
                                    current.sourceId!,
                                    current.cfiRange,
                                  ),
                          ),
                        ),
                      },
                    ),
                    ReviewSessionControls(
                      isSaving: state.isSaving,
                      item: current,
                      revealed: state.revealed,
                      intervals: state.intervals,
                      onReveal: () => bloc.add(
                        ReviewSessionAnswerRevealed(state.cardIdentity!),
                      ),
                      onRated: (rating) => bloc.add(
                        ReviewSessionCardRated(state.cardIdentity!, rating),
                      ),
                    ),
                  ],
                ),
                ReviewSessionStatus.reviewing => const SizedBox.shrink(),
              },
            ),
          ),
        );
      },
    );
  }
}

/// A centred word card; revealing its answer preserves this scroll position.
class _ReviewWordCardViewport extends StatelessWidget {
  const _ReviewWordCardViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ClipRect(
      key: const ValueKey('reviewCardClip'),
      child: ScrollEdgeFadeStack(
        showBottomFade: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const ValueKey('reviewCardViewport'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.xl * 2)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _reviewCardMaxWidth,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppSurface(
                      key: const ValueKey('reviewStudyCard'),
                      role: AppSurfaceRole.reviewCard,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Keeps the complete highlight frame on screen; only its body scrolls.
class _ReviewHighlightViewport extends StatelessWidget {
  const _ReviewHighlightViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final vertical = constraints.maxHeight < AppSizes.buttonHeight * 6
          ? AppSpacing.lg
          : AppSpacing.xl;
      return Padding(
        key: const ValueKey('reviewHighlightViewport'),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          vertical,
          AppSpacing.lg,
          vertical + AppSpacing.md,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _reviewCardMaxWidth),
            child: child,
          ),
        ),
      );
    },
  );
}
