import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_spacing.dart';

/// Styled search text field with prefix icon and optional clear button.
///
/// When [controller] is provided and the field is non-empty, a clear
/// button appears as a suffix icon.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.hintText,
    this.controller,
    this.onChanged,
    super.key,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextField(
      controller: controller,
      onChanged: onChanged,
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
                  return IconButton(
                    icon: const Icon(AppIcons.close, size: AppIconSize.xs),
                    onPressed: () {
                      controller!.clear();
                      onChanged?.call('');
                    },
                  );
                },
              )
            : null,
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
