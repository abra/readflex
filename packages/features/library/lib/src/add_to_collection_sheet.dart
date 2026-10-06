import 'dart:math' as math;

import 'package:collection_repository/collection_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'add_to_collection_cubit.dart';

// Destination rows keep a 4dp inset for their ink and end with a 48dp slot
// whose 20dp check lands on the gutter, matching the Collections picker's
// menu column; the list subtracts both from the 24dp sheet gutter.
const double _destinationRowInset = AppSpacing.xs;
const EdgeInsetsDirectional _destinationListPadding =
    EdgeInsetsDirectional.only(
      start: AppSpacing.xl - _destinationRowInset,
      end: AppSpacing.xl - _destinationRowInset - AppSizes.iconActionOutset,
    );
// Dividers and messages inside that list sit on the 24dp gutter.
const EdgeInsetsDirectional _destinationLinePadding =
    EdgeInsetsDirectional.only(
      start: _destinationRowInset,
      end: _destinationRowInset + AppSizes.iconActionOutset,
    );

Future<bool?> showAddToCollectionSheet({
  required BuildContext context,
  required AddToCollectionCubit cubit,
  required Set<String> sourceIds,
}) {
  cubit.load(sourceIds: sourceIds);
  return showAppBottomSheet<bool>(
    context,
    scrimClosesFlow: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _AddToCollectionSheet(sourceIds: sourceIds),
    ),
  );
}

/// Sheet that adds the selected source ids to favourites, an existing
/// collection, or a newly created collection.
class _AddToCollectionSheet extends StatefulWidget {
  const _AddToCollectionSheet({required this.sourceIds});

