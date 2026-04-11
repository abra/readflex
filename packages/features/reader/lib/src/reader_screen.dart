import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';

import 'article_content_view.dart';
import 'reader_bloc.dart';

/// Approximate height of the context panel, used to offset the review banner.
const _kContextPanelHeight = 80.0;

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.bookRepository,
    required this.articleRepository,
    required this.highlightRepository,
    required this.textActions,
    this.onCheckDueItems,
    this.onStartMiniReview,
    super.key,
  });

  final String sourceId;
  final BookRepository bookRepository;
  final ArticleRepository articleRepository;
  final HighlightRepository highlightRepository;
  final List<TextAction> textActions;
  final Future<int> Function(String sourceId)? onCheckDueItems;
  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ReaderScreen(sourceId: $sourceId)');

    return BlocProvider(
      create: (_) => ReaderBloc(
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        highlightRepository: highlightRepository,
      )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
      child: _ReaderView(
        textActions: textActions,
        onCheckDueItems: onCheckDueItems,
        onStartMiniReview: onStartMiniReview,
      ),
    );
  }
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({
    required this.textActions,
    this.onCheckDueItems,
    this.onStartMiniReview,
  });

  final List<TextAction> textActions;
  final Future<int> Function(String sourceId)? onCheckDueItems;
  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: BlocSelector<ReaderBloc, ReaderState, _ReaderAppBarState>(
          selector: (state) => _ReaderAppBarState(
            title: state.title,
            highlightCount: state.highlights.length,
          ),
          builder: (context, appBarState) {
            return _ReaderAppBar(
              title: appBarState.title,
              highlightCount: appBarState.highlightCount,
            );
          },
        ),
      ),
      body: BlocBuilder<ReaderBloc, ReaderState>(
        buildWhen: (previous, current) => previous != current,
        builder: (context, state) => _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ReaderState state) {
    return switch (state.status) {
      ReaderStatus.initial || ReaderStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      ReaderStatus.failure => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text('Failed to load content'),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
      ReaderStatus.ready => _ReadyContent(
        state: state,
        textActions: textActions,
        onCheckDueItems: onCheckDueItems,
        onStartMiniReview: onStartMiniReview,
      ),
    };
  }
}

class _ReaderAppBarState {
  const _ReaderAppBarState({
    required this.title,
    required this.highlightCount,
  });

  final String title;
  final int highlightCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ReaderAppBarState &&
          title == other.title &&
          highlightCount == other.highlightCount;

  @override
  int get hashCode => Object.hash(title, highlightCount);
}

class _ReaderAppBar extends StatelessWidget {
  const _ReaderAppBar({
    required this.title,
    required this.highlightCount,
  });

  final String title;
  final int highlightCount;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (highlightCount > 0)
          Badge(
            label: Text('$highlightCount'),
            child: IconButton(
              icon: const Icon(Icons.highlight),
              onPressed: () {
                // TODO: show highlights list as bottom sheet.
              },
            ),
          ),
      ],
    );
  }
}

class _ReadyContent extends StatefulWidget {
  const _ReadyContent({
    required this.state,
    required this.textActions,
    this.onCheckDueItems,
    this.onStartMiniReview,
  });

  final ReaderState state;
  final List<TextAction> textActions;
  final Future<int> Function(String sourceId)? onCheckDueItems;
  final void Function(BuildContext context, String sourceId)? onStartMiniReview;

  @override
  State<_ReadyContent> createState() => _ReadyContentState();
}

class _ReadyContentState extends State<_ReadyContent> {
  // 5-minute interval balances responsiveness with avoiding excessive DB
  // queries while reading. An initial check runs on load for items already due.
  static const _checkInterval = Duration(minutes: 5);
  Timer? _dueCheckTimer;

  @override
  void initState() {
    super.initState();
    _scheduleCheckDueItems();
  }

  @override
  void dispose() {
    _dueCheckTimer?.cancel();
    super.dispose();
  }

  void _scheduleCheckDueItems() {
    final onCheck = widget.onCheckDueItems;
    if (onCheck == null) return;

    final sourceId = widget.state.sourceId;
    if (sourceId == null) return;

    // Initial check after content loads
    _checkDueItems(onCheck, sourceId);

    // Periodic check every 5 minutes
    _dueCheckTimer = Timer.periodic(_checkInterval, (_) {
      _checkDueItems(onCheck, sourceId);
    });
  }

