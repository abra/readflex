import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_bloc.dart';
import 'manage_collection_cubit.dart';

enum ManageCollectionSheetResult { deleted }

enum _ManageCollectionStep { manage, confirmDelete }

/// Source currently being animated out of the collection list.
///
/// Keeps the original list count stable while the removal animation runs.
class _RemovingCollectionSource {
  const _RemovingCollectionSource({
    required this.id,
    required this.initialSourceCount,
  });

  final String id;
  final int initialSourceCount;
}

const double _collectionSourcesMaxHeight = 260;
const double _collectionSourceRowHeightEstimate = 57;
const double _emptyCollectionListHeightEstimate = 56;
const double _manageCollectionHeaderHeightEstimate = 48;
const double _manageCollectionTextFieldHeightEstimate = 56;
const double _manageCollectionCountLabelHeightEstimate = 18;
const double _manageCollectionActionsHeightEstimate = 56;
const double _manageCollectionDeleteBodyHeightEstimate = 88;
const double _manageCollectionManageMinStepHeight = 336;
const double _manageCollectionDeleteMinStepHeight = 224;
const double _manageCollectionViewportTopReserve = 96;
const Duration _manageCollectionTransitionDuration = Duration(
  milliseconds: 300,
);
const Duration _collectionSourceRemovalDuration = Duration(milliseconds: 260);
const EdgeInsets _sheetHorizontalPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.xl,
);
const EdgeInsets _sheetActionsPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  0,
  AppSpacing.xl,
  AppSpacing.lg,
);

Future<ManageCollectionSheetResult?> showManageCollectionSheet({
  required BuildContext context,
  required ManageCollectionCubit cubit,
  required LibraryCollectionScope scope,
  required List<LibrarySource> sources,
  required VoidCallback onCollectionChanged,
}) {
  return showAppBottomSheet<ManageCollectionSheetResult>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ManageCollectionSheet(
        scope: scope,
        sources: sources,
        onCollectionChanged: onCollectionChanged,
      ),
    ),
  );
}

/// Stateful collection-management sheet. Owns staged source removals and
/// rename/delete step transitions before saving to [ManageCollectionCubit].
class _ManageCollectionSheet extends StatefulWidget {
  const _ManageCollectionSheet({
    required this.scope,
    required this.sources,
    required this.onCollectionChanged,
  });

  final LibraryCollectionScope scope;
  final List<LibrarySource> sources;
  final VoidCallback onCollectionChanged;

  @override
  State<_ManageCollectionSheet> createState() => _ManageCollectionSheetState();
}

