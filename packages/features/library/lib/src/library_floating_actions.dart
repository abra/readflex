import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'library_capsule_action_button.dart';
import 'library_collections_button.dart';
import 'library_layout.dart';
import 'library_practice_button.dart';
import 'library_search_controls.dart';

const double _controlInset =
    (kLibraryFloatingActionsHeight - AppSizes.buttonHeight) / 2;
const double _searchMaxWidth = 480;

/// A persistent bottom surface for browsing or editing search. Animation state
/// stays local; the screen supplies the query, focus and navigation callbacks.
class LibraryFloatingActions extends StatefulWidget {
  const LibraryFloatingActions({
    required this.scope,
    required this.onCollectionsPressed,
    required this.onSearchPressed,
    required this.onAddPressed,
    this.searchActive = false,
    this.horizontalViewPadding = 0,
    this.searchController,
    this.searchFocusNode,
    this.canRequestSearchFocus = true,
    this.onSearchChanged,
    this.onSearchClosed,
    this.practiceDue = 0,
    this.onPracticePressed,
    super.key,
  }) : assert(
         !searchActive ||
             (searchController != null &&
                 searchFocusNode != null &&
                 onSearchChanged != null &&
                 onSearchClosed != null),
       );

  final LibraryCollectionScope? scope;
  final VoidCallback onCollectionsPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback? onAddPressed;
  final bool searchActive;

  /// Original side safe insets, before the Scaffold strips them from this slot.
  final double horizontalViewPadding;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final bool canRequestSearchFocus;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClosed;
  final int practiceDue;
  final VoidCallback? onPracticePressed;

  @override
  State<LibraryFloatingActions> createState() => _LibraryFloatingActionsState();
}