  Future<void> _checkDueItems(
    Future<int> Function(String) onCheck,
    String sourceId,
  ) async {
    final count = await onCheck(sourceId);
    if (count > 0 && mounted) {
      context.read<ReaderBloc>().add(const ReaderReviewReminderShown());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReaderBloc>();
    final state = widget.state;
    final appearance = PreferencesScope.readerAppearanceOf(context);
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;
    final readerFont = ReaderFontPreset.fromId(appearance.fontId);
    final text = context.text;
    final bodyLarge = text.bodyLarge;
    final readerTextStyle = bodyLarge.copyWith(
      fontFamily: readerFont.fontFamily,
      fontSize: bodyLarge.fontSize! * appearance.textScale,
      height: appearance.lineHeight,
      color: readerTheme.primaryTextColor,
    );

    return Stack(
      children: [
        ColoredBox(
          color: readerTheme.backgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: state.isArticle && state.articleContent.isNotEmpty
                  ? ArticleContentView(
                      html: state.articleContent,
                      textStyle: readerTextStyle,
                      accentColor: readerTheme.accentColor,
                      secondaryTextColor: readerTheme.secondaryTextColor,
                      dividerColor: readerTheme.dividerColor,
                      onSelectionChanged: (selectedText) {
                        if (selectedText == null) {
                          bloc.add(const ReaderTextDeselected());
                        } else {
                          bloc.add(
                            ReaderTextSelected(selectedText: selectedText),
                          );
                        }
                      },
                    )
                  // Book rendering is still deferred until the book track
                  // vendors foliate-js into the reader package, so books
                  // keep the hero-card placeholder for now.
                  : _BookPlaceholder(
                      state: state,
                      readerTheme: readerTheme,
                      readerTextStyle: readerTextStyle,
                      text: text,
                    ),
            ),
          ),
        ),

        // Context panel (text actions) — shown when text is selected
        if (state.hasSelection &&
            state.sourceId != null &&
            state.sourceType != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ContextPanel(
              selectedText: state.selectedText,
              sourceId: state.sourceId!,
              sourceType: state.sourceType!,
              selectionCfiRange: state.selectionCfiRange,
              selectionPageNumber: state.selectionPageNumber,
              selectionScrollOffset: state.selectionScrollOffset,
              textActions: widget.textActions,
              panelColor: readerTheme.panelColor,
              iconColor: readerTheme.primaryTextColor,
              dividerColor: readerTheme.dividerColor,
            ),
          ),

        // Review reminder banner
        if (state.showReviewReminder)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: state.hasSelection ? _kContextPanelHeight : AppSpacing.md,
            child: _ReviewReminderBanner(
              onReview: () {
                bloc.add(const ReaderReviewReminderDismissed());
                final sourceId = state.sourceId;
                if (sourceId != null) {
                  widget.onStartMiniReview?.call(context, sourceId);
                }
              },
              onDismiss: () {
                bloc.add(const ReaderReviewReminderDismissed());
              },
            ),
          ),
      ],
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.selectedText,
    required this.sourceId,
    required this.sourceType,
    required this.textActions,
    required this.panelColor,
    required this.iconColor,
    required this.dividerColor,
    this.selectionCfiRange,
    this.selectionPageNumber,
    this.selectionScrollOffset,
  });

  final String selectedText;
  final String sourceId;
  final SourceType sourceType;
  final List<TextAction> textActions;
  final Color panelColor;
  final Color iconColor;
  final Color dividerColor;
  final String? selectionCfiRange;
  final int? selectionPageNumber;
  final double? selectionScrollOffset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panelColor,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: dividerColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: textActions.map((action) {
                return IconButton(
                  icon: Icon(action.icon, color: iconColor),
                  tooltip: action.label,
                  onPressed: () {
                    action.onExecute(
                      context,
                      TextSelectionContext(
                        selectedText: selectedText,
                        sourceId: sourceId,
                        sourceType: sourceType,
                        cfiRange: selectionCfiRange,
                        pageNumber: selectionPageNumber,
                        scrollOffset: selectionScrollOffset,
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookPlaceholder extends StatelessWidget {
  const _BookPlaceholder({
    required this.state,
    required this.readerTheme,
    required this.readerTextStyle,
    required this.text,
  });

  final ReaderState state;
  final ReaderThemeData readerTheme;
  final TextStyle readerTextStyle;
  final AppTextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: readerTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: readerTheme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.isBook ? Icons.menu_book : Icons.article,
                size: 48,
                color: readerTheme.accentColor,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                state.title,
                style: text.headlineSmall.copyWith(
                  color: readerTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Book rendering is not implemented yet. Once the book track '
                'vendors foliate-js into the reader package, this placeholder '
                'will be replaced by the real WebView-based reader.',
                style: readerTextStyle,
                textAlign: TextAlign.start,
              ),
              if (state.isBook && state.book != null) ...[
                const SizedBox(height: AppSpacing.lg),
                LinearProgressIndicator(
                  value: state.book!.readingProgress,
                  minHeight: 4,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${(state.book!.readingProgress * 100).toInt()}% read',
                  style: text.labelSmall.copyWith(
                    color: readerTheme.secondaryTextColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewReminderBanner extends StatelessWidget {
  const _ReviewReminderBanner({
    required this.onReview,
    required this.onDismiss,
  });

  final VoidCallback onReview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.school, size: AppIconSize.sm),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text('You have items to review'),
            ),
            TextButton(
              onPressed: onReview,
              child: const Text('Review'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: AppIconSize.sm),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
