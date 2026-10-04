import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_selection_cubit.dart';

const _actionInset =
    AppSpacing.lg - (AppSizes.buttonHeight - AppIconSize.sm) / 2;

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
        child: AppBottomSafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: _actionInset,
                  end: AppSpacing.lg,
                ),
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
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  0,
                  _actionInset,
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
