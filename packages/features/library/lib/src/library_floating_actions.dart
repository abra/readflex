import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_add_button.dart';
import 'library_bloc.dart';
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
    _mode = AnimationController(vsync: this, duration: AppMotion.quick)
      ..value = widget.searchActive ? 1 : 0
      ..addStatusListener(_onStatus);
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
      final targetWidth = widget.searchActive
          ? searchWidth
          : math.min(browseWidth, naturalBrowseWidth);
      final browse = _ModeLayer(
        key: const ValueKey('libraryBrowseModeLayer'),
        active: !widget.searchActive,
        opacity: _browseOpacity,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: kLibraryFloatingActionsMaxTextScale,
          child: _BrowseControls(
            scope: widget.searchActive ? _exitingScope : widget.scope,
            onCollectionsPressed: widget.onCollectionsPressed,
            onSearchPressed: widget.onSearchPressed,
            onAddPressed: widget.onAddPressed,
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
                onClose: widget.onSearchClosed!,
              )
            : LibrarySearchSnapshot(
                text: _searchSnapshot,
                scrollOffset: _searchSnapshotOffset,
              ),
      );
      // Key the direct Stack children so transition cleanup retains the live
      // editor and its native input connection.
      final browsePosition = Positioned.fill(
        key: const ValueKey('libraryBrowsePosition'),
        child: browse,
      );
      final searchPosition = Positioned.fill(
        key: const ValueKey('librarySearchPosition'),
        child: search,
      );
      final contents = Stack(
        fit: StackFit.expand,
        alignment: AlignmentDirectional.centerEnd,
        children: [
          if (widget.searchActive && _mode.value < 1) browsePosition,
          if (!widget.searchActive && _mode.value > 0) searchPosition,
          widget.searchActive ? searchPosition : browsePosition,
        ],
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
              width: targetWidth,
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
    required this.width,
    required this.reduceMotion,
    required this.child,
  });

  final double width;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_AnimatedCapsuleWidth> createState() => _AnimatedCapsuleWidthState();
}

class _AnimatedCapsuleWidthState extends State<_AnimatedCapsuleWidth>
    with SingleTickerProviderStateMixin {
  late final AnimationController _width;
  late double _begin;
  late double _end;

  double get _current =>
      _begin + (_end - _begin) * Curves.easeOutCubic.transform(_width.value);

  @override
  void initState() {
    super.initState();
    _begin = _end = widget.width;
    _width = AnimationController(vsync: this, duration: AppMotion.short)
      ..value = 1;
  }

  @override
  void didUpdateWidget(_AnimatedCapsuleWidth oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.width != oldWidget.width) {
      _begin = _current;
      _end = widget.width;
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
    animation: _width,
    child: widget.child,
    builder: (context, child) => SizedBox(width: _current, child: child),
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

class _BrowseControls extends StatelessWidget {
  const _BrowseControls({
    required this.scope,
    required this.onCollectionsPressed,
    required this.onSearchPressed,
    required this.onAddPressed,
  });

  final LibraryCollectionScope? scope;
  final VoidCallback onCollectionsPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Expanded(
        child: LibraryCollectionsButton(
          scope: scope,
          onPressed: onCollectionsPressed,
        ),
      ),
      AppPlainIconButton(
        key: const ValueKey('librarySearchButton'),
        tooltip: context.l10n.librarySearchHint,
        icon: AppIcons.search,
        onPressed: onSearchPressed,
      ),
      const SizedBox(width: _controlInset),
      LibraryAddButton(onPressed: onAddPressed),
    ],
  );
}
