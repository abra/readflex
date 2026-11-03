import 'dart:math' as math;

import 'package:collection_repository/collection_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'add_to_collection_cubit.dart';

Future<int?> showAddToCollectionSheet({
  required BuildContext context,
  required AddToCollectionCubit cubit,
  required Set<String> sourceIds,
  required VoidCallback onCollectionCreated,
}) {
  cubit.load(sourceIds: sourceIds);
  return showAppBottomSheet<int>(
    context,
    scrimClosesFlow: true,
    builder: (sheetContext) => BlocProvider.value(
      value: cubit,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(
            600,
            MediaQuery.sizeOf(sheetContext).height * .75,
          ),
        ),
        child: AddToCollectionSheet(
          sourceIds: sourceIds,
          onClose: () => Navigator.of(sheetContext).pop(),
          onAdded: (count) => Navigator.of(sheetContext).pop(count),
          onCollectionCreated: onCollectionCreated,
        ),
      ),
    ),
  );
}

/// Modal collection destinations and their guarded creation step.
class AddToCollectionSheet extends StatefulWidget {
  const AddToCollectionSheet({
    required this.sourceIds,
    required this.onClose,
    required this.onAdded,
    required this.onCollectionCreated,
    super.key,
  });

  final Set<String> sourceIds;

  final VoidCallback onClose;
  final ValueChanged<int> onAdded;
  final VoidCallback onCollectionCreated;

  @override
  State<AddToCollectionSheet> createState() => AddToCollectionSheetState();
}

