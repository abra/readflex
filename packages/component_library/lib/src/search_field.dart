import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Styled search text field with prefix icon and optional clear button.
///
/// When [controller] is provided and the field is non-empty, a clear
/// button appears as a suffix icon.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.hintText,
    this.clearButtonSemanticsLabel = 'Clear search',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.textInputAction,
    super.key,
  });

  final String hintText;
  final String clearButtonSemanticsLabel;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// Keyboard action key; null keeps the platform default.
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clearIconColor = colors.brightness == Brightness.dark
        ? colors.primaryFixedDim
        : colors.primary;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: textInputAction,
      style: context.text.bodyMedium.copyWith(color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          AppIcons.search,
          size: AppIconSize.xs,
          color: colors.onSurface.withValues(alpha: 0.55),
        ),
        suffixIcon: controller != null
            ? ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return AppPlainIconButton(
                    icon: AppIcons.close,
                    iconSize: AppIconSize.xs,
                    color: clearIconColor,
                    tooltip: clearButtonSemanticsLabel,
                    onPressed: () {
                      controller!.clear();
                      onChanged?.call('');
                    },
                  );
                },
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.buttonHeight,
          minHeight: AppSizes.buttonHeight,
        ),
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
