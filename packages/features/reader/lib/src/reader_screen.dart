import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:shared/shared.dart';

import 'reader_bloc.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.bookRepository,
    required this.articleRepository,
    required this.highlightRepository,
    required this.textActions,
    super.key,
  });

  final String sourceId;
  final BookRepository bookRepository;
  final ArticleRepository articleRepository;
  final HighlightRepository highlightRepository;
  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReaderBloc(
        bookRepository: bookRepository,
        articleRepository: articleRepository,
        highlightRepository: highlightRepository,
      )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
      child: _ReaderView(textActions: textActions),
    );
  }
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({required this.textActions});

  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    final preferences = PreferencesScope.of(context);
    final readerTheme = ReaderThemePreset.fromId(preferences.readerThemeId).data;
    final readerFont = ReaderFontPreset.fromId(preferences.readerFontId);

    return BlocBuilder<ReaderBloc, ReaderState>(
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: _buildBody(
            context,
            state,
            preferences,
            readerTheme,
            readerFont,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ReaderState state) {
    return AppBar(
      title: Text(
        state.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (state.highlights.isNotEmpty)
          Badge(
            label: Text('${state.highlights.length}'),
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

  Widget _buildBody(
    BuildContext context,
    ReaderState state,
    Preferences preferences,
    ReaderThemeData readerTheme,
    ReaderFontPreset readerFont,
  ) {
    return switch (state.status) {
      ReaderStatus.initial || ReaderStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      ReaderStatus.failure => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: Spacing.medium),
            const Text('Failed to load content'),
            const SizedBox(height: Spacing.medium),
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
        preferences: preferences,
        readerTheme: readerTheme,
        readerFont: readerFont,
      ),
    };
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.state,
    required this.textActions,
    required this.preferences,
    required this.readerTheme,
    required this.readerFont,
  });

  final ReaderState state;
  final List<TextAction> textActions;
  final Preferences preferences;
  final ReaderThemeData readerTheme;
  final ReaderFontPreset readerFont;

  @override
  Widget build(BuildContext context) {
    final readerTextStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontFamily: readerFont.fontFamily,
      fontSize:
          Theme.of(context).textTheme.bodyLarge!.fontSize! *
          preferences.readerTextScale,
      height: preferences.readerLineHeight,
      color: readerTheme.primaryTextColor,
    );

    return Stack(
      children: [
        // TODO: replace placeholder with WebView (foliate-js / flutter_inappwebview).
        ColoredBox(
          color: readerTheme.backgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xLarge),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: readerTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: readerTheme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xLarge,
                      vertical: Spacing.xxLarge,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.isBook ? Icons.menu_book : Icons.article,
                          size: 48,
                          color: readerTheme.accentColor,
                        ),
                        const SizedBox(height: Spacing.mediumLarge),
                        Text(
                          state.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: readerTheme.primaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.mediumLarge),
                        Text(
                          state.isBook
                              ? 'This is where the book content will be rendered. The final reader should inherit the selected reading theme, font and typography settings.'
                              : 'This is where the article content will be rendered. The final reader should inherit the selected reading theme, font and typography settings.',
                          style: readerTextStyle,
                          textAlign: TextAlign.start,
                        ),
                        if (state.isBook && state.book != null) ...[
                          const SizedBox(height: Spacing.large),
                          LinearProgressIndicator(
                            value: state.book!.readingProgress,
                            minHeight: 4,
                          ),
                          const SizedBox(height: Spacing.small),
                          Text(
                            '${(state.book!.readingProgress * 100).toInt()}% read',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: readerTheme.secondaryTextColor,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
              textActions: textActions,
              panelColor: readerTheme.panelColor,
              iconColor: readerTheme.primaryTextColor,
              dividerColor: readerTheme.dividerColor,
            ),
          ),

        // Review reminder banner
        if (state.showReviewReminder)
          Positioned(
            left: Spacing.medium,
            right: Spacing.medium,
            bottom: state.hasSelection ? 80 : Spacing.medium,
            child: _ReviewReminderBanner(
              onReview: () {
                // TODO: start mini review session as overlay.
              },
              onDismiss: () {
                context.read<ReaderBloc>().add(
                  const ReaderReviewReminderDismissed(),
                );
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
              horizontal: Spacing.medium,
              vertical: Spacing.small,
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
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Row(
          children: [
            const Icon(Icons.school, size: 20),
            const SizedBox(width: Spacing.small),
            const Expanded(
              child: Text('You have items to review'),
            ),
            TextButton(
              onPressed: onReview,
              child: const Text('Review'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
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
