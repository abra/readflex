part of 'reader_screen.dart';

/// Collects TOC/bookmark state from [ReaderBloc] and feeds the drawer UI.
class _ReaderTocDrawerDriver extends StatelessWidget {
  const _ReaderTocDrawerDriver({
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
    required this.onHighlightSelected,
    required this.onBookmarkDeleted,
  });

  final bool visible;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<Highlight> onHighlightSelected;
  final ValueChanged<SourceBookmark> onBookmarkDeleted;

  @override
  Widget build(BuildContext context) {
    final tocItems = context.select<ReaderBloc, List<ReaderTocItem>>(
      (b) => b.state.tocItems,
    );
    final bookmarks = context.select<ReaderBloc, List<SourceBookmark>>(
      (b) => b.state.bookmarks,
    );
    final highlights = context.select<ReaderBloc, List<Highlight>>(
      (b) => b.state.highlights,
    );
    final currentProgress = context.select<ReaderBloc, double?>(
      (b) => b.state.book?.readingProgress,
    );
    final currentChapterTitle = context.select<ReaderBloc, String?>(
      (b) => b.state.chapterTitle,
    );
    final colors = context.colors;

    return _ReaderTocDrawer(
      visible: visible,
      format: format,
      pageProgressionRtl: pageProgressionRtl,
      readerTheme: readerTheme,
      tocItems: tocItems,
      bookmarks: bookmarks,
      highlights: highlights,
      currentProgress: currentProgress,
      currentChapterTitle: currentChapterTitle,
      panelColor: colors.surface,
      dividerColor: colors.outlineVariant,
      onClose: onClose,
      onItemSelected: onItemSelected,
      onBookmarkSelected: onBookmarkSelected,
      onHighlightSelected: onHighlightSelected,
      onBookmarkDeleted: onBookmarkDeleted,
    );
  }
}

/// Sliding full-height drawer that hosts chapter and bookmark tabs.
class _ReaderTocDrawer extends StatelessWidget {
  const _ReaderTocDrawer({
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.tocItems,
    required this.bookmarks,
    required this.highlights,
    required this.currentProgress,
    required this.currentChapterTitle,
    required this.panelColor,
    required this.dividerColor,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
    required this.onHighlightSelected,
    required this.onBookmarkDeleted,
  });

