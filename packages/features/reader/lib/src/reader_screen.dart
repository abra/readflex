import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:shared/shared.dart';

import 'reader_bloc.dart';

/// Approximate height of the context panel, used to offset the review banner.
const _kContextPanelHeight = 80.0;

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.serverPort,
    required this.bookRepository,
    required this.articleRepository,
    required this.highlightRepository,
    required this.textActions,
    this.onCheckDueItems,
    this.onStartMiniReview,
    super.key,
  });

  final String sourceId;
  final int serverPort;
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
        serverPort: serverPort,
        textActions: textActions,
        onCheckDueItems: onCheckDueItems,
        onStartMiniReview: onStartMiniReview,
      ),
    );
  }
}

class _ReaderView extends StatelessWidget {
  const _ReaderView({
    required this.serverPort,
    required this.textActions,
    this.onCheckDueItems,
    this.onStartMiniReview,
  });

  final int serverPort;
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
      body: BlocSelector<ReaderBloc, ReaderState, ReaderStatus>(
        selector: (state) => state.status,
        builder: (context, status) => _buildBody(context, status),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ReaderStatus status) {
    return switch (status) {
      ReaderStatus.initial || ReaderStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      ReaderStatus.failure => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, size: 48),
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
        sourceId: context.read<ReaderBloc>().state.sourceId!,
        serverPort: serverPort,
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

class _SelectionSlice {
  const _SelectionSlice({
    required this.hasSelection,
    required this.selectedText,
    this.sourceId,
    this.sourceType,
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
  });

  final bool hasSelection;
  final String selectedText;
  final String? sourceId;
  final SourceType? sourceType;
  final String? cfiRange;
  final int? pageNumber;
  final double? scrollOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SelectionSlice &&
          hasSelection == other.hasSelection &&
          selectedText == other.selectedText &&
          sourceId == other.sourceId &&
          sourceType == other.sourceType &&
          cfiRange == other.cfiRange &&
          pageNumber == other.pageNumber &&
          scrollOffset == other.scrollOffset;

  @override
  int get hashCode => Object.hash(
    hasSelection,
    selectedText,
    sourceId,
    sourceType,
    cfiRange,
    pageNumber,
    scrollOffset,
  );
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
              icon: const Icon(AppIcons.highlight),
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
    required this.sourceId,
    required this.serverPort,
    required this.textActions,
    this.onCheckDueItems,
    this.onStartMiniReview,
  });

  final String sourceId;
  final int serverPort;
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

    final sourceId = widget.sourceId;

    _checkDueItems(onCheck, sourceId);

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

