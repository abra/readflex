import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'add_to_collection_cubit.dart';

Future<bool?> showAddToCollectionSheet({
  required BuildContext context,
  required AddToCollectionCubit cubit,
  required Set<String> sourceIds,
}) {
  cubit.load();
  return showAppBottomSheet<bool>(
    context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _AddToCollectionSheet(sourceIds: sourceIds),
    ),
  );
}

class _AddToCollectionSheet extends StatefulWidget {
  const _AddToCollectionSheet({required this.sourceIds});

  final Set<String> sourceIds;

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addToCollection(LibraryCollection collection) async {
    final cubit = context.read<AddToCollectionCubit>();
    await cubit.addToCollection(
      collectionId: collection.id,
      sourceIds: widget.sourceIds,
    );
    if (!mounted || cubit.state.status == AddToCollectionStatus.failure) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _createAndAdd() async {
    final cubit = context.read<AddToCollectionCubit>();
    await cubit.createAndAdd(
      name: _nameController.text,
      sourceIds: widget.sourceIds,
    );
    if (!mounted || cubit.state.status == AddToCollectionStatus.failure) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ActionBottomSheetLayout(
      title: 'Add to collection',
      child: BlocBuilder<AddToCollectionCubit, AddToCollectionState>(
        builder: (context, state) {
          final content = switch (state.status) {
            AddToCollectionStatus.initial ||
            AddToCollectionStatus.loading => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: CenteredCircularProgressIndicator(),
            ),
            _ => _CollectionContent(
              state: state,
              nameController: _nameController,
              sourceCount: widget.sourceIds.length,
              onCollectionPressed: _addToCollection,
              onCreatePressed: state.isBusy ? null : _createAndAdd,
              onCancelPressed: state.isBusy
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
          };

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: content,
          );
        },
      ),
    );
  }
}

class _CollectionContent extends StatelessWidget {
  const _CollectionContent({
    required this.state,
    required this.nameController,
    required this.sourceCount,
    required this.onCollectionPressed,
    required this.onCreatePressed,
    required this.onCancelPressed,
  });

  final AddToCollectionState state;
  final TextEditingController nameController;
  final int sourceCount;
  final ValueChanged<LibraryCollection> onCollectionPressed;
  final VoidCallback? onCreatePressed;
  final VoidCallback? onCancelPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            style: text.bodyMedium.copyWith(color: colors.error),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (state.collections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              'Create a collection for $sourceCount selected item${sourceCount == 1 ? '' : 's'}.',
              style: text.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: state.collections.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: context.appColors.divider,
              ),
              itemBuilder: (context, index) {
                final collection = state.collections[index];
                return _CollectionRow(
                  collection: collection,
                  enabled: !state.isBusy,
                  onPressed: () => onCollectionPressed(collection),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        TextField(
          controller: nameController,
          enabled: !state.isBusy,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'New collection name',
          ),
          onSubmitted: (_) => onCreatePressed?.call(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancelPressed,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: onCreatePressed,
                icon: const Icon(AppIcons.add, size: AppIconSize.sm),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.collection,
    required this.enabled,
    required this.onPressed,
  });

  final LibraryCollection collection;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return InkWell(
      onTap: enabled ? onPressed : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.collection,
              size: AppIconSize.sm,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge.copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${collection.sourceCount}',
              style: text.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