class _LibraryFloatingActionsState extends State<LibraryFloatingActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mode;
  late final CurvedAnimation _progress;
  late final CurvedAnimation _searchOpacity;
  late final CurvedAnimation _browseProgress;
  late final Animation<double> _browseOpacity;
  LibraryCollectionScope? _exitingScope;
  String _searchSnapshot = '';
  double _searchSnapshotOffset = 0;
  final _searchScrollController = ScrollController(keepScrollOffset: false);
  bool _captureScheduled = false;
  bool _synchronizing = false;

  @override
  void initState() {
    super.initState();
    _mode = AnimationController(vsync: this, duration: AppMotion.short)
      ..value = widget.searchActive ? 1 : 0
      ..addStatusListener(_onStatus);
    _progress = CurvedAnimation(parent: _mode, curve: Curves.easeInOutCubic);
    _searchOpacity = CurvedAnimation(
      parent: _mode,
      curve: const Interval(.5, 1, curve: Curves.easeInOutCubic),
    );
    _browseProgress = CurvedAnimation(
      parent: _mode,
      curve: const Interval(0, .5, curve: Curves.easeInOutCubic),
    );
    _browseOpacity = ReverseAnimation(_browseProgress);
    _exitingScope = widget.scope;
    _searchSnapshot = widget.searchController?.text ?? '';
    widget.searchController?.addListener(_captureSearch);
    _searchScrollController.addListener(_captureSearch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) _synchronize();
  }

  @override
  void didUpdateWidget(LibraryFloatingActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_captureSearch);
      widget.searchController?.addListener(_captureSearch);
      _searchSnapshot = widget.searchController?.text ?? '';
    }
    if (widget.searchActive != oldWidget.searchActive) {
      if (widget.searchActive) {
        _exitingScope = oldWidget.scope;
        _searchSnapshot = widget.searchController?.text ?? '';
        _searchSnapshotOffset = 0;
      }
      _synchronize();
    }
  }

  void _synchronize() {
    _synchronizing = true;
    try {
      if (context.reduceMotion) {
        _mode.value = widget.searchActive ? 1 : 0;
      } else if (widget.searchActive) {
        _mode.forward();
      } else {
        _mode.reverse();
      }
    } finally {
      _synchronizing = false;
    }
  }

  void _onStatus(AnimationStatus status) {
    if (!_synchronizing &&
        (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed)) {
      setState(() {});
    }
  }

  void _captureSearch() {
    if (_captureScheduled) return;
    _captureScheduled = true;
    // Remember the last painted query before Close clears the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (mounted && widget.searchActive) {
        _searchSnapshot = widget.searchController?.text ?? '';
        _searchSnapshotOffset = _searchScrollController.hasClients
            ? _searchScrollController.offset
            : 0;
      }
    });
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_captureSearch);
    _mode.removeStatusListener(_onStatus);
    _searchOpacity.dispose();
    _browseProgress.dispose();
    _progress.dispose();
    _mode.dispose();
    _searchScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = math.max(
        0.0,
        constraints.maxWidth - AppSpacing.lg * 2 - widget.horizontalViewPadding,
      );
      final browseWidth = math.min(kLibraryFloatingActionsMaxWidth, available);
      final searchWidth = math.min(_searchMaxWidth, available);
      final naturalBrowseWidth =
          LibraryCollectionsButton.naturalWidthOf(
            context,
            widget.searchActive ? _exitingScope : widget.scope,
            textScaler: MediaQuery.textScalerOf(context).clamp(
              maxScaleFactor: kLibraryFloatingActionsMaxTextScale,
            ),
          ) +
          AppSizes.buttonHeight * 2 +
          _controlInset * 3;
      final browse = _ModeLayer(
        key: const ValueKey('libraryBrowseModeLayer'),
        active: !widget.searchActive,
        opacity: _browseOpacity,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: kLibraryFloatingActionsMaxTextScale,
          child: LibraryCollectionsButton(
            scope: widget.searchActive ? _exitingScope : widget.scope,
            onPressed: widget.onCollectionsPressed,
          ),
        ),
      );
      final search = _ModeLayer(
        key: const ValueKey('librarySearchModeLayer'),
        active: widget.searchActive,
        opacity: _searchOpacity,
        child: widget.searchActive
            ? LibrarySearchControls(
                controller: widget.searchController!,
                focusNode: widget.searchFocusNode!,
                canRequestFocus: widget.canRequestSearchFocus,
                scrollController: _searchScrollController,
                onChanged: widget.onSearchChanged!,
              )
            : LibrarySearchSnapshot(
                text: _searchSnapshot,
                scrollOffset: _searchSnapshotOffset,
              ),
      );
      final contents = _CapsuleContents(
        progress: _progress,
        browse: browse,
        search: search,
        searchButton: IgnorePointer(
          ignoring: widget.searchActive,
          child: ExcludeFocus(
            excluding: widget.searchActive,
            child: ExcludeSemantics(
              excluding: widget.searchActive,
              child: AppPlainIconButton(
                key: const ValueKey('librarySearchButton'),
                tooltip: context.l10n.librarySearchHint,
                icon: AppIcons.search,
                onPressed: widget.onSearchPressed,
              ),
            ),
          ),
        ),
        // Close must finish returning to "+" before another tap can import.
        action: IgnorePointer(
          ignoring: !widget.searchActive && !_mode.isDismissed,
          child: ExcludeFocus(
            excluding: !widget.searchActive && !_mode.isDismissed,
            child: ExcludeSemantics(
              excluding: !widget.searchActive && !_mode.isDismissed,
              child: LibraryCapsuleActionButton(
                progress: _progress,
                searchActive: widget.searchActive,
                onAddPressed: widget.onAddPressed,
                onSearchClosed: widget.onSearchClosed,
              ),
            ),
          ),
        ),
      );
      final onPracticePressed = widget.onPracticePressed;
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: searchWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.searchActive &&
                onPracticePressed != null &&
                widget.practiceDue > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: _controlInset,
                  bottom: kLibraryPracticeActionGap,
                ),
                child: LibraryPracticeButton(
                  due: widget.practiceDue,
                  onPressed: onPracticePressed,
                ),
              ),
            _AnimatedCapsuleWidth(
              browseWidth: math.min(browseWidth, naturalBrowseWidth),
              searchWidth: searchWidth,
              progress: _progress,
              reduceMotion: context.reduceMotion,
              child: AppFloatingCapsule(
                key: const ValueKey('libraryFloatingActions'),
                height: kLibraryFloatingActionsHeight,
                child: Padding(
                  padding: const EdgeInsets.all(_controlInset),
                  child: contents,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AnimatedCapsuleWidth extends StatefulWidget {
  const _AnimatedCapsuleWidth({
    required this.browseWidth,
    required this.searchWidth,
    required this.progress,
    required this.reduceMotion,
    required this.child,
  });

  final double browseWidth;
  final double searchWidth;
  final Animation<double> progress;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_AnimatedCapsuleWidth> createState() => _AnimatedCapsuleWidthState();
}

class _AnimatedCapsuleWidthState extends State<_AnimatedCapsuleWidth>
    with SingleTickerProviderStateMixin {
  late final AnimationController _width;
  late double _browseBegin;
  late double _browseEnd;
  late double _searchBegin;
  late double _searchEnd;

  double get _resizeProgress => Curves.easeOutCubic.transform(_width.value);
  double get _browseWidth =>
      _browseBegin + (_browseEnd - _browseBegin) * _resizeProgress;
  double get _searchWidth =>
      _searchBegin + (_searchEnd - _searchBegin) * _resizeProgress;

  @override
  void initState() {
    super.initState();
    _browseBegin = _browseEnd = widget.browseWidth;
    _searchBegin = _searchEnd = widget.searchWidth;
    _width = AnimationController(vsync: this, duration: AppMotion.short)
      ..value = 1;
  }

  @override
  void didUpdateWidget(_AnimatedCapsuleWidth oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.browseWidth != oldWidget.browseWidth ||
        widget.searchWidth != oldWidget.searchWidth) {
      _browseBegin = _browseWidth;
      _searchBegin = _searchWidth;
      _browseEnd = widget.browseWidth;
      _searchEnd = widget.searchWidth;
      if (widget.reduceMotion) {
        _width.value = 1;
      } else {
        _width.forward(from: 0);
      }
    } else if (widget.reduceMotion) {
      _width.value = 1;
    }
  }

  @override
  void dispose() {
    _width.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_width, widget.progress]),
    child: widget.child,
    builder: (context, child) => SizedBox(
      width:
          _browseWidth + (_searchWidth - _browseWidth) * widget.progress.value,
      child: child,
    ),
  );
}