  final Set<String> sourceIds;

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet>
    with SingleTickerProviderStateMixin {
  late final _nameController = TextEditingController()
    ..addListener(_onDraftChanged);
  bool _creating = false;
  bool _confirmingDiscard = false;
  late final _transition =
      AnimationController(
        vsync: this,
        duration: AppMotion.medium,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          setState(() {});
        }
      });
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

  bool get _hasDraft => _nameController.text.trim().isNotEmpty;

  // The guard follows the typed name, so the sheet must rebuild on edits.
  void _onDraftChanged() => setState(() {});

  /// Close, scrim and drag-down: a typed name asks before leaving the flow.
  void _requestClose() {
    if (context.read<AddToCollectionCubit>().state.isBusy) return;
    if (!_creating || !_hasDraft) {
      Navigator.of(context).pop(false);
      return;
    }
    // Repeated attempts keep the decision visible until the user chooses.
    if (_confirmingDiscard) return;
    FocusScope.of(context).unfocus();
    setState(() => _confirmingDiscard = true);
  }

  void _keepEditing() => setState(() => _confirmingDiscard = false);

  void _discardDraft() => Navigator.of(context).pop(false);

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
    if (context.reduceMotion) {
      _transition.value = creating ? 1 : 0;
    } else {
      _transition.animateTo(creating ? 1 : 0);
    }
  }

  Widget _step({
    required bool active,
    required Animation<Offset> offset,
    required Widget child,
  }) => ExcludeSemantics(
    excluding: !active,
    child: ExcludeFocus(
      excluding: !active,
      child: IgnorePointer(
        ignoring: !active,
        child: SlideTransition(
          position: offset,
          textDirection: Directionality.of(context),
          child: child,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _curve.dispose();
    _transition.dispose();
    _nameController
      ..removeListener(_onDraftChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _addToCollection(LibraryCollection collection) async {
    final cubit = context.read<AddToCollectionCubit>();
    if (cubit.state.isBusy) return;
    await cubit.addToCollection(
      collectionId: collection.id,
      sourceIds: widget.sourceIds,
    );
    if (!mounted || cubit.state.status == AddToCollectionStatus.failure) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _addToFavourites() async {
    final cubit = context.read<AddToCollectionCubit>();
    if (cubit.state.isBusy) return;
    await cubit.addToFavourites(sourceIds: widget.sourceIds);
    if (!mounted || cubit.state.status == AddToCollectionStatus.failure) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _createAndAdd() async {
    final cubit = context.read<AddToCollectionCubit>();
    if (cubit.state.isBusy) return;
    await cubit.createAndAdd(
      name: _nameController.text,
      sourceIds: widget.sourceIds,
    );
    if (!mounted || cubit.state.status == AddToCollectionStatus.failure) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddToCollectionCubit, AddToCollectionState>(
      builder: (context, state) => PopScope(
        canPop: !_creating && !state.isBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !_creating) return;
          // Back is a step back, not a dismissal: the draft stays in place.
          if (_confirmingDiscard) {
            _keepEditing();
          } else {
            _showCreation(false);
          }
        },
        child: ClipRect(
          child: Stack(
            children: [
              // Keep the complete destination step's size, including a wrapping
              // header. The form fills it without changing the sheet's top edge.
              Visibility(
                visible: !_creating || _transition.isAnimating,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: _step(
                  active: !_creating,
                  offset: _listOffset,
                  // Scrim and drag-down wait for the write like Close and
                  // system Back do; there is no decision to show.
                  child: AppSheetDismissGuard(
                    enabled: state.isBusy,
                    onDismissAttempt: _ignoreDismissAttempt,
                    child: ActionBottomSheetLayout(
                      title: context.l10n.libraryAddToCollectionTitle,
                      closeLabel: context.l10n.commonClose,
                      onClose: state.isBusy ? null : _requestClose,
                      constrainBody: true,
                      bodyPadding: const EdgeInsets.only(
                        bottom: AppSpacing.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final content = switch (state.status) {
                              AddToCollectionStatus.initial ||
                              AddToCollectionStatus.loading => const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl,
                                ),
                                child: CenteredCircularProgressIndicator(),
                              ),
                              AddToCollectionStatus.failure
                                  when state.errorCode ==
                                      AddToCollectionErrorCode
                                          .loadCollectionsFailed =>
                                SingleChildScrollView(
                                  child: ErrorState(
                                    message: context
                                        .l10n
                                        .libraryLoadCollectionsFailed,
                                    retryLabel: context.l10n.commonRetry,
                                    onRetry: context
                                        .read<AddToCollectionCubit>()
                                        .load,
                                  ),
                                ),
                              _ => ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: math.min(
                                    constraints.maxHeight,
                                    2 * 48 +
                                        2 * AppSpacing.lg +
                                        2 * AppSpacing.md +
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(32),
                                  ),
                                ),
                                child: _CollectionContent(
                                  state: state,
                                  sourceCount: widget.sourceIds.length,
                                  onCollectionPressed: _addToCollection,
                                  onFavouritesPressed: state.isBusy
                                      ? null
                                      : _addToFavourites,
                                  onCreatePressed: state.isBusy
                                      ? null
                                      : () => _showCreation(true),
                                ),
                              ),
                            };

                            return content;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_creating || _transition.isAnimating)
                Positioned.fill(
                  child: _step(
                    active: _creating,
                    offset: _formOffset,
                    child: AppSheetDismissGuard(
                      enabled: _creating && _hasDraft,
                      onDismissAttempt: _requestClose,
                      child: AnimatedSwitcher(
                        duration: context.motion(AppMotion.short),
                        // The default switcher layout centres the shorter
                        // form inside the destination step's frame; the step
                        // must fill it so its command sits on the footer line.
                        layoutBuilder: _fillStepLayout,
                        child: _confirmingDiscard
                            ? _DiscardDraftStep(
                                key: const ValueKey(
                                  'addToCollectionDiscardStep',
                                ),
                                onKeepEditing: _keepEditing,
                                onDiscard: _discardDraft,
                                onClose: _requestClose,
                              )
                            : ActionBottomSheetLayout(
                                key: const ValueKey(
                                  'addToCollectionCreateStep',
                                ),
                                title: context.l10n.libraryNewCollection,
                                onBack: () => _showCreation(false),
                                backLabel: context.l10n.commonBack,
                                closeLabel: context.l10n.commonClose,
                                onClose: state.isBusy ? null : _requestClose,
                                constrainBody: true,
                                bodyPadding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                footer: _CreateCollectionAction(
                                  state: state,
                                  controller: _nameController,
                                  onCreate: _createAndAdd,
                                ),
                                child: _CreateCollectionContent(
                                  state: state,
                                  controller: _nameController,
                                  onCreate: _createAndAdd,
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
    );
  }
}

/// Discard decision for a typed collection name; same copy and safe-default
/// pairing as the Manage flow. Close keeps the decision visible.
class _DiscardDraftStep extends StatelessWidget {
  const _DiscardDraftStep({
    required this.onKeepEditing,
    required this.onDiscard,
    required this.onClose,
    super.key,
  });

  final VoidCallback onKeepEditing;
  final VoidCallback onDiscard;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionBottomSheetLayout(
      title: l10n.libraryDiscardChangesTitle,
      onBack: onKeepEditing,
      backLabel: l10n.commonBack,
      onClose: onClose,
      closeLabel: l10n.commonClose,
      constrainBody: true,
      footer: AppSheetActions(
        primaryLabel: l10n.commonKeepEditing,
        onPrimary: onKeepEditing,
        secondaryLabel: l10n.commonDiscardChanges,
        onSecondary: onDiscard,
        destructiveSecondary: true,
      ),
      child: SingleChildScrollView(
        child: Text(
          l10n.libraryDiscardChangesBody,
          style: context.text.bodyMedium,
        ),
      ),
    );
  }
}

/// Destination choices. Membership is supplied by the cubit, not queried per row.
class _CollectionContent extends StatelessWidget {
  const _CollectionContent({
    required this.state,
    required this.sourceCount,
    required this.onCollectionPressed,
    required this.onFavouritesPressed,
    required this.onCreatePressed,
  });

  final AddToCollectionState state;
  final int sourceCount;
  final ValueChanged<LibraryCollection> onCollectionPressed;
  final VoidCallback? onFavouritesPressed;
  final VoidCallback? onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 2,
          child: state.status == AddToCollectionStatus.submitting
              ? const LinearProgressIndicator()
              : null,
        ),
        Flexible(
          child: ScrollEdgeFadeStack(
            child: CustomScrollView(
              shrinkWrap: true,
              slivers: [
                SliverPadding(
                  padding: _destinationListPadding,
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.errorCode ==
                                    AddToCollectionErrorCode
                                        .updateCollectionFailed ||
                                state.errorCode ==
                                    AddToCollectionErrorCode
                                        .updateFavouritesFailed) ...[
                              Padding(
                                padding: _destinationLinePadding,
                                child: Text(
                                  _addToCollectionErrorMessage(
                                    l10n,
                                    state.errorCode!,
                                  ),
                                  style: text.bodyMedium.copyWith(
                                    color: colors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            _CollectionRow(
                              icon: AppIcons.collectionFavourites,
                              included: state.containingAll.contains(
                                CollectionRepository.favouritesCollectionId,
                              ),
                              label: l10n.libraryFavourites,
                              sourceCount: state.favouritesSourceCount,
                              enabled: !state.isBusy,
                              onPressed: onFavouritesPressed,
                            ),
                            const _DestinationDivider(),
                            if (state.collections.isEmpty)
                              Padding(
                                padding: _destinationLinePadding.add(
                                  const EdgeInsets.symmetric(
                                    vertical: AppSpacing.lg,
                                  ),
                                ),
                                child: Text(
                                  l10n.libraryCreateCollectionPrompt(
                                    sourceCount,
                                  ),
                                  style: text.bodyMedium.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (state.collections.isNotEmpty)
                        SliverList.separated(
                          itemCount: state.collections.length,
                          separatorBuilder: (_, _) =>
                              const _DestinationDivider(),
                          itemBuilder: (context, index) {
                            final collection = state.collections[index];
                            return _CollectionRow(
                              icon: AppIcons.collection,
                              included: state.containingAll.contains(
                                collection.id,
                              ),
                              label: collection.name,
                              sourceCount: collection.sourceCount,
                              enabled: !state.isBusy,
                              onPressed: () => onCollectionPressed(collection),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: AppDrillInRow(
            key: const ValueKey('libraryNewCollectionRow'),
            icon: AppIcons.collectionAdd,
            title: l10n.libraryNewCollection,
            enabled: onCreatePressed != null,
            onTap: onCreatePressed,
          ),
        ),
      ],
    );
  }
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
    final l10n = context.l10n;
    return ScrollEdgeFadeStack(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              enabled: !state.isBusy,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.libraryNewCollectionName,
              ),
              onSubmitted: (_) {
                if (!state.isBusy && controller.text.trim().isNotEmpty) {
                  onCreate();
                }
              },
            ),
            if (state.errorCode != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _addToCollectionErrorMessage(l10n, state.errorCode!),
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

/// Single footer command of the name form; leaving is the header's job
/// (Back/Close). The write shows as a spinner in the button rather than a
/// progress strip over the field.
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => FilledButton(
        onPressed: state.isBusy || value.text.trim().isEmpty ? null : onCreate,
        child: AppBusyButtonLabel(l10n.libraryCreateAndAdd, busy: state.isBusy),
      ),
    );
  }
}

class _DestinationDivider extends StatelessWidget {
  const _DestinationDivider();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: _destinationLinePadding, child: Divider());
}

// Guarded only while a write is in flight: the attempt is simply ignored.
void _ignoreDismissAttempt() {}

// AnimatedSwitcher layout that stretches every step to the switcher's bounds
// instead of centring it (see AnimatedSwitcher.defaultLayoutBuilder).
Widget _fillStepLayout(Widget? currentChild, List<Widget> previousChildren) =>
    Stack(
      fit: StackFit.expand,
      children: [...previousChildren, ?currentChild],
    );

String _addToCollectionErrorMessage(
  ReadflexLocalizations l10n,
  AddToCollectionErrorCode errorCode,
) {
  return switch (errorCode) {
    AddToCollectionErrorCode.loadCollectionsFailed =>
      l10n.libraryLoadCollectionsFailed,
    AddToCollectionErrorCode.updateCollectionFailed =>
      l10n.libraryUpdateCollectionFailed,
    AddToCollectionErrorCode.updateFavouritesFailed =>
      l10n.libraryUpdateFavouritesFailed,
    AddToCollectionErrorCode.collectionNameRequired =>
      l10n.libraryCollectionNameRequired,
    AddToCollectionErrorCode.createCollectionFailed =>
      l10n.libraryCreateCollectionFailed,
  };
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    this.included = false,
    required this.icon,
    required this.label,
    required this.sourceCount,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool included;
  final String label;
  final int sourceCount;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    // Included rows stay readable; only a busy sheet mutes the destination.
    final titleColor = enabled ? colors.onSurface : colors.onSurfaceVariant;

    return Semantics(
      label: included ? context.l10n.libraryAddedToCollection : null,
      selected: included,
      child: InkWell(
        onTap: enabled && !included ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: _destinationRowInset,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppIconSize.sm,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge.copyWith(color: titleColor),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$sourceCount',
                style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              // A 48dp slot like the picker's menu column keeps counts
              // aligned across both sheets, marked or not.
              SizedBox(
                width: AppSizes.buttonHeight,
                child: Center(
                  child: SizedBox.square(
                    dimension: AppIconSize.sm,
                    child: included
                        ? Icon(
                            AppIcons.check,
                            size: AppIconSize.sm,
                            color: context.actionForeground,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
