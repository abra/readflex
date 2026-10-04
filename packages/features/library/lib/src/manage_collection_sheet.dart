import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_bloc.dart';
import 'manage_collection_cubit.dart';

enum ManageCollectionSheetResult { deleted }

enum _ManageCollectionStep { manage, confirmDelete, confirmDiscard }

const double _collectionSourcesMaxHeight = 260;
const double _collectionSourceRowHeight =
    AppSizes.buttonHeight + AppSpacing.sm * 2;
const double _collectionSourceDividerHeight = 1;
// Align the glyph with the header; keep the full hit target in the gutter.
const double _collectionSourceActionOutset =
    (AppSizes.buttonHeight - AppIconSize.sm) / 2;
const double _emptyCollectionListHeightEstimate = 56;
const double _manageCollectionTextFieldHeightEstimate = 56;
const double _manageCollectionCountLabelHeightEstimate = 18;
const double _manageCollectionDeleteBodyHeightEstimate = 88;
const double _manageCollectionManageMinStepHeight = 336;
const double _manageCollectionDeleteMinStepHeight = 224;
const double _manageCollectionViewportTopReserve = 96;
const Duration _manageCollectionTransitionDuration = Duration(
  milliseconds: 300,
);
const EdgeInsets _sheetHorizontalPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.xl,
);
const EdgeInsets _sheetActionsPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  0,
  AppSpacing.xl,
  AppSpacing.lg,
);
const EdgeInsets _collectionSourcesListPadding = EdgeInsets.only(
  bottom: AppSpacing.lg,
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
    // Closing goes through the form guard; a swipe must not discard edits.
    dismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: ManageCollectionSheet(
        scope: scope,
        sources: sources,
        onCollectionChanged: onCollectionChanged,
      ),
    ),
  );
}

/// Stateful collection-management sheet. Owns staged source removals and
/// rename/delete step transitions before saving to [ManageCollectionCubit].
class ManageCollectionSheet extends StatefulWidget {
  const ManageCollectionSheet({
    required this.scope,
    required this.sources,
    required this.onCollectionChanged,
    this.onFinished,
    this.onCloseFlow,
    super.key,
  });

  final LibraryCollectionScope scope;
  final List<LibrarySource> sources;
  final VoidCallback onCollectionChanged;
  final ValueChanged<ManageCollectionSheetResult?>? onFinished;
  final VoidCallback? onCloseFlow;

  @override
  State<ManageCollectionSheet> createState() => _ManageCollectionSheetState();
}

class _ManageCollectionSheetState extends State<ManageCollectionSheet> {
  late final TextEditingController _nameController;
  late final List<LibrarySource> _displayedSources;
  late int _bookCount;
  late int _articleCount;
  late String _currentName;
  final _removedSourceIds = <String>{};
  var _animateNextSizeChange = false;
  var _step = _ManageCollectionStep.manage;
  var _discardClosesFlow = false;