class AddToCollectionSheetState extends State<AddToCollectionSheet>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _panelScroll = ScrollController();
  final _searchFocus = FocusNode(debugLabel: 'Collection destination search');
  late final _nameController = TextEditingController()
    ..addListener(_onDraftChanged);
  bool _hasDraft = false;
  bool _creating = false;
  bool _confirmingDiscard = false;
  late final _transition = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  )..addStatusListener(_onTransitionStatus);
  late final _curve = CurvedAnimation(
    parent: _transition,
    curve: Curves.easeInOutCubic,
  );
  late final _listOffset = Tween(
    begin: Offset.zero,
    end: const Offset(-1, 0),
  ).animate(_curve);
  late final _formOffset = Tween(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(_curve);

  void _onDraftChanged() {
    final hasDraft = _nameController.text.trim().isNotEmpty;
    if (hasDraft != _hasDraft) setState(() => _hasDraft = hasDraft);
  }

  void _onTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      setState(() {});
    }
  }

  /// Close and guarded scrim/drag attempts preserve a typed name.
  void requestClose() {
    if (context.read<AddToCollectionCubit>().state.isBusy) return;
    if (_hasDraft) {
      if (_confirmingDiscard) return;
      FocusScope.of(context).unfocus();
      if (!_creating) _showCreation(true);
      setState(() {
        _confirmingDiscard = true;
      });
      _resetOuterScroll();
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onClose();
  }

  /// Back unwinds the current step before leaving the destination list.
  void handleBack() {
    if (context.read<AddToCollectionCubit>().state.isBusy) return;
    if (_confirmingDiscard) {
      _keepEditing();
    } else if (_creating) {
      _showCreation(false);
    } else {
      requestClose();
    }
  }

  void _keepEditing() {
    setState(() => _confirmingDiscard = false);
    _resetOuterScroll();
  }

  void _resetOuterScroll() {
    if (_panelScroll.hasClients) _panelScroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _panelScroll.hasClients) _panelScroll.jumpTo(0);
    });
  }

  void _discardDraft() => widget.onClose();

  void _showCreation(bool creating) {
    if (_creating == creating ||
        context.read<AddToCollectionCubit>().state.isBusy) {
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AddToCollectionCubit>().clearError();
    setState(() {
      _creating = creating;
      _confirmingDiscard = false;
    });
    _resetOuterScroll();
    if (context.reduceMotion) {
      _transition.value = creating ? 1 : 0;
    } else {
      _transition.animateTo(creating ? 1 : 0);
    }
  }

  Future<void> _submit() async {
    final cubit = context.read<AddToCollectionCubit>();
    if (!cubit.state.canSubmit) return;
    final destinationCount = cubit.state.selectedDestinationCount;
    FocusScope.of(context).unfocus();
    final added = await cubit.submitSelected(sourceIds: widget.sourceIds);
    if (mounted && added) widget.onAdded(destinationCount);
  }

  Future<void> _createCollection() async {
    final cubit = context.read<AddToCollectionCubit>();
    if (cubit.state.isBusy || !_hasDraft) return;
    final created = await cubit.createCollection(name: _nameController.text);
    if (!mounted || !created) return;
    _nameController.clear();
    _searchController.clear();
    _showCreation(false);
    widget.onCollectionCreated();
  }

  @override
  void dispose() {
    _curve.dispose();
    _transition.dispose();
    _searchController.dispose();
    _panelScroll.dispose();
    _searchFocus.dispose();
    _nameController
      ..removeListener(_onDraftChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddToCollectionCubit, AddToCollectionState>(
      builder: (context, state) => PopScope(
        canPop: !_creating && !_hasDraft && !state.isBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) handleBack();
        },
        child: AppSheetDismissGuard(
          enabled: state.isBusy || _hasDraft,
          onDismissAttempt: requestClose,
          child: _PanelViewport(
            controller: _panelScroll,
            creating: _creating || _transition.isAnimating,
            destinationCount: state.selectedDestinationCount,
            favouritesSourceCount: state.favouritesSourceCount,
            child: ClipRect(
              child: Stack(
                children: [
                  AppSheetStep(
                    active: !_creating,
                    visible: !_creating || _transition.isAnimating,
                    maintainSize: true,
                    position: _listOffset,
                    child: ActionBottomSheetLayout(
                      title: context.l10n.libraryAddToCollectionTitle,
                      closeLabel: context.l10n.commonClose,
                      onClose: state.isBusy ? null : requestClose,
                      constrainBody: true,
                      bodyPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      footer: _AddToCollectionsAction(
                        state: state,
                        onSubmit: _submit,
                      ),
                      child: _DestinationContent(
                        state: state,
                        sourceCount: widget.sourceIds.length,
                        searchController: _searchController,
                        searchFocus: _searchFocus,
                        onCreate: () => _showCreation(true),
                      ),
                    ),
                  ),
                  if (_creating || _transition.isAnimating)
                    Positioned.fill(
                      child: AppSheetStep(
                        active: _creating,
                        visible: true,
                        position: _formOffset,
                        child: AnimatedSwitcher(
                          duration: context.motion(AppMotion.short),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                fit: StackFit.expand,
                                children: [...previousChildren, ?currentChild],
                              ),
                          child: _confirmingDiscard
                              ? _DiscardCollectionDraft(
                                  key: const ValueKey(
                                    'addToCollectionDiscardStep',
                                  ),
                                  onKeepEditing: _keepEditing,
                                  onDiscard: _discardDraft,
                                  onClose: requestClose,
                                )
                              : ActionBottomSheetLayout(
                                  key: const ValueKey(
                                    'addToCollectionCreateStep',
                                  ),
                                  title: context.l10n.libraryNewCollection,
                                  closeLabel: context.l10n.commonClose,
                                  onClose: state.isBusy ? null : requestClose,
                                  backLabel: context.l10n.commonBack,
                                  onBack: state.isBusy ? null : handleBack,
                                  constrainBody: true,
                                  bodyPadding: const EdgeInsets.only(
                                    bottom: AppSpacing.lg,
                                  ),
                                  footer: _CreateCollectionAction(
                                    state: state,
                                    controller: _nameController,
                                    onCreate: _createCollection,
                                  ),
                                  child: _CreateCollectionContent(
                                    state: state,
                                    controller: _nameController,
                                    onCreate: _createCollection,
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
      ),
    );
  }
}

/// Keep one scroll subtree through keyboard/rotation changes. Only short hosts
/// scroll the whole frame; destination rows retain their own lazy viewport.
class _PanelViewport extends StatefulWidget {
  const _PanelViewport({
    required this.controller,
    required this.creating,
    required this.destinationCount,
    required this.favouritesSourceCount,
    required this.child,
  });

  final ScrollController controller;
  final bool creating;
  final int destinationCount;
  final int favouritesSourceCount;
  final Widget child;

  @override
  State<_PanelViewport> createState() => _PanelViewportState();
}

class _PanelViewportState extends State<_PanelViewport> {
  Object? _layoutKey;
  ({double destinations, double forms})? _minimums;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layoutKey = (
        constraints.maxWidth,
        MediaQuery.textScalerOf(context),
        Localizations.localeOf(context),
        Theme.of(context),
        widget.destinationCount,
        widget.favouritesSourceCount,
      );
      if (_layoutKey != layoutKey) {
        _layoutKey = layoutKey;
        _minimums = _measureMinimums(context, constraints.maxWidth);
      }
      final minimums = _minimums!;
      final minimumHeight = math.max(minimums.destinations, minimums.forms);
      final fits = constraints.maxHeight >= minimumHeight;
      return SingleChildScrollView(
        key: const ValueKey('addToCollectionPanelViewport'),
        controller: widget.controller,
        primary: false,
        physics: fits ? const NeverScrollableScrollPhysics() : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: widget.creating ? minimums.forms : 0,
            maxHeight: math.max(constraints.maxHeight, minimumHeight),
          ),
          child: widget.child,
        ),
      );
    },
  );

  // Measure only the fixed chrome when its geometry changes. Collection rows
  // remain lazy and are never measured to determine the panel's height.
  ({double destinations, double forms}) _measureMinimums(
    BuildContext context,
    double width,
  ) {
    final l10n = context.l10n;
    final text = context.text;
    final contentWidth = math.max(1.0, width - 2 * AppSpacing.xl);
    final buttonWidth = math.max(1.0, contentWidth - 2 * AppSpacing.lg);
    final subtitle = _textHeight(
      l10n.libraryChooseCollectionsSubtitle,
      text.bodySmall,
      contentWidth,
    );
    final search = math.max(
      AppSizes.buttonHeight,
      _textHeight('M', text.bodyMedium, contentWidth) + 2 * AppSpacing.sm,
    );
    final newCollection = math.max(
      AppSizes.buttonHeight,
      _textHeight(
        l10n.libraryNewCollection,
        text.bodyMedium,
        math.max(1.0, contentWidth - 2 * (AppIconSize.sm + AppSpacing.md)),
      ),
    );
    final submit = _buttonHeight(
      l10n.libraryAddToCollections(widget.destinationCount),
      buttonWidth,
    );
    // Keep at least one complete wrapped destination in the inner viewport.
    // Budget the fixed Favourites/status labels, never the collection catalog.
    final rowTextWidth = math.max(
      1.0,
      contentWidth - AppSpacing.xl - 2 * AppSpacing.lg - AppSizes.buttonHeight,
    );
    final rowLabelWidth = math.max(
      1.0,
      rowTextWidth -
          AppSpacing.sm -
          _textWidth('${widget.favouritesSourceCount}', text.bodyMedium),
    );
    final destinationRow = math.max(
      AppSizes.buttonHeight,
      math.max(
            _textHeight(l10n.libraryFavourites, text.bodyLarge, rowLabelWidth),
            3 * _textHeight('M', text.bodyLarge, double.infinity),
          ) +
          _textHeight(
            l10n.libraryAddedToCollection,
            text.bodySmall,
            rowTextWidth,
          ) +
          2 * AppSpacing.sm,
    );
    final destinations =
        math.max(
          AppSizes.buttonHeight,
          _textHeight(
            l10n.libraryAddToCollectionTitle,
            text.titleMedium,
            math.max(1.0, width - 2 * AppSpacing.xl - AppSizes.buttonHeight),
          ),
        ) +
        AppSpacing.sm +
        subtitle +
        AppSpacing.md +
        search +
        AppSpacing.sm +
        destinationRow +
        AppSpacing.sm +
        newCollection +
        AppSpacing.sm +
        submit +
        AppSpacing.lg;
    // Back/title/Close can stack in narrow windows, as BottomSheetHeader does.
    final creation =
        AppSizes.buttonHeight +
        AppSpacing.sm +
        _textHeight(l10n.libraryNewCollection, text.titleMedium, contentWidth) +
        AppSpacing.sm +
        math.max(
          AppSizes.buttonHeight,
          _textHeight('M', text.bodyLarge, contentWidth) + AppSpacing.xl,
        ) +
        AppSpacing.lg +
        AppSpacing.sm +
        _buttonHeight(l10n.libraryCreateCollection, buttonWidth) +
        AppSpacing.lg;
    final stacked = AppSheetActions.stacks(
      context,
      maxWidth: contentWidth,
      primaryLabel: l10n.commonKeepEditing,
      secondaryLabel: l10n.commonDiscardChanges,
    );
    final actionWidth = stacked
        ? buttonWidth
        : math.max(1.0, (contentWidth - AppSpacing.md) / 2 - 2 * AppSpacing.lg);
    final keep = _buttonHeight(
      l10n.commonKeepEditing,
      actionWidth,
      maxLines: 2,
    );
    final discard = _buttonHeight(
      l10n.commonDiscardChanges,
      actionWidth,
      maxLines: 2,
    );
    final confirmation =
        AppSizes.buttonHeight +
        AppSpacing.sm +
        _textHeight(
          l10n.libraryDiscardChangesTitle,
          text.titleMedium,
          contentWidth,
        ) +
        AppSpacing.sm +
        _textHeight(
          l10n.libraryDiscardChangesBody,
          text.bodyMedium,
          contentWidth,
        ) +
        AppSpacing.lg +
        AppSpacing.sm +
        (stacked ? keep + AppSpacing.sm + discard : math.max(keep, discard)) +
        AppSpacing.lg;
    return (
      destinations: destinations,
      forms: math.max(creation, confirmation),
    );
  }

  double _buttonHeight(String label, double width, {int? maxLines}) => math.max(
    AppSizes.buttonHeight,
    _textHeight(label, context.text.labelLarge, width, maxLines: maxLines) +
        2 * AppSpacing.md,
  );

  double _textHeight(
    String value,
    TextStyle style,
    double width, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _textWidth(String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class _DestinationContent extends StatelessWidget {
  const _DestinationContent({
    required this.state,
    required this.sourceCount,
    required this.searchController,
    required this.searchFocus,
    required this.onCreate,
  });

  final AddToCollectionState state;
  final int sourceCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.libraryChooseCollectionsSubtitle,
          style: context.text.bodySmall.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AbsorbPointer(
          absorbing: state.isBusy,
          child: ExcludeFocus(
            excluding: state.isBusy,
            child: SearchField(
              key: const ValueKey('addToCollectionsSearch'),
              hintText: l10n.librarySearchCollectionsHint,
              compactHintText: l10n.commonSearch,
              clearButtonSemanticsLabel: l10n.commonClearSearch,
              controller: searchController,
              focusNode: searchFocus,
              onChanged: context.read<AddToCollectionCubit>().searchCollections,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: _DestinationResults(state: state, sourceCount: sourceCount),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppDrillInRow(
          key: const ValueKey('libraryNewCollectionRow'),
          icon: AppIcons.collectionAdd,
          title: l10n.libraryNewCollection,
          enabled:
              !state.isBusy &&
              state.errorCode != AddToCollectionErrorCode.loadCollectionsFailed,
          onTap: onCreate,
        ),
      ],
    );
  }
}

class _DestinationResults extends StatelessWidget {
  const _DestinationResults({required this.state, required this.sourceCount});

  final AddToCollectionState state;
  final int sourceCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.status == AddToCollectionStatus.initial ||
        state.status == AddToCollectionStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: CenteredCircularProgressIndicator(),
      );
    }
    if (state.errorCode == AddToCollectionErrorCode.loadCollectionsFailed) {
      return SingleChildScrollView(
        primary: false,
        child: ErrorState(
          message: l10n.libraryLoadCollectionsFailed,
          retryLabel: l10n.commonRetry,
          onRetry: context.read<AddToCollectionCubit>().load,
        ),
      );
    }

    final collections = state.visibleCollections;
    final showFavourites = state.matchesSearch(l10n.libraryFavourites);
    final resultCount = collections.length + (showFavourites ? 1 : 0);
    return ScrollEdgeFadeStack(
      child: CustomScrollView(
        key: const ValueKey('addToCollectionDestinationList'),
        primary: false,
        shrinkWrap: true,
        slivers: [
          if (state.errorCode ==
              AddToCollectionErrorCode.updateCollectionFailed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _collectionErrorMessage(l10n, state.errorCode!),
                    style: context.text.bodySmall.copyWith(
                      color: context.colors.error,
                    ),
                  ),
                ),
              ),
            ),
          if (resultCount == 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  l10n.libraryNoMatchingCollections,
                  style: context.text.bodyMedium.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: resultCount,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (showFavourites && index == 0) {
                  return _DestinationRow(
                    id: CollectionRepository.favouritesCollectionId,
                    icon: AppIcons.collectionFavourites,
                    label: l10n.libraryFavourites,
                    sourceCount: state.favouritesSourceCount,
                    state: state,
                  );
                }
                final collection =
                    collections[index - (showFavourites ? 1 : 0)];
                return _DestinationRow(
                  id: collection.id,
                  icon: AppIcons.collection,
                  label: collection.name,
                  sourceCount: collection.sourceCount,
                  state: state,
                );
              },
            ),
          if (state.collections.isEmpty && state.searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l10n.libraryCreateCollectionPrompt(sourceCount),
                  style: context.text.bodyMedium.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.id,
    required this.icon,
    required this.label,
    required this.sourceCount,
    required this.state,
  });

  final String id;
  final IconData icon;
  final String label;
  final int sourceCount;
  final AddToCollectionState state;

  @override
  Widget build(BuildContext context) {
    final included = state.containingAll.contains(id);
    return CheckboxListTile(
      key: ValueKey('addToCollectionDestination-$id'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.trailing,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      secondary: Icon(
        icon,
        size: AppIconSize.sm,
        color: context.colors.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyLarge)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$sourceCount',
            style: context.text.bodyMedium.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: included
          ? Text(
              context.l10n.libraryAddedToCollection,
              style: context.text.bodySmall.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            )
          : null,
      value: included || state.selectedCollectionIds.contains(id),
      onChanged: included || state.isBusy
          ? null
          : (_) => context.read<AddToCollectionCubit>().toggleCollection(id),
    );
  }
}

class _AddToCollectionsAction extends StatelessWidget {
  const _AddToCollectionsAction({required this.state, required this.onSubmit});

  final AddToCollectionState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey('addToCollectionsSubmitButton'),
    onPressed: state.canSubmit ? onSubmit : null,
    child: AppBusyButtonLabel(
      context.l10n.libraryAddToCollections(state.selectedDestinationCount),
      busy: state.status == AddToCollectionStatus.submitting,
      maxLines: null,
    ),
  );
}

class _CreateCollectionContent extends StatelessWidget {
  const _CreateCollectionContent({
    required this.state,
    required this.controller,
    required this.onCreate,
  });

  final AddToCollectionState state;
  final TextEditingController controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final creationError =
        state.errorCode == AddToCollectionErrorCode.collectionNameRequired ||
        state.errorCode == AddToCollectionErrorCode.createCollectionFailed;
    return ScrollEdgeFadeStack(
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('newCollectionNameField'),
              controller: controller,
              enabled: !state.isBusy,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: context.l10n.libraryNewCollectionName,
              ),
              onSubmitted: (_) {
                if (!state.isBusy && controller.text.trim().isNotEmpty) {
                  onCreate();
                }
              },
            ),
            if (creationError)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _collectionErrorMessage(context.l10n, state.errorCode!),
                  style: context.text.bodySmall.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateCollectionAction extends StatelessWidget {
  const _CreateCollectionAction({
    required this.state,
    required this.controller,
    required this.onCreate,
  });

  final AddToCollectionState state;
  final TextEditingController controller;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => FilledButton(
          key: const ValueKey('createCollectionSubmitButton'),
          onPressed: state.isBusy || value.text.trim().isEmpty
              ? null
              : onCreate,
          child: AppBusyButtonLabel(
            context.l10n.libraryCreateCollection,
            busy: state.status == AddToCollectionStatus.submitting,
            maxLines: null,
          ),
        ),
      );
}

class _DiscardCollectionDraft extends StatelessWidget {
  const _DiscardCollectionDraft({
    required this.onKeepEditing,
    required this.onDiscard,
    required this.onClose,
    super.key,
  });

  final VoidCallback onKeepEditing;
  final VoidCallback onDiscard;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ActionBottomSheetLayout(
    title: context.l10n.libraryDiscardChangesTitle,
    onBack: onKeepEditing,
    backLabel: context.l10n.commonBack,
    onClose: onClose,
    closeLabel: context.l10n.commonClose,
    constrainBody: true,
    footer: AppSheetActions(
      primaryLabel: context.l10n.commonKeepEditing,
      onPrimary: onKeepEditing,
      secondaryLabel: context.l10n.commonDiscardChanges,
      onSecondary: onDiscard,
      destructiveSecondary: true,
    ),
    child: SingleChildScrollView(
      primary: false,
      child: Text(
        context.l10n.libraryDiscardChangesBody,
        style: context.text.bodyMedium,
      ),
    ),
  );
}

String _collectionErrorMessage(
  ReadflexLocalizations l10n,
  AddToCollectionErrorCode code,
) => switch (code) {
  AddToCollectionErrorCode.loadCollectionsFailed =>
    l10n.libraryLoadCollectionsFailed,
  AddToCollectionErrorCode.updateCollectionFailed =>
    l10n.libraryAddToCollectionsFailed,
  AddToCollectionErrorCode.collectionNameRequired =>
    l10n.libraryCollectionNameRequired,
  AddToCollectionErrorCode.createCollectionFailed =>
    l10n.libraryCreateCollectionFailed,
};
