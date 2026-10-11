import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';
import 'search_field_hint.dart';
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
    this.compactHintText,
    this.clearButtonSemanticsLabel = 'Clear search',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.textInputAction,
    super.key,
  });

  final String hintText;

  /// Shorter hint shown when [hintText] would be cut, such as "Search" for
  /// "Search chapters" on a narrow screen with large text. Screen readers
  /// still hear [hintText].
  final String? compactHintText;
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
    final compact = compactHintText;
    final fieldStyle = context.text.bodyMedium.copyWith(
      color: colors.onSurface,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: textInputAction,
      style: fieldStyle,
      decoration: InputDecoration(
        hintText: compact == null ? hintText : null,
        hint: compact == null
            ? null
            : SearchFieldHint(
                text: hintText,
                compactText: compact,
                style: _hintStyle(context, fieldStyle),
              ),
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

  // A custom hint widget gets no style from the decorator, so resolve the
  // chain it applies to `hintText`: the Material 3 body style, the field's
  // own style, the default hint color, then the theme's hint style.
  static TextStyle _hintStyle(BuildContext context, TextStyle fieldStyle) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge!
        .merge(fieldStyle)
        .merge(TextStyle(color: theme.colorScheme.onSurfaceVariant))
        .merge(theme.inputDecorationTheme.hintStyle);
  }
}