class _ManageCollectionSheetState extends State<_ManageCollectionSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final AnimationController _sourceRemovalController;
  late final List<LibrarySource> _displayedSources;
  late String _currentName;
  final _removedSourceIds = <String>{};
  _RemovingCollectionSource? _removingSource;
  var _animateNextSizeChange = false;
  var _step = _ManageCollectionStep.manage;

  @override
  void initState() {
    super.initState();
    _currentName = widget.scope.label;
    _displayedSources = widget.sources.toList(growable: true);
    _sourceRemovalController = AnimationController(
      vsync: this,
      duration: _collectionSourceRemovalDuration,
    );
    _nameController = TextEditingController(text: _currentName)
      ..addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _sourceRemovalController.dispose();
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  void _showDeleteConfirmation() {
    setState(() {
      _animateNextSizeChange = true;
      _step = _ManageCollectionStep.confirmDelete;
    });
  }

  void _cancelDeleteConfirmation() {
    setState(() {
      _animateNextSizeChange = true;
      _step = _ManageCollectionStep.manage;
    });
  }

  Future<void> _saveChanges() async {
    final canRename = widget.scope.canRename;
    final name = canRename ? _nameController.text.trim() : _currentName;
    final hasNameChange = canRename && name != _currentName;
    if ((canRename && name.isEmpty) ||
        (!hasNameChange && _removedSourceIds.isEmpty)) {
      return;
    }

    final cubit = context.read<ManageCollectionCubit>();
    final saved = await cubit.saveChanges(
      collectionId: widget.scope.id,
      name: hasNameChange ? name : null,
      removedSourceIds: _removedSourceIds.toSet(),
    );
    if (!mounted || !saved) return;
    setState(() => _currentName = name);
    widget.onCollectionChanged();
    Navigator.of(context).pop();
  }

  void _stageSourceRemoval(LibrarySource source) {
    if (_removedSourceIds.contains(source.id) || _removingSource != null) {
      return;
    }
    final index = _displayedSources.indexWhere((item) => item.id == source.id);
    if (index == -1) return;

    _removedSourceIds.add(source.id);
    setState(() {
      _removingSource = _RemovingCollectionSource(
        id: source.id,
        initialSourceCount: _displayedSources.length,
      );
    });

    _sourceRemovalController.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted || _removingSource?.id != source.id) return;
      setState(() {
        _displayedSources.removeWhere((item) => item.id == source.id);
        _removingSource = null;
        _sourceRemovalController.reset();
      });
    });
  }

  Future<void> _deleteCollection() async {
    if (!widget.scope.canDelete) return;
    final cubit = context.read<ManageCollectionCubit>();
    final deleted = await cubit.deleteCollection(widget.scope.id);
    if (!mounted || !deleted) return;
    widget.onCollectionChanged();
    Navigator.of(context).pop(ManageCollectionSheetResult.deleted);
  }

  double _stepHeight(
    BuildContext context,
    _ManageCollectionStep step,
    int sourceCount,
  ) {
    final sourceListHeight = sourceCount == 0
        ? _emptyCollectionListHeightEstimate
        : (sourceCount * _collectionSourceRowHeightEstimate)
              .clamp(0.0, _collectionSourcesMaxHeight)
              .toDouble();
    final renameHeight = widget.scope.canRename
        ? _manageCollectionTextFieldHeightEstimate + AppSpacing.lg
        : 0.0;
    final manageHeight =
        _manageCollectionHeaderHeightEstimate +
        AppSpacing.lg +
        renameHeight +
        _manageCollectionCountLabelHeightEstimate +
        AppSpacing.md +
        sourceListHeight +
        AppSpacing.lg +
        _manageCollectionActionsHeightEstimate;
    final deleteHeight =
        _manageCollectionHeaderHeightEstimate +
        AppSpacing.lg +
        _manageCollectionDeleteBodyHeightEstimate +
        AppSpacing.lg +
        _manageCollectionActionsHeightEstimate;
    final viewportLimit =
        MediaQuery.sizeOf(context).height - _manageCollectionViewportTopReserve;
    final minHeight = switch (step) {
      _ManageCollectionStep.manage => _manageCollectionManageMinStepHeight,
      _ManageCollectionStep.confirmDelete =>
        _manageCollectionDeleteMinStepHeight,
    };
    final maxHeight = viewportLimit < minHeight ? minHeight : viewportLimit;
    final preferredHeight = switch (step) {
      _ManageCollectionStep.manage => manageHeight,
      _ManageCollectionStep.confirmDelete => deleteHeight,
    };
    return preferredHeight.clamp(minHeight, maxHeight).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ManageCollectionCubit, ManageCollectionState>(
      builder: (context, state) {
        return AnimatedBuilder(
          animation: _sourceRemovalController,
          builder: (context, _) => _buildSheet(context, state),
        );
      },
    );
  }

  Widget _buildSheet(BuildContext context, ManageCollectionState state) {
    final visibleSources = List<LibrarySource>.unmodifiable(_displayedSources);
    final canRename = widget.scope.canRename;
    final name = canRename ? _nameController.text.trim() : _currentName;
    final canSave =
        !state.isBusy &&
        (!canRename || name.isNotEmpty) &&
        ((canRename && name != _currentName) || _removedSourceIds.isNotEmpty);

    final stepHeight = _currentStepHeight(context, visibleSources.length);
    final sizeDuration = _animateNextSizeChange
        ? _manageCollectionTransitionDuration
        : Duration.zero;
    if (_animateNextSizeChange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateNextSizeChange = false;
      });
    }

    final child = switch (_step) {
      _ManageCollectionStep.manage => _ManageCollectionStepView(
        key: const ValueKey('manageCollectionContent'),
        title: 'Manage collection',
        child: _ManageCollectionContent(
          state: state,
          nameController: _nameController,
          visibleSources: visibleSources,
          removingSourceId: _removingSource?.id,
          removalProgress: _sourceRemovalController.value,
          canRename: widget.scope.canRename,
          canDelete: widget.scope.canDelete,
          canSave: canSave,
          onSave: _saveChanges,
          onRemoveSource: _stageSourceRemoval,
          onDeletePressed: _showDeleteConfirmation,
        ),
      ),
      _ManageCollectionStep.confirmDelete => _ManageCollectionStepView(
        key: const ValueKey('deleteCollectionContent'),
        title: 'Delete collection?',
        child: _DeleteCollectionConfirmationContent(
          state: state,
          collectionName: _currentName,
          onCancel: _cancelDeleteConfirmation,
          onDelete: _deleteCollection,
        ),
      ),
    };

    final sheetBody = SizedBox(
      height: stepHeight,
      child: _ManageCollectionStepSwitcher(
        step: _step,
        height: stepHeight,
        child: child,
      ),
    );
    if (sizeDuration == Duration.zero) return sheetBody;

    return AnimatedSize(
      duration: sizeDuration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.bottomCenter,
      child: sheetBody,
    );
  }

  double _currentStepHeight(BuildContext context, int visibleSourceCount) {
    final removal = _removingSource;
    if (_step != _ManageCollectionStep.manage || removal == null) {
      return _stepHeight(context, _step, visibleSourceCount);
    }

    final startHeight = _stepHeight(
      context,
      _ManageCollectionStep.manage,
      removal.initialSourceCount,
    );
    final endHeight = _stepHeight(
      context,
      _ManageCollectionStep.manage,
      removal.initialSourceCount - 1,
    );
    return startHeight +
        (endHeight - startHeight) * _sourceRemovalController.value;
  }
}