  Widget _buildReaderBody(BuildContext context, ReaderThemeData readerTheme) {
    final state = context.read<ReaderBloc>().state;
    final bloc = context.read<ReaderBloc>();
    final highlights = state.highlights
        .map(
          (h) => ReaderHighlight(
            id: h.id,
            text: h.text,
            cfiRange: h.cfiRange,
          ),
        )
        .toList();

    final articleStyle = ReaderStyle(
      textColor: _colorToHex(readerTheme.primaryTextColor),
      bgColor: _colorToHex(readerTheme.backgroundColor),
      accentColor: _colorToHex(readerTheme.accentColor),
      secondaryColor: _colorToHex(readerTheme.secondaryTextColor),
      dividerColor: _colorToHex(readerTheme.dividerColor),
    );

    if (state.isArticle) {
      return ArticleReaderWebView(
        key: ValueKey(state.article?.id),
        serverPort: widget.serverPort,
        articleId: state.article!.id,
        initialScrollFraction: state.article?.currentScrollOffset,
        style: articleStyle,
        highlights: highlights,
        onPositionChanged: (fraction) {
          bloc.add(
            ReaderPositionUpdated(
              scrollOffset: fraction,
              progress: fraction,
            ),
          );
        },
        onTextSelected: (selection) {
          bloc.add(
            ReaderTextSelected(
              selectedText: selection.text,
              scrollOffset: selection.scrollOffset,
            ),
          );
        },
        onTextDeselected: () {
          bloc.add(const ReaderTextDeselected());
        },
      );
    }

    return BookReaderWebView(
      key: ValueKey(state.book?.id),
      serverPort: widget.serverPort,
      bookFilePath: state.book!.filePath,
      initialCfi: state.book?.currentCfi,
      foliateStyle: FoliateStyle(
        fontColor: _colorToHex(readerTheme.primaryTextColor),
        backgroundColor: _colorToHex(readerTheme.backgroundColor),
      ),
      highlights: highlights,
      onPositionChanged: (position) {
        bloc.add(
          ReaderPositionUpdated(
            cfi: position.cfi,
            progress: position.fraction,
          ),
        );
      },
      onTextSelected: (selection) {
        bloc.add(
          ReaderTextSelected(
            selectedText: selection.text,
            cfiRange: selection.cfiRange,
          ),
        );
      },
      onTextDeselected: () {
        bloc.add(const ReaderTextDeselected());
      },
    );
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appearance = PreferencesScope.readerAppearanceOf(context);
    final readerTheme = ReaderThemePreset.fromId(appearance.themeId).data;

    return Stack(
      children: [
        // WebView body — reads BLoC state once, not subscribed to changes.
        // Only rebuilds on theme change (PreferencesScope), never on
        // selection or review-reminder state changes.
        ColoredBox(
          color: readerTheme.backgroundColor,
          child: _buildReaderBody(context, readerTheme),
        ),

        // Context panel — rebuilds only when selection state changes
        BlocSelector<ReaderBloc, ReaderState, _SelectionSlice>(
          selector: (state) => _SelectionSlice(
            hasSelection: state.hasSelection,
            selectedText: state.selectedText,
            sourceId: state.sourceId,
            sourceType: state.sourceType,
            cfiRange: state.selectionCfiRange,
            pageNumber: state.selectionPageNumber,
            scrollOffset: state.selectionScrollOffset,
          ),
          builder: (context, sel) {
            if (!sel.hasSelection ||
                sel.sourceId == null ||
                sel.sourceType == null) {
              return const SizedBox.shrink();
            }
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ContextPanel(
                selectedText: sel.selectedText,
                sourceId: sel.sourceId!,
                sourceType: sel.sourceType!,
                selectionCfiRange: sel.cfiRange,
                selectionPageNumber: sel.pageNumber,
                selectionScrollOffset: sel.scrollOffset,
                textActions: widget.textActions,
                panelColor: readerTheme.panelColor,
                iconColor: readerTheme.primaryTextColor,
                dividerColor: readerTheme.dividerColor,
              ),
            );
          },
        ),

        // Review reminder banner — rebuilds only when reminder state changes
        BlocSelector<ReaderBloc, ReaderState, (bool, bool, String?)>(
          selector: (state) => (
            state.showReviewReminder,
            state.hasSelection,
            state.sourceId,
          ),
          builder: (context, data) {
            final (show, hasSelection, sourceId) = data;
            if (!show) return const SizedBox.shrink();
            return Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: hasSelection ? _kContextPanelHeight : AppSpacing.md,
              child: _ReviewReminderBanner(
                onReview: () {
                  context.read<ReaderBloc>().add(
                    const ReaderReviewReminderDismissed(),
                  );
                  if (sourceId != null) {
                    widget.onStartMiniReview?.call(context, sourceId);
                  }
                },
                onDismiss: () {
                  context.read<ReaderBloc>().add(
                    const ReaderReviewReminderDismissed(),
                  );
                },
              ),
            );
          },
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
            const Icon(AppIcons.practice, size: AppIconSize.sm),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text('You have items to review'),
            ),
            TextButton(
              onPressed: onReview,
              child: const Text('Review'),
            ),
            IconButton(
              icon: const Icon(AppIcons.close, size: AppIconSize.sm),
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
