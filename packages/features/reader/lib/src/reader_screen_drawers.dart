part of 'reader_screen.dart';

/// Collects TOC/bookmark state from [ReaderBloc] and feeds the drawer UI.
@visibleForTesting
class ReaderTocDrawerDriver extends StatelessWidget {
  const ReaderTocDrawerDriver({
    required this.loadThumbnail,
    required this.visible,
    required this.format,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.onClose,
    required this.onItemSelected,
    required this.onBookmarkSelected,
    required this.onHighlightSelected,
    required this.onBookmarkDeleted,
    super.key,
  });

  final ComicThumbnailLoader loadThumbnail;
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
      (b) => b.state.document?.readingProgress,
    );
    final currentChapterTitle = context.select<ReaderBloc, String?>(
      (b) => b.state.chapterTitle,
    );
    final colors = context.colors;

    return _ReaderTocDrawer(
      loadThumbnail: loadThumbnail,
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
    required this.loadThumbnail,
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

  final ComicThumbnailLoader loadThumbnail;
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
          offset: visible
              ? Offset.zero
              : readerSidePanelHiddenOffset(Directionality.of(context)),
          duration: context.motion(AppMotion.short),
          curve: _kChromeAnimCurve,
          child: Material(
            color: panelColor,
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: _ReaderTocDrawerContent(
                loadThumbnail: loadThumbnail,
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
    required this.loadThumbnail,
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

  final ComicThumbnailLoader loadThumbnail;
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
    final l10n = context.l10n;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.sm,
              readerDrawerActionEndPadding,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.readerContents,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
                AppPlainIconButton(
                  icon: AppIcons.close,
                  tooltip: l10n.commonClose,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              var width = 0.0;
              for (final label in [
                widget.format == BookFormat.cbz
                    ? l10n.readerPages
                    : l10n.readerChapters,
                l10n.readerBookmarks,
                l10n.readerHighlights,
              ]) {
                final painter = TextPainter(
                  text: TextSpan(text: label, style: context.text.labelSmall),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                width +=
                    painter.width +
                    AppIconSize.sm +
                    AppSpacing.xxs +
                    2 * AppSpacing.sm;
                painter.dispose();
              }
              final scrollable = width > constraints.maxWidth;
              return TabBar(
                isScrollable: scrollable,
                tabAlignment: scrollable
                    ? TabAlignment.start
                    : TabAlignment.fill,
                // Scrolling tabs start at the drawer gutter: 8dp bar inset
                // plus the 8dp label padding puts the first glyph on 16.
                padding: scrollable
                    ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm)
                    : null,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: scrollable ? AppSpacing.sm : 0,
                ),
                tabs: [
                  Tab(
                    child: _ReaderDrawerTabLabel(
                      icon: AppIcons.toc,
                      label: widget.format == BookFormat.cbz
                          ? l10n.readerPages
                          : l10n.readerChapters,
                    ),
                  ),
                  Tab(
                    child: _ReaderDrawerTabLabel(
                      icon: AppIcons.bookmark,
                      label: l10n.readerBookmarks,
                    ),
                  ),
                  Tab(
                    child: _ReaderDrawerTabLabel(
                      icon: AppIcons.highlight,
                      label: l10n.readerHighlights,
                    ),
                  ),
                ],
                labelColor: colors.onSurface,
                unselectedLabelColor: colors.onSurfaceVariant,
                indicatorColor: context.actionForeground,
              );
            },
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (widget.format == BookFormat.cbz)
                  Builder(
                    builder: (context) {
                      final tabs = DefaultTabController.of(context);
                      return AnimatedBuilder(
                        animation: tabs,
                        builder: (context, _) {
                          if (!widget.visible || tabs.index != 0) {
                            return const SizedBox.shrink();
                          }
                          return ReaderComicPages(
                            items: widget.tocItems,
                            pageProgressionRtl: widget.pageProgressionRtl,
                            currentIndex:
                                readerActiveTocIndex(
                                  items: widget.tocItems,
                                  readingProgress: widget.currentProgress,
                                  chapterTitle: widget.currentChapterTitle,
                                ) ??
                                0,
                            loadThumbnail: widget.loadThumbnail,
                            onSelected: widget.onItemSelected,
                          );
                        },
                      );
                    },
                  )
                else
                  _ReaderTocTab(
                    controller: _chaptersSearchController,
                    visible: widget.visible,
                    format: widget.format,
                    pageProgressionRtl: widget.pageProgressionRtl,
                    currentProgress: widget.currentProgress,
                    currentChapterTitle: widget.currentChapterTitle,
                    query: _chaptersQuery,
                    hintText: l10n.readerSearchChapters,
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
                Builder(
                  builder: (context) {
                    final tabs = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tabs,
                      builder: (context, _) => _ReaderHighlightsTab(
                        controller: _highlightsSearchController,
                        pageProgressionRtl: widget.pageProgressionRtl,
                        readerTheme: widget.readerTheme,
                        query: _highlightsQuery,
                        highlights: widget.highlights,
                        previewsEnabled:
                            widget.visible &&
                            tabs.index == 2 &&
                            widget.format == BookFormat.cbz,
                        loadThumbnail: widget.loadThumbnail,
                        onQueryChanged: (value) {
                          setState(() => _highlightsQuery = value);
                        },
                        onHighlightSelected: widget.onHighlightSelected,
                      ),
                    );
                  },
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
    final listBottomPadding = readerDrawerListBottomPadding(context);
    final filteredItems = _filteredItems();
    final activeSourceIndex = _activeSourceIndex();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SearchField(
            controller: widget.controller,
            hintText: widget.hintText,
            clearButtonSemanticsLabel: context.l10n.commonClearSearch,
            onChanged: widget.onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: filteredItems.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: widget.items.isEmpty
                        ? AppIcons.toc
                        : AppIcons.searchOff,
                    message: readerTocEmptyMessage(
                      l10n: context.l10n,
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
        AppSpacing.lg + (item.level - 1).clamp(0, 4) * AppSpacing.md;

    final titleColor = isActive
        ? colors.selectedControlForeground
        : colors.onSurface;

    // Row layout follows the app locale; only the chapter text keeps the
    // book's direction. The active fill spans the panel edge to edge: the
    // themed 16dp tile radius is for inset rows, not full-bleed panel rows.
    return ListTile(
      selected: isActive,
      selectedTileColor: colors.selectedControlBackground,
      shape: const RoundedRectangleBorder(),
      contentPadding: EdgeInsetsDirectional.only(
        start: levelInset.toDouble(),
        end: AppSpacing.lg,
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      title: Text(
        item.label.isEmpty ? context.l10n.readerUntitledChapter : item.label,
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

class _ReaderBookmarksTab extends StatefulWidget {
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
  State<_ReaderBookmarksTab> createState() => _ReaderBookmarksTabState();
}

class _ReaderBookmarksTabState extends State<_ReaderBookmarksTab> {
  List<SourceBookmark>? _bookmarks;
  List<SourceBookmark>? _removed;
  String? _query;
  List<SourceBookmark> _filtered = const [];
  Set<String> _removedIds = const {};

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = readerDrawerListBottomPadding(context);
    final edits = context.select<ReaderBloc, ReaderBookmarkEdits>(
      (b) => b.state.bookmarkEdits,
    );
    if (!identical(_bookmarks, widget.bookmarks) ||
        !identical(_removed, edits.removed) ||
        _query != widget.query) {
      _bookmarks = widget.bookmarks;
      _removed = edits.removed;
      _query = widget.query;
      _removedIds = edits.removed.map((b) => b.id).toSet();
      final items = [...widget.bookmarks, ...edits.removed]
        ..sort((a, b) {
          final progress = a.progress.compareTo(b.progress);
          return progress == 0 ? a.createdAt.compareTo(b.createdAt) : progress;
        });
      _filtered = filterReaderBookmarks(items, widget.query);
    }
    final hasItems = widget.bookmarks.isNotEmpty || edits.removed.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SearchField(
            controller: widget.controller,
            hintText: context.l10n.readerSearchBookmarks,
            clearButtonSemanticsLabel: context.l10n.commonClearSearch,
            onChanged: widget.onQueryChanged,
          ),
        ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: _filtered.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: !hasItems ? AppIcons.bookmark : AppIcons.searchOff,
                    message: !hasItems
                        ? context.l10n.readerNoBookmarksYet
                        : context.l10n.readerNoMatchingBookmarks,
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: listBottomPadding),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final bookmark = _filtered[index];
                        final removed = _removedIds.contains(bookmark.id);
                        return _ReaderBookmarkListTile(
                          bookmark: bookmark,
                          pageProgressionRtl: widget.pageProgressionRtl,
                          removed: removed,
                          failed: edits.failedId == bookmark.id,
                          onTap: removed
                              ? null
                              : () => widget.onBookmarkSelected(bookmark),
                          // Only the row being written disables its action;
                          // the bookmark event bucket serializes the rest.
                          onDelete: edits.busyId == bookmark.id
                              ? null
                              : () => widget.onBookmarkDeleted(bookmark),
                          onUndo: edits.busyId == bookmark.id
                              ? null
                              : () => context.read<ReaderBloc>().add(
                                  ReaderBookmarkRestored(
                                    sourceId: bookmark.sourceId,
                                    id: bookmark.id,
                                  ),
                                ),
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
    required this.onUndo,
    this.removed = false,
    this.failed = false,
  });

  final SourceBookmark bookmark;
  final bool pageProgressionRtl;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onUndo;
  final bool removed;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chapterTitle = bookmark.chapterTitle;
    final content = bookmark.content.trim();
    final percentage = (bookmark.progress * 100).clamp(0, 100).round();

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xxs,
        readerDrawerActionEndPadding,
        AppSpacing.xxs,
      ),
      minVerticalPadding: AppSpacing.xs,
      leading: Icon(
        AppIcons.bookmark,
        size: AppIconSize.sm,
        color: context.actionForeground,
      ),
      title: Text(
        content.isEmpty ? context.l10n.readerBookmarkedPage : content,
        textAlign: readerDirectionalTextAlign(
          pageProgressionRtl: pageProgressionRtl,
        ),
        textDirection: readerDirectionalTextDirection(
          pageProgressionRtl: pageProgressionRtl,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodyMedium.copyWith(
          color: removed ? colors.onSurfaceVariant : colors.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(
          [
            if (removed)
              context.l10n.readerBookmarkRemoved
            else ...[
              if (chapterTitle != null && chapterTitle.isNotEmpty) chapterTitle,
              '$percentage%',
            ],
            if (failed) context.l10n.readerBookmarkUpdateFailed,
          ].join(' · '),
          textAlign: readerDirectionalTextAlign(
            pageProgressionRtl: pageProgressionRtl,
          ),
          textDirection: readerDirectionalTextDirection(
            pageProgressionRtl: pageProgressionRtl,
          ),
          maxLines: failed ? null : 1,
          overflow: TextOverflow.ellipsis,
          strutStyle: StrutStyle.fromTextStyle(
            context.text.bodySmall,
            forceStrutHeight: true,
          ),
          style: context.text.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      trailing: SizedBox.square(
        dimension: AppSizes.buttonHeight,
        child: AppPlainIconButton(
          tooltip: removed
              ? context.l10n.commonUndo
              : context.l10n.readerDeleteBookmark,
          icon: removed ? AppIcons.undo : AppIcons.delete,
          color: removed ? context.actionForeground : colors.onSurfaceVariant,
          onPressed: removed ? onUndo : onDelete,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ReaderHighlightsTab extends StatefulWidget {
  const _ReaderHighlightsTab({
    required this.controller,
    required this.pageProgressionRtl,
    required this.readerTheme,
    required this.query,
    required this.highlights,
    required this.previewsEnabled,
    required this.loadThumbnail,
    required this.onQueryChanged,
    required this.onHighlightSelected,
  });

  final TextEditingController controller;
  final bool pageProgressionRtl;
  final ReaderThemeData readerTheme;
  final String query;
  final List<Highlight> highlights;
  final bool previewsEnabled;
  final ComicThumbnailLoader loadThumbnail;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Highlight> onHighlightSelected;

  @override
  State<_ReaderHighlightsTab> createState() => _ReaderHighlightsTabState();
}

class _ReaderHighlightsTabState extends State<_ReaderHighlightsTab>
    with AutomaticKeepAliveClientMixin<_ReaderHighlightsTab> {
  HighlightColor? _color;
  final _expanded = <String>{};
  late List<Highlight> _filtered;
  List<Highlight> _removed = const [];
  Set<String> _removedIds = const {};
  ReaderComicThumbnailCubit? _thumbnails;
  ReadflexLocalizations? _strings;

  // Preserve filters and note expansion, but release previews on inactive tabs.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.previewsEnabled) {
      _thumbnails = ReaderComicThumbnailCubit(widget.loadThumbnail);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strings = context.l10n;
    if (!identical(_strings, strings)) {
      _strings = strings;
      _filter();
    }
  }

  @override
  void didUpdateWidget(covariant _ReaderHighlightsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewsEnabled != widget.previewsEnabled) {
      final previous = _thumbnails;
      _thumbnails = widget.previewsEnabled
          ? ReaderComicThumbnailCubit(widget.loadThumbnail)
          : null;
      if (previous != null) unawaited(previous.close());
    }
    if (!identical(oldWidget.highlights, widget.highlights)) {
      final ids = widget.highlights.map((h) => h.id).toSet();
      _expanded.retainWhere(ids.contains);
    }
    if (!identical(oldWidget.highlights, widget.highlights) ||
        oldWidget.query != widget.query) {
      _filter();
    }
  }

  void _filter() {
    // Removed rows keep their place: the list is ordered by creation date.
    final items = _removed.isEmpty
        ? widget.highlights
        : ([...widget.highlights, ..._removed]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    _filtered = filterReaderHighlights(
      items,
      widget.query,
      color: _color,
      formatPage: _strings?.readerPageNumber,
    );
  }

  @override
  void dispose() {
    final thumbnails = _thumbnails;
    if (thumbnails != null) unawaited(thumbnails.close());
    super.dispose();
  }

  void _selectColor(HighlightColor? color) {
    if (_color == color) return;
    setState(() {
      _color = color;
      _filter();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final edits = context.select<ReaderBloc, ReaderHighlightEdits>(
      (b) => b.state.highlightEdits,
    );
    if (!identical(_removed, edits.removed)) {
      _removed = edits.removed;
      _removedIds = edits.removed.map((h) => h.id).toSet();
      _filter();
    }
    final hasItems = widget.highlights.isNotEmpty || _removed.isNotEmpty;
    return Column(
      // Stretch so the filter strip starts on the gutter instead of
      // centering its shrink-wrapped scroll view.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SearchField(
            controller: widget.controller,
            hintText: context.l10n.readerSearchHighlights,
            clearButtonSemanticsLabel: context.l10n.commonClearSearch,
            onChanged: widget.onQueryChanged,
          ),
        ),
        if (hasItems)
          _ReaderHighlightFilterStrip(
            readerTheme: widget.readerTheme,
            selected: _color,
            onSelected: _selectColor,
          ),
        Expanded(
          child: _ReaderDrawerContentFrame(
            child: _filtered.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: !hasItems ? AppIcons.highlight : AppIcons.searchOff,
                    message: !hasItems
                        ? context.l10n.readerNoHighlightsYet
                        : context.l10n.readerNoMatchingHighlights,
                  )
                : ScrollEdgeFadeStack(
                    child: ListView.builder(
                      // Keep the ordinary text-list prefetch; only image
                      // previews must wait until their rows are visible.
                      scrollCacheExtent: widget.previewsEnabled
                          ? const ScrollCacheExtent.pixels(0)
                          : null,
                      padding: EdgeInsets.only(
                        bottom: readerDrawerListBottomPadding(context),
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final highlight = _filtered[index];
                        final area = highlight.imageArea;
                        final thumbnails = _thumbnails;
                        final removed = _removedIds.contains(highlight.id);
                        return ReaderHighlightListTile(
                          key: ValueKey(highlight.id),
                          highlight: highlight,
                          pageProgressionRtl: widget.pageProgressionRtl,
                          readerTheme: widget.readerTheme,
                          removed: removed,
                          failed: edits.failedId == highlight.id,
                          onUndo: edits.busyId == highlight.id
                              ? null
                              : () => context.read<ReaderBloc>().add(
                                  ReaderHighlightRestored(
                                    highlightId: highlight.id,
                                  ),
                                ),
                          expanded: _expanded.contains(highlight.id),
                          onExpanded: () => setState(() {
                            _expanded.contains(highlight.id)
                                ? _expanded.remove(highlight.id)
                                : _expanded.add(highlight.id);
                          }),
                          onNavigate: () =>
                              widget.onHighlightSelected(highlight),
                          imagePreview:
                              area != null &&
                                  area.pageIndex >= 0 &&
                                  thumbnails != null
                              ? BlocProvider.value(
                                  value: thumbnails,
                                  child: ReaderImageHighlightPreview(
                                    area: area,
                                  ),
                                )
                              : null,
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

/// "All" chip plus one swatch per highlight color, scrolling horizontally.
///
/// Every control sits in a 48dp target; the 32dp swatch matches the chip
/// beside it. The strip owns the 16dp gutter and 8dp above/below the targets.
class _ReaderHighlightFilterStrip extends StatelessWidget {
  const _ReaderHighlightFilterStrip({
    required this.readerTheme,
    required this.selected,
    required this.onSelected,
  });

  final ReaderThemeData readerTheme;
  final HighlightColor? selected;
  final ValueChanged<HighlightColor?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppFilterChip(
            label: context.l10n.readerHighlightFilterAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.xs),
          for (final color in HighlightColor.values)
            ReaderHighlightColorButton(
              color: color,
              readerTheme: readerTheme,
              selected: selected == color,
              enabled: true,
              size: AppSizes.chipHeight,
              onPressed: () => onSelected(color),
            ),
        ],
      ),
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