  void _finish([ManageCollectionSheetResult? result]) {
    if (widget.onFinished case final onFinished?) {
      onFinished(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _closeFlow() {
    if (widget.onCloseFlow case final onClose?) {
      onClose();
    } else {
      _finish();
    }
  }

  void _discard() => _discardClosesFlow ? _closeFlow() : _finish();

  bool get _hasChanges =>
      (widget.scope.canRename && _nameController.text.trim() != _currentName) ||
      _removedSourceIds.isNotEmpty;

  void _requestClose({bool closeFlow = false}) {
    if (context.read<ManageCollectionCubit>().state.isBusy) {
      return;
    }
    if (!_hasChanges) {
      closeFlow ? _closeFlow() : _finish();
      return;
    }
    // Closing must not dismiss the discard decision or silently lose a draft.
    if (_step == _ManageCollectionStep.confirmDiscard) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _discardClosesFlow = closeFlow;
      _animateNextSizeChange = true;
      _step = _ManageCollectionStep.confirmDiscard;
    });
  }

  void _goBack() {
    if (context.read<ManageCollectionCubit>().state.isBusy) return;
    if (_step == _ManageCollectionStep.manage) {
      _requestClose();
    } else {
      _returnToEditing();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentName = widget.scope.label;
    _displayedSources = List.unmodifiable(widget.sources);
    _bookCount = _displayedSources
        .where((source) => source.sourceType == SourceType.book)
        .length;
    _articleCount = _displayedSources.length - _bookCount;
    _nameController = TextEditingController(text: _currentName)
      ..addListener(_onNameChanged);
  }

  @override
  void dispose() {
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

  void _returnToEditing() {
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
    _finish();
  }

  void _toggleSourceRemoval(LibrarySource source) {
    if (context.read<ManageCollectionCubit>().state.isBusy) return;
    // Keep rows in place until Save: undo has no timeout and never writes storage.
    setState(() {
      final removing = _removedSourceIds.add(source.id);
      if (!removing) _removedSourceIds.remove(source.id);
      final delta = removing ? -1 : 1;
      if (source.sourceType == SourceType.book) {
        _bookCount += delta;
      } else {
        _articleCount += delta;
      }
    });
  }

  Future<void> _deleteCollection() async {
    if (!widget.scope.canDelete) return;
    final cubit = context.read<ManageCollectionCubit>();
    final deleted = await cubit.deleteCollection(widget.scope.id);
    if (!mounted || !deleted) return;
    widget.onCollectionChanged();
    _finish(ManageCollectionSheetResult.deleted);
  }

  double _stepHeight(
    BuildContext context,
    _ManageCollectionStep step,
    int sourceCount,
  ) {
    final sourceListHeight = sourceCount == 0
        ? _emptyCollectionListHeightEstimate
        : (sourceCount * _collectionSourceRowHeight +
                  (sourceCount - 1) * _collectionSourceDividerHeight +
                  _collectionSourcesListPadding.vertical)
              .clamp(0.0, _collectionSourcesMaxHeight)
              .toDouble();
    final renameHeight = widget.scope.canRename
        ? _manageCollectionTextFieldHeightEstimate + AppSpacing.lg
        : 0.0;
    final manageHeight =
        AppSizes.buttonHeight +
        AppSpacing.sm +
        renameHeight +
        _manageCollectionCountLabelHeightEstimate +
        AppSpacing.md +
        sourceListHeight +
        AppSpacing.lg +
        AppSizes.buttonHeight +
        _sheetActionsPadding.vertical +
        (widget.scope.canDelete
            ? _collectionSourceDividerHeight +
                  AppSizes.buttonHeight +
                  AppSpacing.lg
            : 0);
    final deleteHeight =
        AppSizes.buttonHeight +
        AppSpacing.sm +
        _manageCollectionDeleteBodyHeightEstimate +
        AppSpacing.lg +
        AppSizes.buttonHeight +
        _sheetActionsPadding.vertical;
    final viewportLimit = math.max(
      0.0,
      MediaQuery.sizeOf(context).height -
          MediaQuery.viewInsetsOf(context).bottom -
          _manageCollectionViewportTopReserve,
    );
    final minHeight = switch (step) {
      _ManageCollectionStep.manage => _manageCollectionManageMinStepHeight,
      _ManageCollectionStep.confirmDelete ||
      _ManageCollectionStep.confirmDiscard =>
        _manageCollectionDeleteMinStepHeight,
    };
    final maxHeight = viewportLimit;
    final preferredHeight = switch (step) {
      _ManageCollectionStep.manage => manageHeight,
      _ManageCollectionStep.confirmDelete ||
      _ManageCollectionStep.confirmDiscard => deleteHeight,
    };
    final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    return (preferredHeight * textScale)
        .clamp(math.min(minHeight, maxHeight), maxHeight)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: BlocBuilder<ManageCollectionCubit, ManageCollectionState>(
        builder: _buildSheet,
      ),
    );
  }

  Widget _buildSheet(BuildContext context, ManageCollectionState state) {
    final visibleSources = _displayedSources;
    final canRename = widget.scope.canRename;
    final name = canRename ? _nameController.text.trim() : _currentName;
    final canSave =
        !state.isBusy &&
        (!canRename || name.isNotEmpty) &&
        ((canRename && name != _currentName) || _removedSourceIds.isNotEmpty);

    final sizeDuration =
        _animateNextSizeChange && !MediaQuery.disableAnimationsOf(context)
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
        title: context.l10n.libraryManageCollectionTitle,
        hasPreviousStep: widget.onFinished != null,
        onBack: state.isBusy || widget.onFinished == null ? null : _goBack,
        onClose: state.isBusy ? null : () => _requestClose(closeFlow: true),
        child: _ManageCollectionContent(
          state: state,
          nameController: _nameController,
          visibleSources: visibleSources,
          removedSourceIds: _removedSourceIds,
          bookCount: _bookCount,
          articleCount: _articleCount,
          canRename: widget.scope.canRename,
          canDelete: widget.scope.canDelete,
          canSave: canSave,
          onSave: _saveChanges,
          onCancel: _requestClose,
          onToggleSource: _toggleSourceRemoval,
          onDeletePressed: _showDeleteConfirmation,
        ),
      ),
      _ManageCollectionStep.confirmDelete => _ManageCollectionStepView(
        key: const ValueKey('deleteCollectionContent'),
        title: context.l10n.libraryDeleteCollectionTitle,
        hasPreviousStep: true,
        onBack: state.isBusy ? null : _goBack,
        onClose: state.isBusy ? null : () => _requestClose(closeFlow: true),
        child: _DeleteCollectionConfirmationContent(
          state: state,
          collectionName: _currentName,
          onCancel: _returnToEditing,
          onDelete: _deleteCollection,
        ),
      ),
      _ManageCollectionStep.confirmDiscard => _ManageCollectionStepView(
        key: const ValueKey('discardCollectionContent'),
        title: context.l10n.libraryDiscardChangesTitle,
        hasPreviousStep: true,
        onBack: _goBack,
        onClose: () => _requestClose(closeFlow: true),
        child: Padding(
          padding: _sheetActionsPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    context.l10n.libraryDiscardChangesBody,
                    style: context.text.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSheetActions(
                primaryLabel: context.l10n.libraryKeepEditing,
                onPrimary: _returnToEditing,
                secondaryLabel: context.l10n.libraryDiscardChanges,
                onSecondary: _discard,
              ),
            ],
          ),
        ),
      ),
    };

    final stepHeight = _stepHeight(context, _step, visibleSources.length);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: stepHeight),
      duration: sizeDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, animatedHeight, child) {
        return SizedBox(
          key: const ValueKey('manageCollectionStepFrame'),
          height: animatedHeight,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: stepHeight,
              maxHeight: stepHeight,
              child: SizedBox(height: stepHeight, child: child),
            ),
          ),
        );
      },
      child: SizedBox(
        height: stepHeight,
        child: _ManageCollectionStepSwitcher(
          step: _step,
          height: stepHeight,
          child: child,
        ),
      ),
    );
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
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _manageCollectionTransitionDuration;
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
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
          translation: Offset(
            sign *
                (Directionality.of(context) == TextDirection.rtl ? -1 : 1) *
                (1 - value),
            0,
          ),
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
    _ManageCollectionStep.confirmDelete ||
    _ManageCollectionStep.confirmDiscard => 1,
  };
}

