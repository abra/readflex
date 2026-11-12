import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Platform text input. Controllers and focus nodes retain their ownership.
class AppTextField extends StatefulWidget {
  static EdgeInsetsGeometry contentPaddingOf(BuildContext context) =>
      context.isCupertino
      ? const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        )
      : context.theme.inputDecorationTheme.contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            );

  const AppTextField({
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.readOnly = false,
    this.canRequestFocus = true,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.style,
    this.labelText,
    this.hintText,
    this.hint,
    this.errorText,
    this.error,
    this.hasError = false,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
    this.filled = true,
    this.fillColor,
    this.borderless = false,
    this.borderRadius,
    this.dense = false,
    this.contentPadding,
    this.scrollController,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final GestureTapCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final bool readOnly;
  final bool canRequestFocus;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final String? labelText;
  final String? hintText;
  final Widget? hint;
  final String? errorText;
  final Widget? error;
  final bool hasError;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final bool filled;
  final Color? fillColor;
  final bool borderless;
  final BorderRadius? borderRadius;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;
  final ScrollController? scrollController;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  TextEditingController? _ownedController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != null && widget.controller == null) {
      _ownedController ??= TextEditingController.fromValue(
        oldWidget.controller!.value,
      );
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      final borderless = widget.borderRadius == null
          ? material.InputBorder.none
          : material.OutlineInputBorder(
              borderRadius: widget.borderRadius!,
              borderSide: BorderSide.none,
            );
      final silentError =
          widget.hasError && widget.error == null && widget.errorText == null;
      final decorationTheme = context.theme.inputDecorationTheme;
      final errorBorder =
          (decorationTheme.enabledBorder ??
                  decorationTheme.border ??
                  borderless)
              .copyWith(borderSide: BorderSide(color: context.colors.error));
      return material.TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: widget.onEditingComplete,
        onTap: widget.onTap,
        onTapOutside: widget.onTapOutside,
        readOnly: widget.readOnly,
        canRequestFocus: widget.canRequestFocus,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        textAlign: widget.textAlign,
        textAlignVertical: widget.textAlignVertical,
        style: widget.style,
        scrollController: widget.scrollController,
        decoration: material.InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hint == null ? widget.hintText : null,
          hint: widget.hint,
          errorText: widget.errorText,
          error: widget.error,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          prefixIconConstraints: widget.prefixIconConstraints,
          suffixIconConstraints: widget.suffixIconConstraints,
          filled: widget.filled,
          isDense: widget.dense,
          fillColor: widget.fillColor,
          contentPadding: widget.contentPadding,
          border: widget.borderless ? borderless : null,
          enabledBorder: silentError
              ? errorBorder
              : widget.borderless
              ? borderless
              : null,
          focusedBorder: silentError
              ? errorBorder
              : widget.borderless
              ? borderless
              : null,
        ),
      );
    }
    final hasError =
        widget.hasError || widget.errorText != null || widget.error != null;
    final colors = context.colors;
    final padding =
        widget.contentPadding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
    final direction = Directionality.of(context);
    final resolvedPadding = padding.resolve(direction);
    final hintStart = direction == TextDirection.ltr
        ? resolvedPadding.left
        : resolvedPadding.right;
    final hintEnd = direction == TextDirection.ltr
        ? resolvedPadding.right
        : resolvedPadding.left;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.labelText != null) ...[
          Text(widget.labelText!, style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
        ],
        Flexible(
          fit: FlexFit.loose,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            descendantsAreFocusable: widget.canRequestFocus,
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.inputHeight,
                  ),
                  child: cupertino.CupertinoTextField(
                    controller: _controller,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    onEditingComplete: widget.onEditingComplete,
                    onTap: widget.onTap,
                    onTapOutside: widget.onTapOutside,
                    readOnly: widget.readOnly,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    maxLines: widget.maxLines,
                    minLines: widget.minLines,
                    maxLength: widget.maxLength,
                    inputFormatters: widget.inputFormatters,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textCapitalization: widget.textCapitalization,
                    autocorrect: widget.autocorrect,
                    enableSuggestions: widget.enableSuggestions,
                    textAlign: widget.textAlign,
                    textAlignVertical: widget.textAlignVertical,
                    style: widget.style ?? context.text.bodyLarge,
                    scrollController: widget.scrollController,
                    padding: padding,
                    placeholder: widget.hintText,
                    placeholderStyle: (widget.style ?? context.text.bodyLarge)
                        .copyWith(
                          color: widget.hint == null
                              ? cupertino.CupertinoColors.placeholderText
                                    .resolveFrom(
                                      context,
                                    )
                              : const Color(0x00000000),
                        ),
                    decoration: BoxDecoration(
                      color: widget.filled
                          ? widget.fillColor ??
                                cupertino.CupertinoColors.tertiarySystemFill
                                    .resolveFrom(context)
                          : const Color(0x00000000),
                      borderRadius:
                          widget.borderRadius ??
                          BorderRadius.circular(AppRadius.md),
                      border: hasError
                          ? Border.all(color: colors.error)
                          : widget.borderless
                          ? null
                          : Border.all(
                              color: cupertino.CupertinoColors.separator
                                  .resolveFrom(context),
                              width: .5,
                            ),
                    ),
                    prefix: widget.prefixIcon == null
                        ? null
                        : ConstrainedBox(
                            constraints:
                                widget.prefixIconConstraints ??
                                const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                            child: widget.prefixIcon,
                          ),
                    suffix: widget.suffixIcon == null
                        ? null
                        : ConstrainedBox(
                            constraints:
                                widget.suffixIconConstraints ??
                                const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                            child: widget.suffixIcon,
                          ),
                  ),
                ),
                if (widget.hint != null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? PositionedDirectional(
                            start:
                                hintStart +
                                (widget.prefixIcon == null
                                    ? 0
                                    : widget.prefixIconConstraints?.minWidth ??
                                          48),
                            end:
                                hintEnd +
                                (widget.suffixIcon == null
                                    ? 0
                                    : widget.suffixIconConstraints?.minWidth ??
                                          48),
                            child: IgnorePointer(
                              child: ExcludeSemantics(child: widget.hint!),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
        if (widget.error != null || widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          widget.error ??
              Text(
                widget.errorText!,
                style: context.text.bodySmall.copyWith(color: colors.error),
              ),
        ],
      ],
    );
  }
}
