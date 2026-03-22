import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
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
    return BlocBuilder<ReaderBloc, ReaderState>(
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: _buildBody(context, state),
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
                // TODO: show highlights list
              },
            ),
          ),
      ],
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
      ),
    };
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.state,
    required this.textActions,
  });

  final ReaderState state;
  final List<TextAction> textActions;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content area — placeholder for WebView
        Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isBook ? Icons.menu_book : Icons.article,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: Spacing.medium),
                Text(
                  state.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.small),
                Text(
                  state.isBook
                      ? 'Book reader (WebView) will render here'
                      : 'Article reader (WebView) will render here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (state.isBook && state.book != null) ...[
                  const SizedBox(height: Spacing.small),
                  LinearProgressIndicator(
                    value: state.book!.readingProgress,
                  ),
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    '${(state.book!.readingProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
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
                // TODO: start mini review session
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
    this.selectionCfiRange,
    this.selectionPageNumber,
    this.selectionScrollOffset,
  });

  final String selectedText;
  final String sourceId;
  final SourceType sourceType;
  final List<TextAction> textActions;
  final String? selectionCfiRange;
  final int? selectionPageNumber;
  final double? selectionScrollOffset;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: textActions.map((action) {
              return IconButton(
                icon: Icon(action.icon),
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