/// Shared step frame with a bottom-sheet header and expandable body.
class _ManageCollectionStepView extends StatelessWidget {
  const _ManageCollectionStepView({
    required this.title,
    required this.child,
    this.hasPreviousStep = false,
    this.onBack,
    this.onClose,
    super.key,
  });

  final String title;
  final Widget child;
  final bool hasPreviousStep;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ActionBottomSheetLayout(
        title: title,
        onBack: onBack,
        backLabel: hasPreviousStep ? context.l10n.commonBack : null,
        onClose: onClose,
        closeLabel: context.l10n.commonClose,
        constrainBody: true,
        bodyPadding: EdgeInsets.zero,
        child: SizedBox.expand(child: child),
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
    required this.removedSourceIds,
    required this.bookCount,
    required this.articleCount,
    required this.canRename,
    required this.canDelete,
    required this.canSave,
    required this.onSave,
    required this.onCancel,
    required this.onToggleSource,
    required this.onDeletePressed,
  });

  final ManageCollectionState state;
  final TextEditingController nameController;
  final List<LibrarySource> visibleSources;
  final Set<String> removedSourceIds;
  final int bookCount;
  final int articleCount;
  final bool canRename;
  final bool canDelete;
  final bool canSave;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;
  final ValueChanged<LibrarySource> onToggleSource;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (state.errorCode != null) ...[
        Padding(
          padding: _sheetHorizontalPadding,
          child: Text(
            _manageCollectionErrorMessage(context.l10n, state.errorCode!),
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
            decoration: InputDecoration(
              hintText: context.l10n.libraryCollectionNameRequired,
            ),
            onSubmitted: (_) => canSave ? onSave() : null,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      Padding(
        padding: _sheetHorizontalPadding,
        child: Text(
          _sourceCountLabel(context),
          style: context.text.labelSmall.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
    ];
    final deleteAction = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: _collectionSourceDividerHeight),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: state.isBusy ? null : onDeletePressed,
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            icon: const Icon(AppIcons.delete, size: AppIconSize.sm),
            label: Text(context.l10n.libraryDeleteCollectionButton),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
    final actions = _CollectionFormActions(
      onCancel: state.isBusy ? null : onCancel,
      onSave: canSave ? onSave : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the footer reachable with the keyboard or large accessibility
        // text. A single sliver viewport avoids nested scrolling and eager rows.
        final scrollForm =
            constraints.maxHeight < 260 ||
            MediaQuery.textScalerOf(context).scale(15) > 20;
        if (scrollForm) {
          return Column(
            children: [
              Expanded(
                child: ScrollEdgeFadeStack(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: fields,
                        ),
                      ),
                      if (visibleSources.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              context.l10n.libraryNoItemsInCollection,
                              style: context.text.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: visibleSources.length,
                          itemBuilder: (context, index) {
                            final source = visibleSources[index];
                            return _CollectionSourceRow(
                              key: ValueKey('collectionSource-${source.id}'),
                              source: source,
                              enabled: !state.isBusy,
                              removed: removedSourceIds.contains(source.id),
                              showDivider: index < visibleSources.length - 1,
                              onTogglePressed: () => onToggleSource(source),
                            );
                          },
                        ),
                      if (canDelete)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: _sheetHorizontalPadding,
                            child: deleteAction,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(padding: _sheetActionsPadding, child: actions),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...fields,
            Expanded(
              child: _CollectionSourcesList(
                visibleSources: visibleSources,
                removedSourceIds: removedSourceIds,
                enabled: !state.isBusy,
                onToggleSource: onToggleSource,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: _sheetActionsPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (canDelete) deleteAction, actions],
              ),
            ),
          ],
        );
      },
    );
  }

  String _sourceCountLabel(BuildContext context) {
    final parts = [
      if (bookCount > 0) context.l10n.libraryBookCount(bookCount),
      if (articleCount > 0) context.l10n.libraryArticleCount(articleCount),
    ];
    return parts.isEmpty
        ? context.l10n.libraryEmptySourceCount
        : parts.join(', ');
  }
}