/// Animated step switcher for the manage/delete-confirmation sheet flow.
class _ManageCollectionStepSwitcher extends StatefulWidget {
  const _ManageCollectionStepSwitcher({
    required this.step,
    required this.height,
    required this.child,
  });

  final _ManageCollectionStep step;
  final double height;
  final Widget child;

  @override
  State<_ManageCollectionStepSwitcher> createState() =>
      _ManageCollectionStepSwitcherState();
}

class _ManageCollectionStepSwitcherState
    extends State<_ManageCollectionStepSwitcher> {
  var _slideDirection = 1;
  double? _previousHeight;

  @override
  void didUpdateWidget(covariant _ManageCollectionStepSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _slideDirection = _transitionDirection(oldWidget.step, widget.step);
      _previousHeight = oldWidget.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _manageCollectionTransitionDuration,
      reverseDuration: _manageCollectionTransitionDuration,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        final previousHeight = _previousHeight ?? widget.height;
        return ClipRect(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              for (final child in previousChildren)
                _StepHeightSlot(height: previousHeight, child: child),
              if (currentChild != null)
                _StepHeightSlot(height: widget.height, child: currentChild),
            ],
          ),
        );
      },
      transitionBuilder: (child, animation) {
        return _ManageCollectionSlideTransition(
          animation: animation,
          direction: _slideDirection,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Pins an outgoing/incoming step to a known height while the sheet animates.
class _StepHeightSlot extends StatelessWidget {
  const _StepHeightSlot({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The current and outgoing steps keep their own heights while
    // AnimatedSize changes the sheet height around them.
    return OverflowBox(
      alignment: Alignment.bottomCenter,
      minHeight: height,
      maxHeight: height,
      child: SizedBox(height: height, child: child),
    );
  }
}

/// Directional slide transition between manage collection steps.
class _ManageCollectionSlideTransition extends StatelessWidget {
  const _ManageCollectionSlideTransition({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = Curves.easeInOutCubic.transform(animation.value);
        final isExiting = animation.status == AnimationStatus.reverse;
        final sign = isExiting ? -direction : direction;
        return FractionalTranslation(
          translation: Offset(sign * (1 - value), 0),
          child: child,
        );
      },
    );
  }
}

int _transitionDirection(
  _ManageCollectionStep from,
  _ManageCollectionStep to,
) {
  final fromDepth = _navigationDepth(from);
  final toDepth = _navigationDepth(to);
  return toDepth < fromDepth ? -1 : 1;
}

int _navigationDepth(_ManageCollectionStep step) {
  return switch (step) {
    _ManageCollectionStep.manage => 0,
    _ManageCollectionStep.confirmDelete => 1,
  };
}

/// Shared step frame with a bottom-sheet header and expandable body.
class _ManageCollectionStepView extends StatelessWidget {
  const _ManageCollectionStepView({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: _sheetHorizontalPadding,
            child: BottomSheetHeader(title: title),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Main collection edit step: rename, remove sources, save, or enter delete
/// confirmation.
class _ManageCollectionContent extends StatelessWidget {
  const _ManageCollectionContent({
    required this.state,
    required this.nameController,
    required this.visibleSources,
    required this.removingSourceId,
    required this.removalProgress,
    required this.canRename,
    required this.canDelete,
    required this.canSave,
    required this.onSave,
    required this.onRemoveSource,
    required this.onDeletePressed,
  });

  final ManageCollectionState state;
  final TextEditingController nameController;
  final List<LibrarySource> visibleSources;
  final String? removingSourceId;
  final double removalProgress;
  final bool canRename;
  final bool canDelete;
  final bool canSave;
  final Future<void> Function() onSave;
  final ValueChanged<LibrarySource> onRemoveSource;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null) ...[
          Padding(
            padding: _sheetHorizontalPadding,
            child: Text(
              state.errorMessage!,
              style: context.text.bodyMedium.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (canRename) ...[
          Padding(
            padding: _sheetHorizontalPadding,
            child: TextField(
              controller: nameController,
              enabled: !state.isBusy,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(),
              onSubmitted: (_) => canSave ? onSave() : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Padding(
          padding: _sheetHorizontalPadding,
          child: Text(
            _sourceCountLabel(visibleSources),
            style: context.text.labelSmall.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _CollectionSourcesList(
            visibleSources: visibleSources,
            removingSourceId: removingSourceId,
            removalProgress: removalProgress,
            enabled: !state.isBusy,
            onRemoveSource: onRemoveSource,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: _sheetActionsPadding,
          child: canDelete
              ? Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.error,
                          foregroundColor: context.colors.onError,
                        ),
                        onPressed: state.isBusy ? null : onDeletePressed,
                        child: const Text('Delete collection'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: canSave ? onSave : null,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                )
              : FilledButton(
                  onPressed: canSave ? onSave : null,
                  child: const Text('Save'),
                ),
        ),
      ],
    );
  }

  String _sourceCountLabel(List<LibrarySource> sources) {
    var books = 0;
    var articles = 0;
    for (final source in sources) {
      switch (source.sourceType) {
        case SourceType.book:
          books++;
          break;
        case SourceType.article:
          articles++;
          break;
      }
    }

    final parts = [
      if (books > 0) _pluralize(books, 'book'),
      if (articles > 0) _pluralize(articles, 'article'),
    ];
    return parts.isEmpty ? '0 books/articles' : parts.join(', ');
  }

  String _pluralize(int count, String singular) {
    return count == 1 ? '$count $singular' : '$count ${singular}s';
  }
}

/// Scrollable list of sources currently displayed inside the collection.
class _CollectionSourcesList extends StatelessWidget {
  const _CollectionSourcesList({
    required this.visibleSources,
    required this.removingSourceId,
    required this.removalProgress,
    required this.enabled,
    required this.onRemoveSource,
  });

  final List<LibrarySource> visibleSources;
  final String? removingSourceId;
  final double removalProgress;
  final bool enabled;
  final ValueChanged<LibrarySource> onRemoveSource;

  @override
  Widget build(BuildContext context) {
    if (visibleSources.isEmpty && removingSourceId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'No items in this collection',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: _collectionSourcesMaxHeight,
        ),
        child: ScrollEdgeFadeStack(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: visibleSources.length,
            itemBuilder: (context, index) {
              final source = visibleSources[index];
              final isRemoving = source.id == removingSourceId;
              return _CollapsibleCollectionSourceRow(
                source: source,
                enabled: enabled && !isRemoving && removingSourceId == null,
                showDivider: index < visibleSources.length - 1,
                sizeFactor: isRemoving ? 1 - removalProgress : 1,
                onRemovePressed: () => onRemoveSource(source),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Destructive confirmation step for deleting a manual collection.
class _DeleteCollectionConfirmationContent extends StatelessWidget {
  const _DeleteCollectionConfirmationContent({
    required this.state,
    required this.collectionName,
    required this.onCancel,
    required this.onDelete,
  });

  final ManageCollectionState state;
  final String collectionName;
  final VoidCallback onCancel;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetActionsPadding,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage != null) ...[
            Text(
              state.errorMessage!,
              style: context.text.bodyMedium.copyWith(
                color: context.colors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Expanded(
            child: Center(
              child: Text(
                'This removes "$collectionName" only. Books and articles stay in your library.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isBusy ? null : onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.error,
                    foregroundColor: context.colors.onError,
                  ),
                  onPressed: state.isBusy ? null : onDelete,
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Source row wrapper that collapses vertically during staged removal.
class _CollapsibleCollectionSourceRow extends StatelessWidget {
  const _CollapsibleCollectionSourceRow({
    required this.source,
    required this.enabled,
    required this.showDivider,
    required this.sizeFactor,
    required this.onRemovePressed,
  });

  final LibrarySource source;
  final bool enabled;
  final bool showDivider;
  final double sizeFactor;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final clampedSizeFactor = sizeFactor.clamp(0.0, 1.0).toDouble();
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: clampedSizeFactor,
        child: Opacity(
          opacity: clampedSizeFactor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CollectionSourceRow(
                source: source,
                enabled: enabled,
                onRemovePressed: onRemovePressed,
              ),
              if (showDivider)
                Divider(
                  height: 1,
                  color: context.appColors.divider,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionSourceRow extends StatelessWidget {
  const _CollectionSourceRow({
    required this.source,
    required this.enabled,
    required this.onRemovePressed,
  });

  final LibrarySource source;
  final bool enabled;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            _iconFor(source),
            size: AppIconSize.sm,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              source.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            key: ValueKey('collectionSourceRemove-${source.id}'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: colors.onSurfaceVariant,
              minimumSize: const Size.square(40),
              padding: EdgeInsets.zero,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: enabled ? onRemovePressed : null,
            icon: const Icon(
              AppIcons.close,
              size: AppIconSize.sm,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(LibrarySource source) {
    return switch (source.sourceType) {
      SourceType.article => AppIcons.article,
      SourceType.book => AppIcons.book,
    };
  }
}
