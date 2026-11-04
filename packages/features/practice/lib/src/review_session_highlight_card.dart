part of 'review_session_screen.dart';

/// A bounded reading card: the source stays fixed while quote and note scroll.
/// Its parent supplies finite maximum height and lets short content shrink.
class ReviewHighlightCard extends StatefulWidget {
  const ReviewHighlightCard({
    required this.item,
    this.onOpenInSource,
    super.key,
  });

  final PracticeHighlightItem item;
  final VoidCallback? onOpenInSource;

  @override
  State<ReviewHighlightCard> createState() => _ReviewHighlightCardState();
}

class _ReviewHighlightCardState extends State<ReviewHighlightCard> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(
        constraints.hasBoundedHeight,
        'ReviewHighlightCard requires a finite maximum height.',
      );
      final source = widget.item.source;
      final title = (source?.title ?? widget.item.sourceTitle)?.trim();
      var author = source?.author?.trim();
      if ((author == null || author.isEmpty) &&
          source?.sourceType == SourceType.article) {
        author = source?.sourceName?.trim();
      }
      final chapter = widget.item.highlight.chapterTitle?.trim();
      final note = widget.item.highlight.note?.trim();
      final quote = widget.item.highlight.text.trim();
      final denseHeight = constraints.maxHeight < AppSizes.buttonHeight * 6;
      final padding = denseHeight ? AppSpacing.lg : AppSpacing.xl;
      final compact =
          constraints.maxWidth - padding * 2 < 240 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.5;
      return DecoratedBox(
        key: const ValueKey('reviewStudyCard'),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLowest,
          border: Border.all(color: context.colors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ([title, author, chapter].any(
                    (value) => value?.isNotEmpty == true,
                  )) ...[
                    _ReviewHighlightSourceHeader(
                      key: const ValueKey('reviewLocation'),
                      source: source,
                      title: title,
                      author: author,
                      chapter: chapter,
                      denseHeight: denseHeight,
                      onOpenInSource: widget.onOpenInSource,
                    ),
                    SizedBox(
                      height: compact || denseHeight
                          ? AppSpacing.md
                          : AppSpacing.lg,
                    ),
                  ],
                  Flexible(
                    fit: FlexFit.loose,
                    child: ClipRect(
                      key: const ValueKey('reviewCardClip'),
                      child: Scrollbar(
                        key: const ValueKey('reviewHighlightScrollbar'),
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            scrollbars: false,
                          ),
                          child: SingleChildScrollView(
                            key: const ValueKey('reviewCardViewport'),
                            controller: _scrollController,
                            primary: false,
                            padding: const EdgeInsetsDirectional.only(
                              end: AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  quote,
                                  key: const ValueKey('reviewQuote'),
                                  textDirection: _directionOf(quote),
                                  style: AppTypography.serif(
                                    textStyle: context.text.bodyLarge,
                                    color: context.colors.onSurface,
                                    letterSpacing: 0,
                                  ),
                                ),
                                if (note != null && note.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xl),
                                  _ReviewHighlightNote(note: note),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ReviewHighlightSourceHeader extends StatelessWidget {
  const _ReviewHighlightSourceHeader({
    required this.source,
    required this.title,
    required this.author,
    required this.chapter,
    required this.denseHeight,
    required this.onOpenInSource,
    super.key,
  });

  final LibrarySource? source;
  final String? title;
  final String? author;
  final String? chapter;
  final bool denseHeight;
  final VoidCallback? onOpenInSource;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          denseHeight ||
          constraints.maxWidth < 240 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.5;
      final showCover = source != null && !compact;
      final content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showCover) ...[
              ExcludeSemantics(
                child: SizedBox(
                  key: const ValueKey('reviewSourceCover'),
                  width: 40,
                  height: 60,
                  child: PracticeSourceCover(source: source!),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: _ReviewHighlightSourceMetadata(
                title: title,
                author: author,
                chapter: chapter,
                compact: compact,
                denseHeight: denseHeight,
              ),
            ),
            if (onOpenInSource != null && !compact) ...[
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? AppIcons.chevronLeft
                      : AppIcons.chevronRight,
                  size: AppPlainIconButton.defaultIconSizeOf(context),
                  color: context.actionForeground,
                ),
              ),
            ],
          ],
        ),
      );
      final labels = [
        title,
        author,
        chapter,
      ].nonNulls.where((value) => value.isNotEmpty).toList();
      return Tooltip(
        message: labels.join('\n'),
        excludeFromSemantics: true,
        child: Semantics(
          button: onOpenInSource != null ? true : null,
          enabled: onOpenInSource != null ? true : null,
          label: labels.first,
          value: labels.skip(1).join(' · '),
          onTapHint: onOpenInSource != null
              ? context.l10n.practiceOpenInBook
              : null,
          onTap: onOpenInSource,
          excludeSemantics: true,
          child: onOpenInSource == null
              ? content
              : InkWell(
                  key: const ValueKey('reviewOpenInBook'),
                  onTap: onOpenInSource,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: content,
                ),
        ),
      );
    },
  );
}

class _ReviewHighlightSourceMetadata extends StatelessWidget {
  const _ReviewHighlightSourceMetadata({
    required this.title,
    required this.author,
    required this.chapter,
    required this.compact,
    required this.denseHeight,
  });

  final String? title;
  final String? author;
  final String? chapter;
  final bool compact;
  final bool denseHeight;

  @override
  Widget build(BuildContext context) {
    final details = [
      author,
      chapter,
    ].nonNulls.where((value) => value.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null && title!.isNotEmpty)
          Text(
            title!,
            key: const ValueKey('reviewSourceTitle'),
            textDirection: _directionOf(title!),
            maxLines: denseHeight ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.sourceListTitle.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        if (denseHeight && (title == null || title!.isEmpty))
          Text(
            details,
            key: const ValueKey('reviewSourceDetails'),
            textDirection: _directionOf(details),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.sourceListTitle.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        if (!denseHeight && compact && details.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            details,
            key: const ValueKey('reviewSourceDetails'),
            textDirection: _directionOf(details),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        if (!compact && author != null && author!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            author!,
            key: const ValueKey('reviewSourceAuthor'),
            textDirection: _directionOf(author!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        if (!compact && chapter != null && chapter!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            chapter!,
            key: const ValueKey('reviewSourceChapter'),
            textDirection: _directionOf(chapter!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewHighlightNote extends StatelessWidget {
  const _ReviewHighlightNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.readerHighlightNoteTitle,
            key: const ValueKey('reviewNoteTitle'),
            style: context.text.labelMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            note,
            key: const ValueKey('reviewNote'),
            textDirection: _directionOf(note),
            style: context.text.bodyMedium.copyWith(
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    ),
  );
}