class _CollectionFormActions extends StatelessWidget {
  const _CollectionFormActions({required this.onCancel, required this.onSave});

  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => AppSheetActions(
    primaryLabel: context.l10n.commonSave,
    onPrimary: onSave,
    secondaryLabel: context.l10n.commonCancel,
    onSecondary: onCancel,
  );
}

/// Scrollable list of sources currently displayed inside the collection.
class _CollectionSourcesList extends StatelessWidget {
  const _CollectionSourcesList({
    required this.visibleSources,
    required this.removedSourceIds,
    required this.enabled,
    required this.onToggleSource,
  });

  final List<LibrarySource> visibleSources;
  final Set<String> removedSourceIds;
  final bool enabled;
  final ValueChanged<LibrarySource> onToggleSource;

  @override
  Widget build(BuildContext context) {
    if (visibleSources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            context.l10n.libraryNoItemsInCollection,
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
            padding: _collectionSourcesListPadding,
            itemCount: visibleSources.length,
            itemBuilder: (context, index) {
              final source = visibleSources[index];
              return _CollectionSourceRow(
                key: ValueKey('collectionSource-${source.id}'),
                source: source,
                enabled: enabled,
                removed: removedSourceIds.contains(source.id),
                showDivider: index < visibleSources.length - 1,
                onTogglePressed: () => onToggleSource(source),
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
          if (state.errorCode != null) ...[
            Text(
              _manageCollectionErrorMessage(context.l10n, state.errorCode!),
              style: context.text.bodyMedium.copyWith(
                color: context.colors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Expanded(
            child: Center(
              child: Text(
                context.l10n.libraryDeleteCollectionBody(collectionName),
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSheetActions(
            primaryLabel: context.l10n.commonDelete,
            onPrimary: onDelete,
            destructive: true,
            busy: state.isBusy,
            secondaryLabel: context.l10n.commonCancel,
            onSecondary: onCancel,
          ),
        ],
      ),
    );
  }
}

class _CollectionSourceRow extends StatelessWidget {
  const _CollectionSourceRow({
    required this.source,
    required this.enabled,
    required this.removed,
    required this.showDivider,
    required this.onTogglePressed,
    super.key,
  });

  final LibrarySource source;
  final bool enabled;
  final bool removed;
  final bool showDivider;
  final VoidCallback onTogglePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl - _collectionSourceActionOutset,
            AppSpacing.sm,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium.copyWith(
                        color: removed
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                    Visibility(
                      visible: removed,
                      maintainSize: true,
                      maintainState: true,
                      maintainAnimation: true,
                      child: Text(
                        context.l10n.libraryRemovalPending,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppPlainIconButton(
                key: ValueKey(
                  'collectionSource${removed ? 'Undo' : 'Remove'}-${source.id}',
                ),
                tooltip: removed
                    ? context.l10n.commonUndo
                    : context.l10n.libraryRemoveFromCollection(source.title),
                color: removed
                    ? context.actionForeground
                    : colors.onSurfaceVariant,
                onPressed: enabled ? onTogglePressed : null,
                icon: removed ? AppIcons.undo : AppIcons.delete,
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: _collectionSourceDividerHeight),
      ],
    );
  }

  IconData _iconFor(LibrarySource source) {
    return switch (source.sourceType) {
      SourceType.article => AppIcons.article,
      SourceType.book => AppIcons.book,
    };
  }
}

String _manageCollectionErrorMessage(
  ReadflexLocalizations l10n,
  ManageCollectionErrorCode errorCode,
) {
  return switch (errorCode) {
    ManageCollectionErrorCode.collectionNameRequired =>
      l10n.libraryCollectionNameRequired,
    ManageCollectionErrorCode.saveCollectionFailed =>
      l10n.librarySaveCollectionFailed,
    ManageCollectionErrorCode.deleteCollectionFailed =>
      l10n.libraryDeleteCollectionFailed,
  };
}