class _ModeLayer extends StatelessWidget {
  const _ModeLayer({
    required this.active,
    required this.opacity,
    required this.child,
    super.key,
  });

  final bool active;
  final Animation<double> opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !active,
    child: ExcludeFocus(
      excluding: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: FadeTransition(opacity: opacity, child: child),
      ),
    ),
  );
}

/// Only geometry changes per frame; controls and the live editor stay mounted.
class _CapsuleContents extends StatelessWidget {
  const _CapsuleContents({
    required this.progress,
    required this.browse,
    required this.search,
    required this.searchButton,
    required this.action,
  });

  final Animation<double> progress;
  final Widget browse;
  final Widget search;
  final Widget searchButton;
  final Widget action;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        const fieldStart = AppSizes.buttonHeight;
        const fieldEnd = AppSizes.buttonHeight + _controlInset;
        final collectionWidth = math.max(
          0.0,
          constraints.maxWidth - fieldStart - fieldEnd,
        );
        final iconStart = collectionWidth * (1 - progress.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              key: const ValueKey('libraryBrowsePosition'),
              start: 0,
              end: fieldStart + fieldEnd,
              top: 0,
              bottom: 0,
              child: ClipRect(
                clipper: _LeadingRevealClipper(
                  extent: iconStart,
                  direction: Directionality.of(context),
                ),
                child: browse,
              ),
            ),
            PositionedDirectional(
              key: const ValueKey('librarySearchPosition'),
              start: fieldStart,
              end: fieldEnd,
              top: 0,
              bottom: 0,
              child: ClipRect(
                clipper: _LeadingRevealClipper(
                  extent: iconStart,
                  direction: Directionality.of(context),
                  revealTrailing: true,
                ),
                child: search,
              ),
            ),
            PositionedDirectional(
              start: iconStart,
              top: 0,
              bottom: 0,
              width: AppSizes.buttonHeight,
              child: searchButton,
            ),
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: AppSizes.buttonHeight,
              child: action,
            ),
          ],
        );
      },
    ),
  );
}

/// The moving magnifier separates the collection and editor paint regions.
class _LeadingRevealClipper extends CustomClipper<Rect> {
  const _LeadingRevealClipper({
    required this.extent,
    required this.direction,
    this.revealTrailing = false,
  });

  final double extent;
  final TextDirection direction;
  final bool revealTrailing;

  @override
  Rect getClip(Size size) {
    final edge = extent.clamp(0.0, size.width);
    final ltr = direction == TextDirection.ltr;
    if (revealTrailing) {
      return Rect.fromLTWH(ltr ? edge : 0, 0, size.width - edge, size.height);
    }
    return Rect.fromLTWH(ltr ? 0 : size.width - edge, 0, edge, size.height);
  }

  @override
  bool shouldReclip(_LeadingRevealClipper oldClipper) =>
      extent != oldClipper.extent ||
      direction != oldClipper.direction ||
      revealTrailing != oldClipper.revealTrailing;
}