  final bool visible;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final List<ReaderTocItem> tocItems;
  final List<SourceBookmark> bookmarks;
  final List<Highlight> highlights;
  final double? currentProgress;
  final String? currentChapterTitle;
  final Color panelColor;
  final Color dividerColor;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<Highlight> onHighlightSelected;
  final ValueChanged<SourceBookmark> onBookmarkDeleted;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(-1, 0),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: Material(
            color: panelColor,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: _ReaderTocDrawerContent(
                format: format,
                visible: visible,
                pageProgressionRtl: pageProgressionRtl,
                readerTheme: readerTheme,
                tocItems: tocItems,
                bookmarks: bookmarks,
                highlights: highlights,
                currentProgress: currentProgress,
                currentChapterTitle: currentChapterTitle,
                onClose: onClose,
                onItemSelected: onItemSelected,
                onBookmarkSelected: onBookmarkSelected,
                onHighlightSelected: onHighlightSelected,
                onBookmarkDeleted: onBookmarkDeleted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stateful drawer body because chapter and bookmark searches keep separate
/// local text controllers.
class _ReaderTocDrawerContent extends StatefulWidget {
  const _ReaderTocDrawerContent({
    required this.format,
    required this.visible,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.tocItems,
    required this.bookmarks,
    required this.highlights,
    required this.currentProgress,
    required this.currentChapterTitle,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
    required this.onHighlightSelected,
    required this.onBookmarkDeleted,
  });

  final BookFormat? format;
  final bool visible;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final List<ReaderTocItem> tocItems;
  final List<SourceBookmark> bookmarks;
  final List<Highlight> highlights;
  final double? currentProgress;
  final String? currentChapterTitle;
  final VoidCallback onClose;
  final ValueChanged<ReaderTocItem> onItemSelected;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<Highlight> onHighlightSelected;
  final ValueChanged<SourceBookmark> onBookmarkDeleted;

  @override
  State<_ReaderTocDrawerContent> createState() =>
      _ReaderTocDrawerContentState();
}

class _ReaderTocDrawerContentState extends State<_ReaderTocDrawerContent> {
  final _chaptersSearchController = TextEditingController();
  final _bookmarksSearchController = TextEditingController();
  final _highlightsSearchController = TextEditingController();
  String _chaptersQuery = '';
  String _bookmarksQuery = '';
  String _highlightsQuery = '';

  @override
  void dispose() {
    _chaptersSearchController.dispose();
    _bookmarksSearchController.dispose();
    _highlightsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Contents',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.close, size: AppIconSize.md),
                  tooltip: 'Close',
                  style: _readerDrawerCloseButtonStyle,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          TabBar(
            labelPadding: EdgeInsets.zero,
            tabs: const [
              Tab(
                child: _ReaderDrawerTabLabel(
                  icon: AppIcons.toc,
                  label: 'Chapters',
                ),
              ),
              Tab(
                child: _ReaderDrawerTabLabel(
                  icon: AppIcons.bookmark,
                  label: 'Bookmarks',
                ),
              ),
              Tab(
                child: _ReaderDrawerTabLabel(
                  icon: AppIcons.highlight,
                  label: 'Highlights',
                ),
              ),
            ],
            labelColor: colors.onSurface,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ReaderTocTab(
                  controller: _chaptersSearchController,
                  visible: widget.visible,
                  format: widget.format,
                  pageProgressionRtl: widget.pageProgressionRtl,
                  currentProgress: widget.currentProgress,
                  currentChapterTitle: widget.currentChapterTitle,
                  query: _chaptersQuery,
                  hintText: 'Search chapters',
                  items: widget.tocItems,
                  onQueryChanged: (value) {
                    setState(() => _chaptersQuery = value);
                  },
                  onItemSelected: widget.onItemSelected,
                ),
                _ReaderBookmarksTab(
                  controller: _bookmarksSearchController,
                  pageProgressionRtl: widget.pageProgressionRtl,
                  query: _bookmarksQuery,
                  bookmarks: widget.bookmarks,
                  onQueryChanged: (value) {
                    setState(() => _bookmarksQuery = value);
                  },
                  onBookmarkSelected: widget.onBookmarkSelected,
                  onBookmarkDeleted: widget.onBookmarkDeleted,
                ),
                _ReaderHighlightsTab(
                  controller: _highlightsSearchController,
                  pageProgressionRtl: widget.pageProgressionRtl,
                  readerTheme: widget.readerTheme,
                  query: _highlightsQuery,
                  highlights: widget.highlights,
                  onQueryChanged: (value) {
                    setState(() => _highlightsQuery = value);
                  },
                  onHighlightSelected: widget.onHighlightSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderDrawerTabLabel extends StatelessWidget {
  const _ReaderDrawerTabLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppIconSize.sm),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: context.text.labelSmall,
          ),
        ),
      ],
    );
  }
}

/// Searchable chapter/bookmark tab that auto-scrolls to the active item when
/// the drawer opens.
class _ReaderTocTab extends StatefulWidget {
  const _ReaderTocTab({
    required this.controller,
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.currentProgress,
    required this.currentChapterTitle,
    required this.query,
    required this.hintText,
    required this.items,
    required this.onQueryChanged,
    required this.onItemSelected,
  });

  final TextEditingController controller;
  final bool visible;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final double? currentProgress;
  final String? currentChapterTitle;
  final String query;
  final String hintText;
  final List<ReaderTocItem> items;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ReaderTocItem> onItemSelected;

  @override
  State<_ReaderTocTab> createState() => _ReaderTocTabState();
}

class _ReaderTocTabState extends State<_ReaderTocTab> {
  final _scrollController = ScrollController();
  final _activeItemKey = GlobalKey();
  bool _autoScrolledForOpen = false;
  bool _autoScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _scheduleAutoScrollToActiveItem();
  }

  @override
  void didUpdateWidget(covariant _ReaderTocTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) {
      _autoScrolledForOpen = false;
      _autoScrollScheduled = false;
      return;
    }

