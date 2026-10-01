import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_selection_cubit.dart';

/// Scaffold reserves this bar's height so bulk actions never cover sources.
class LibrarySelectionBar extends StatelessWidget {
  const LibrarySelectionBar({
    required this.onAddToCollection,
    required this.onDelete,
    super.key,
  });

  final VoidCallback onAddToCollection;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) => BlocSelector<LibrarySelectionCubit, LibrarySelectionState, int>(
    selector: (state) => state.selectedIds.length,
    builder: (context, count) {
      if (count == 0) return const SizedBox.shrink();
      final l10n = context.l10n;
      return Material(
        color: context.colors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    AppPlainIconButton(
                      icon: AppIcons.close,
                      tooltip: l10n.libraryCancelSelection,
                      onPressed: context.read<LibrarySelectionCubit>().clear,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.librarySelectedCount(count),
                          style: context.text.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddToCollection,
                        icon: const Icon(
                          AppIcons.collectionAdd,
                          size: AppIconSize.sm,
                        ),
                        label: Text(
                          l10n.libraryAddToCollection,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppPlainIconButton(
                      icon: AppIcons.delete,
                      tooltip: l10n.commonDelete,
                      color: context.colors.error,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
