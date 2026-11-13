import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_appearance_cubit.dart';

/// Options keep an 8dp ink inset like the Library Language sheet; the body
/// gutter gives it back so text and check land on the 24dp sheet gutter.
const double _optionInkInset = AppSpacing.sm;

/// Font selection within the appearance route, sharing its source override.
class ReaderFontSheet extends StatelessWidget {
  const ReaderFontSheet({
    required this.onBack,
    required this.onClose,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fontId = context.select<ReaderAppearanceCubit, String>(
      (cubit) => cubit.state.effectiveAppearance.fontId,
    );
    final selected = ReaderFontPreset.fromId(fontId);
    return ActionBottomSheetLayout.scrollable(
      title: context.l10n.readerFont,
      expandBody: AppWindowSize.isWide(context),
      onBack: onBack,
      backLabel: context.l10n.commonBack,
      onClose: onClose,
      closeLabel: context.l10n.commonClose,
      bodyPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl - _optionInkInset,
        0,
        AppSpacing.xl - _optionInkInset,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final preset in ReaderFontPreset.values) ...[
            if (preset != ReaderFontPreset.values.first)
              const SizedBox(height: AppSpacing.sm),
            _FontOption(
              preset: preset,
              selected: preset == selected,
              onPressed: () =>
                  context.read<ReaderAppearanceCubit>().setFont(preset.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FontOption extends StatelessWidget {
  const _FontOption({
    required this.preset,
    required this.selected,
    required this.onPressed,
  });

  final ReaderFontPreset preset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected
        ? colors.selectedControlForeground
        : colors.onSurface;
    final shape = AppSurfaceAppearance.resolve(
      context,
      AppSurfaceRole.field,
    ).shape.copyWith(side: BorderSide.none);
    return Semantics(
      key: ValueKey('reader-font-option-${preset.id}'),
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: preset.label,
      excludeSemantics: true,
      focusable: true,
      onTap: onPressed,
      child: AppSurface(
        role: AppSurfaceRole.field,
        color: selected ? colors.selectedControlBackground : colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: AppTappable(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.buttonHeight * 2,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _optionInkInset,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preset.label,
                          key: ValueKey('reader-font-${preset.id}'),
                          style: context.text.labelLarge.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox.square(
                        dimension: AppIconSize.sm,
                        child: selected
                            ? Icon(
                                AppIcons.check,
                                size: AppIconSize.sm,
                                color: foreground,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.readerFontSample,
                    key: ValueKey('reader-font-sample-${preset.id}'),
                    style: context.text.bodyLarge.copyWith(
                      fontFamily: preset.fontFamily,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: foreground,
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