    final becameVisible = widget.visible && !oldWidget.visible;
    final activeInputsChanged =
        oldWidget.items != widget.items ||
        oldWidget.currentProgress != widget.currentProgress ||
        oldWidget.currentChapterTitle != widget.currentChapterTitle ||
        oldWidget.query != widget.query;
    if (becameVisible || (!_autoScrolledForOpen && activeInputsChanged)) {
      _scheduleAutoScrollToActiveItem();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<({int sourceIndex, ReaderTocItem item})> _filteredItems() {
    final normalizedQuery = widget.query.trim().toLowerCase();
    return [
      for (var index = 0; index < widget.items.length; index += 1)
        if (normalizedQuery.isEmpty ||
            widget.items[index].label.toLowerCase().contains(normalizedQuery))
          (sourceIndex: index, item: widget.items[index]),
    ];
  }

  int? _activeSourceIndex() {
    return readerActiveTocIndex(
      items: widget.items,
      readingProgress: widget.currentProgress,
      chapterTitle: widget.currentChapterTitle,
    );
  }

  int? _activeFilteredIndex(
    List<({int sourceIndex, ReaderTocItem item})> filteredItems,
    int? activeSourceIndex,
  ) {
    if (activeSourceIndex == null) return null;
    final index = filteredItems.indexWhere(
      (entry) => entry.sourceIndex == activeSourceIndex,
    );
    return index == -1 ? null : index;
  }

  void _scheduleAutoScrollToActiveItem() {
    if (_autoScrolledForOpen ||
        _autoScrollScheduled ||
        widget.query.trim().isNotEmpty) {
      return;
    }
    final filteredItems = _filteredItems();
    final activeFilteredIndex = _activeFilteredIndex(
      filteredItems,
      _activeSourceIndex(),
    );
    if (activeFilteredIndex == null) return;

    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      _autoScrolledForOpen = true;

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final targetOffset =
          (activeFilteredIndex * _kReaderTocTileEstimatedHeight - AppSpacing.lg)
              .clamp(0.0, maxScrollExtent)
              .toDouble();
      _scrollController.jumpTo(targetOffset);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = _activeItemKey.currentContext;
        if (context == null) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.25,
          duration: Duration.zero,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = _readerDrawerListBottomPadding(context);
    final filteredItems = _filteredItems();
    final activeSourceIndex = _activeSourceIndex();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchField(
            controller: widget.controller,
            hintText: widget.hintText,
            onChanged: widget.onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: filteredItems.isEmpty
                ? _ReaderDrawerEmptyState(
                    icon: widget.items.isEmpty
                        ? AppIcons.toc
                        : AppIcons.searchOff,
                    message: readerTocEmptyMessage(
                      format: widget.format,
                      hasSourceItems: widget.items.isNotEmpty,
                    ),
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final entry = filteredItems[index];
                        final isActive = entry.sourceIndex == activeSourceIndex;
                        return _ReaderTocListTile(
                          key: isActive ? _activeItemKey : null,
                          item: entry.item,
                          pageProgressionRtl: widget.pageProgressionRtl,
                          isActive: isActive,
                          onTap: () => widget.onItemSelected(entry.item),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReaderTocListTile extends StatelessWidget {
  const _ReaderTocListTile({
    super.key,
    required this.item,
    required this.pageProgressionRtl,
    required this.isActive,
    required this.onTap,
  });

  final ReaderTocItem item;
  final bool pageProgressionRtl;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final levelInset =
        AppSpacing.md + (item.level - 1).clamp(0, 4) * AppSpacing.md;

    final titleColor = isActive ? colors.primary : colors.onSurface;

    return ListTile(
      selected: isActive,
      selectedTileColor: colors.primary.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: readerDirectionalContentPadding(
        pageProgressionRtl: pageProgressionRtl,
        start: levelInset.toDouble(),
        end: AppSpacing.md,
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      title: Text(
        item.label.isEmpty ? 'Untitled chapter' : item.label,
        textAlign: readerDirectionalTextAlign(
          pageProgressionRtl: pageProgressionRtl,
        ),
        textDirection: readerDirectionalTextDirection(
          pageProgressionRtl: pageProgressionRtl,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium.copyWith(color: titleColor),
      ),
      onTap: onTap,
    );
  }
}

class _ReaderBookmarksTab extends StatelessWidget {
  const _ReaderBookmarksTab({
    required this.controller,
    required this.pageProgressionRtl,
    required this.query,
    required this.bookmarks,
    required this.onQueryChanged,
    required this.onBookmarkSelected,
    required this.onBookmarkDeleted,
  });

  final TextEditingController controller;
  final bool pageProgressionRtl;
  final String query;
  final List<SourceBookmark> bookmarks;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SourceBookmark> onBookmarkSelected;
  final ValueChanged<SourceBookmark> onBookmarkDeleted;

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = _readerDrawerListBottomPadding(context);
    final filteredBookmarks = filterReaderBookmarks(bookmarks, query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchField(
            controller: controller,
            hintText: 'Search bookmarks',
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: filteredBookmarks.isEmpty
                ? _ReaderDrawerEmptyState(
                    icon: bookmarks.isEmpty
                        ? AppIcons.bookmark
                        : AppIcons.searchOff,
                    message: bookmarks.isEmpty
                        ? 'No bookmarks yet'
                        : 'No matching bookmarks',
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: filteredBookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = filteredBookmarks[index];
                        return _ReaderBookmarkListTile(
                          bookmark: bookmark,
                          pageProgressionRtl: pageProgressionRtl,
                          onTap: () => onBookmarkSelected(bookmark),
                          onDelete: () => onBookmarkDeleted(bookmark),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReaderBookmarkListTile extends StatelessWidget {
  const _ReaderBookmarkListTile({
    required this.bookmark,
    required this.pageProgressionRtl,
    required this.onTap,
    required this.onDelete,
  });

  final SourceBookmark bookmark;
  final bool pageProgressionRtl;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chapterTitle = bookmark.chapterTitle;
    final content = bookmark.content.trim();
    final percentage = (bookmark.progress * 100).clamp(0, 100).round();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      leading: Icon(
        AppIcons.bookmark,
        size: AppIconSize.sm,
        color: colors.primary,
      ),
      title: Text(
        content.isEmpty ? 'Bookmarked page' : content,
        textAlign: readerDirectionalTextAlign(
          pageProgressionRtl: pageProgressionRtl,
        ),
        textDirection: readerDirectionalTextDirection(
          pageProgressionRtl: pageProgressionRtl,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium.copyWith(color: colors.onSurface),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(
          [
            if (chapterTitle != null && chapterTitle.isNotEmpty) chapterTitle,
            '$percentage%',
          ].join(' · '),
          textAlign: readerDirectionalTextAlign(
            pageProgressionRtl: pageProgressionRtl,
          ),
          textDirection: readerDirectionalTextDirection(
            pageProgressionRtl: pageProgressionRtl,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete bookmark',
        visualDensity: VisualDensity.compact,
        style: _readerDrawerCloseButtonStyle,
        icon: Icon(
          AppIcons.close,
          size: AppIconSize.xs,
          color: colors.onSurfaceVariant,
        ),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _ReaderHighlightsTab extends StatelessWidget {
  const _ReaderHighlightsTab({
    required this.controller,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.query,
    required this.highlights,
    required this.onQueryChanged,
    required this.onHighlightSelected,
  });

  final TextEditingController controller;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final String query;
  final List<Highlight> highlights;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Highlight> onHighlightSelected;

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = _readerDrawerListBottomPadding(context);
    final filteredHighlights = filterReaderHighlights(highlights, query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchField(
            controller: controller,
            hintText: 'Search highlights',
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: filteredHighlights.isEmpty
                ? _ReaderDrawerEmptyState(
                    icon: highlights.isEmpty
                        ? AppIcons.highlight
                        : AppIcons.searchOff,
                    message: highlights.isEmpty
                        ? 'No highlights yet'
                        : 'No matching highlights',
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: filteredHighlights.length,
                      itemBuilder: (context, index) {
                        final highlight = filteredHighlights[index];
                        return _ReaderHighlightListTile(
                          highlight: highlight,
                          pageProgressionRtl: pageProgressionRtl,
                          readerTheme: readerTheme,
                          onTap: () => onHighlightSelected(highlight),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReaderHighlightListTile extends StatelessWidget {
  const _ReaderHighlightListTile({
    required this.highlight,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.onTap,
  });

  final Highlight highlight;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = highlight.text.trim();
    final note = highlight.note?.trim();
    final hasLocation = readerHighlightHasNavigableLocation(highlight);
    final locationLabel = readerHighlightLocationLabel(highlight);
    final subtitle = [
      if (note != null && note.isNotEmpty) note,
      ?locationLabel,
      if (!hasLocation) 'Location unavailable',
    ].join(' · ');

    return ListTile(
      enabled: hasLocation,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      leading: _ReaderHighlightColorDot(
        color: readerHighlightColor(highlight.color, readerTheme),
      ),
      title: Text(
        text.isEmpty ? 'Highlighted text' : text,
        textAlign: readerDirectionalTextAlign(
          pageProgressionRtl: pageProgressionRtl,
        ),
        textDirection: readerDirectionalTextDirection(
          pageProgressionRtl: pageProgressionRtl,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium.copyWith(
          color: hasLocation ? colors.onSurface : colors.onSurfaceVariant,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                subtitle,
                textAlign: readerDirectionalTextAlign(
                  pageProgressionRtl: pageProgressionRtl,
                ),
                textDirection: readerDirectionalTextDirection(
                  pageProgressionRtl: pageProgressionRtl,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
      onTap: hasLocation ? onTap : null,
    );
  }
}

class _ReaderHighlightColorDot extends StatelessWidget {
  const _ReaderHighlightColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: context.colors.onSurface.withValues(alpha: 0.16),
        ),
      ),
      child: const SizedBox.square(dimension: 18),
    );
  }
}

/// Sliding drawer dedicated to full-text search inside the current book.
class _ReaderSearchDrawer extends StatelessWidget {
  const _ReaderSearchDrawer({
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.onClose,
    required this.onSearch,
    required this.onClearSearch,
    required this.onResultSelected,
  });

  final bool visible;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final VoidCallback onClose;
  final Stream<ReaderSearchEvent> Function(String query) onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(-1, 0),
          duration: _kChromeAnimDuration,
          curve: _kChromeAnimCurve,
          child: Material(
            color: colors.surface,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: _ReaderSearchDrawerContent(
                visible: visible,
                format: format,
                pageProgressionRtl: pageProgressionRtl,
                onClose: onClose,
                onSearch: onSearch,
                onClearSearch: onClearSearch,
                onResultSelected: onResultSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns the search field focus/controller and resets search state when hidden.
class _ReaderSearchDrawerContent extends StatefulWidget {
  const _ReaderSearchDrawerContent({
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.onClose,
    required this.onSearch,
    required this.onClearSearch,
    required this.onResultSelected,
  });

  final bool visible;
  final BookFormat? format;
  final bool pageProgressionRtl;
  final VoidCallback onClose;
  final Stream<ReaderSearchEvent> Function(String query) onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<ReaderSearchResult> onResultSelected;

  @override
  State<_ReaderSearchDrawerContent> createState() =>
      _ReaderSearchDrawerContentState();
}

class _ReaderSearchDrawerContentState
    extends State<_ReaderSearchDrawerContent> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _ReaderSearchDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.visible && oldWidget.visible) {
      _focusNode.unfocus();
      _controller.clear();
      context.read<ReaderSearchCubit>().reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    context.read<ReaderSearchCubit>().queryChanged(
      value,
      searchBook: widget.onSearch,
    );
  }

  void _selectRecentQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focusNode.requestFocus();
    context.read<ReaderSearchCubit>().recentQuerySelected(
      query,
      searchBook: widget.onSearch,
    );
  }

  void _removeRecentQuery(String query) {
    context.read<ReaderSearchCubit>().recentQueryRemoved(query);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listBottomPadding = _readerDrawerListBottomPadding(context);

    return BlocListener<ReaderSearchCubit, ReaderSearchState>(
      listenWhen: (previous, current) =>
          previous.clearSearchToken != current.clearSearchToken,
      listener: (_, _) => widget.onClearSearch(),
      child: BlocBuilder<ReaderSearchCubit, ReaderSearchState>(
        builder: (context, state) {
          final query = state.query.trim();
          final canSearch = query.length >= ReaderSearchCubit.minQueryLength;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Search',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.close, size: AppIconSize.md),
                      tooltip: 'Close',
                      style: _readerDrawerCloseButtonStyle,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: 'Search in book',
                  onChanged: _onQueryChanged,
                ),
              ),
              if (state.isLoading)
                LinearProgressIndicator(
                  minHeight: 2,
                  value: state.progress > 0 && state.progress < 1
                      ? state.progress
                      : null,
                ),
              Expanded(
                child: _ReaderDrawerContentFrame(
                  child: state.errorMessage != null
                      ? _ReaderDrawerEmptyState(message: state.errorMessage!)
                      : !canSearch
                      ? query.isEmpty && state.recentQueries.isNotEmpty
                            ? _ReaderRecentSearchesList(
                                queries: state.recentQueries,
                                pageProgressionRtl: widget.pageProgressionRtl,
                                bottomPadding: listBottomPadding,
                                onQuerySelected: _selectRecentQuery,
                                onQueryRemoved: _removeRecentQuery,
                              )
                            : _ReaderDrawerEmptyState(
                                message: readerSearchPromptMessage(
                                  widget.format,
                                ),
                              )
                      : state.results.isEmpty && !state.isLoading
                      ? const _ReaderDrawerEmptyState(
                          message: 'No results found',
                        )
                      : ScrollEdgeFadeStack(
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: listBottomPadding,
                            ),
                            itemCount: state.results.length,
                            itemBuilder: (context, index) {
                              final result = state.results[index];
                              return _ReaderSearchResultTile(
                                result: result,
                                pageProgressionRtl: widget.pageProgressionRtl,
                                onTap: () => widget.onResultSelected(result),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderRecentSearchesList extends StatelessWidget {
  const _ReaderRecentSearchesList({
    required this.queries,
    required this.pageProgressionRtl,
    required this.bottomPadding,
    required this.onQuerySelected,
    required this.onQueryRemoved,
  });

  final List<String> queries;
  final bool pageProgressionRtl;
  final double bottomPadding;
  final ValueChanged<String> onQuerySelected;
  final ValueChanged<String> onQueryRemoved;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ScrollEdgeFadeStack(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: queries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                'Recent searches',
                style: context.text.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          }

          final query = queries[index - 1];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            minVerticalPadding: AppSpacing.xs,
            leading: Icon(
              AppIcons.clock,
              size: AppIconSize.xs,
              color: colors.onSurfaceVariant,
            ),
            title: Text(
              query,
              textAlign: readerDirectionalTextAlign(
                pageProgressionRtl: pageProgressionRtl,
              ),
              textDirection: readerDirectionalTextDirection(
                pageProgressionRtl: pageProgressionRtl,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(AppIcons.close, size: AppIconSize.xs),
              tooltip: 'Remove from history',
              style: _readerDrawerCloseButtonStyle,
              onPressed: () => onQueryRemoved(query),
            ),
            onTap: () => onQuerySelected(query),
          );
        },
      ),
    );
  }
}

class _ReaderSearchResultTile extends StatelessWidget {
  const _ReaderSearchResultTile({
    required this.result,
    required this.pageProgressionRtl,
    required this.onTap,
  });

  final ReaderSearchResult result;
  final bool pageProgressionRtl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chapterTitle = result.chapterTitle;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      title: Text(
        chapterTitle == null || chapterTitle.isEmpty
            ? 'Search result'
            : chapterTitle,
        textAlign: readerDirectionalTextAlign(
          pageProgressionRtl: pageProgressionRtl,
        ),
        textDirection: readerDirectionalTextDirection(
          pageProgressionRtl: pageProgressionRtl,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: RichText(
          textAlign: readerDirectionalTextAlign(
            pageProgressionRtl: pageProgressionRtl,
          ),
          textDirection: readerDirectionalTextDirection(
            pageProgressionRtl: pageProgressionRtl,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: context.text.bodyMedium.copyWith(color: colors.onSurface),
            children: [
              TextSpan(text: result.excerpt.pre),
              TextSpan(
                text: result.excerpt.match,
                style: context.text.bodyMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: result.excerpt.post),
            ],
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Shared padding/frame wrapper for drawer tab bodies.
class _ReaderDrawerContentFrame extends StatelessWidget {
  const _ReaderDrawerContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.hardEdge,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: context.colors.outlineVariant,
              width: 1 / MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Compact empty-state message used inside reader drawers.
class _ReaderDrawerEmptyState extends StatelessWidget {
  const _ReaderDrawerEmptyState({
    required this.message,
    this.icon,
  });

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppIconSize.lg,
                color: colors.onSurfaceVariant.withValues(alpha: 0.72),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
