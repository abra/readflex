import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'library_bloc.dart';
import 'manage_collection_cubit.dart';

enum ManageCollectionSheetResult { deleted }

enum _ManageCollectionStep { manage, confirmDelete }

const double _collectionSourcesMaxHeight = 260;

Future<ManageCollectionSheetResult?> showManageManualCollectionSheet({
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
      child: _ManageManualCollectionSheet(
        scope: scope,
        sources: sources,
        onCollectionChanged: onCollectionChanged,
      ),
    ),
  );
}

class _ManageManualCollectionSheet extends StatefulWidget {
  const _ManageManualCollectionSheet({
    required this.scope,
    required this.sources,
    required this.onCollectionChanged,
  });

  final LibraryCollectionScope scope;
  final List<LibrarySource> sources;
  final VoidCallback onCollectionChanged;

  @override
  State<_ManageManualCollectionSheet> createState() =>
      _ManageManualCollectionSheetState();
}

class _ManageManualCollectionSheetState
    extends State<_ManageManualCollectionSheet> {
  late final TextEditingController _nameController;
  late String _currentName;
  final _removedSourceIds = <String>{};
  var _step = _ManageCollectionStep.manage;

  @override
  void initState() {
    super.initState();
    _currentName = widget.scope.label;
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
    setState(() => _step = _ManageCollectionStep.confirmDelete);
  }

  void _cancelDeleteConfirmation() {
    setState(() => _step = _ManageCollectionStep.manage);
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final hasNameChange = name != _currentName;
    if (name.isEmpty || (!hasNameChange && _removedSourceIds.isEmpty)) return;

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
    setState(() => _removedSourceIds.add(source.id));
  }

  Future<void> _deleteCollection() async {
    final cubit = context.read<ManageCollectionCubit>();
    final deleted = await cubit.deleteCollection(widget.scope.id);
    if (!mounted || !deleted) return;
    widget.onCollectionChanged();
    Navigator.of(context).pop(ManageCollectionSheetResult.deleted);
  }

  String get _title => switch (_step) {
    _ManageCollectionStep.manage => 'Manage collection',
    _ManageCollectionStep.confirmDelete => 'Delete collection?',
  };

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: _title,
      child: BlocBuilder<ManageCollectionCubit, ManageCollectionState>(
        builder: (context, state) {
          final visibleSources = widget.sources
              .where((source) => !_removedSourceIds.contains(source.id))
              .toList(growable: false);
          final name = _nameController.text.trim();
          final canSave =
              !state.isBusy &&
              name.isNotEmpty &&
              (name != _currentName || _removedSourceIds.isNotEmpty);

          final child = switch (_step) {
            _ManageCollectionStep.manage => _ManageCollectionContent(
              key: const ValueKey('manageCollectionContent'),
              state: state,
              nameController: _nameController,
              visibleSources: visibleSources,
              initialSourceCount: widget.sources.length,
              canSave: canSave,
              onSave: _saveChanges,
              onRemoveSource: _stageSourceRemoval,
              onDeletePressed: _showDeleteConfirmation,
            ),
            _ManageCollectionStep.confirmDelete =>
              _DeleteCollectionConfirmationContent(
                key: const ValueKey('deleteCollectionContent'),
                state: state,
                collectionName: _currentName,
                onCancel: _cancelDeleteConfirmation,
                onDelete: _deleteCollection,
              ),
          };

          return _ManageCollectionStepSwitcher(child: child);
        },
      ),
    );
  }
}

class _ManageCollectionStepSwitcher extends StatelessWidget {
  const _ManageCollectionStepSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => ClipRect(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        ),
      ),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ManageCollectionContent extends StatelessWidget {
  const _ManageCollectionContent({
    required this.state,
    required this.nameController,
    required this.visibleSources,
    required this.initialSourceCount,
    required this.canSave,
    required this.onSave,
    required this.onRemoveSource,
    required this.onDeletePressed,
    super.key,
  });

  final ManageCollectionState state;
  final TextEditingController nameController;
  final List<LibrarySource> visibleSources;
  final int initialSourceCount;
  final bool canSave;
  final Future<void> Function() onSave;
  final ValueChanged<LibrarySource> onRemoveSource;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        TextField(
          controller: nameController,
          enabled: !state.isBusy,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(),
          onSubmitted: (_) => canSave ? onSave() : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Items',
          style: context.text.labelSmall.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _CollectionSourcesList(
          initialSourceCount: initialSourceCount,
          visibleSources: visibleSources,
          enabled: !state.isBusy,
          onRemoveSource: onRemoveSource,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
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
        ),
      ],
    );
  }
}

class _CollectionSourcesList extends StatelessWidget {
  const _CollectionSourcesList({
    required this.initialSourceCount,
    required this.visibleSources,
    required this.enabled,
    required this.onRemoveSource,
  });

  final int initialSourceCount;
  final List<LibrarySource> visibleSources;
  final bool enabled;
  final ValueChanged<LibrarySource> onRemoveSource;

  @override
  Widget build(BuildContext context) {
    if (visibleSources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No items in this collection',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _collectionSourcesMaxHeight),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: visibleSources.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: context.appColors.divider,
        ),
        itemBuilder: (context, index) {
          final source = visibleSources[index];
          return _CollectionSourceRow(
            source: source,
            enabled: enabled,
            onRemovePressed: () => onRemoveSource(source),
          );
        },
      ),
    );
  }
}

class _DeleteCollectionConfirmationContent extends StatelessWidget {
  const _DeleteCollectionConfirmationContent({
    required this.state,
    required this.collectionName,
    required this.onCancel,
    required this.onDelete,
    super.key,
  });

  final ManageCollectionState state;
  final String collectionName;
  final VoidCallback onCancel;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        Text(
          'This removes "$collectionName" only. Books and articles stay in your library.',
          style: context.text.bodyMedium,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
