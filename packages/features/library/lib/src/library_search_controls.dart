import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

/// Search contents of the Library capsule. The screen owns editing and focus.
class LibrarySearchControls extends StatelessWidget {
  const LibrarySearchControls({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
    required this.scrollController,
    this.canRequestFocus = true,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final bool canRequestFocus;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = context.text.bodyMedium.copyWith(
      color: context.colors.onSurface,
    );
    return Row(
      children: [
        AppPlainIconButton(
          key: const ValueKey('librarySearchCloseButton'),
          tooltip: l10n.commonBack,
          icon: AppIcons.back,
          onPressed: onClose,
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('librarySearchField'),
            controller: controller,
            focusNode: focusNode,
            scrollController: scrollController,
            canRequestFocus: canRequestFocus,
            style: style,
            onChanged: onChanged,
            onSubmitted: (_) => focusNode.unfocus(),
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hint: SearchFieldHint(
                text: l10n.librarySearchHint,
                compactText: l10n.commonSearch,
                style: style.copyWith(color: context.colors.onSurfaceVariant),
              ),
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) => value.text.isEmpty
              ? const SizedBox.shrink()
              : AppPlainIconButton(
                  key: const ValueKey('librarySearchClearButton'),
                  tooltip: l10n.commonClearSearch,
                  icon: AppIcons.close,
                  iconSize: AppIconSize.xs,
                  color: context.actionForeground,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ],
    );
  }
}

/// Frozen exit contents: a closing search never keeps a second editable field.
class LibrarySearchSnapshot extends StatelessWidget {
  const LibrarySearchSnapshot({
    required this.text,
    required this.scrollOffset,
    super.key,
  });

  final String text;
  final double scrollOffset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: AppSizes.buttonHeight,
        child: Icon(
          AppIcons.back,
          size: AppPlainIconButton.defaultIconSizeOf(context),
          color: context.colors.onSurface,
        ),
      ),
      Expanded(
        child: text.isEmpty
            ? SearchFieldHint(
                text: context.l10n.librarySearchHint,
                compactText: context.l10n.commonSearch,
                style: context.text.bodyMedium.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              )
            : _SearchTextViewport(
                text: text,
                scrollOffset: scrollOffset,
              ),
      ),
      if (text.isNotEmpty)
        SizedBox.square(
          dimension: AppSizes.buttonHeight,
          child: Icon(
            AppIcons.close,
            size: AppIconSize.xs,
            color: context.actionForeground,
          ),
        ),
    ],
  );
}

class _SearchTextViewport extends StatefulWidget {
  const _SearchTextViewport({required this.text, required this.scrollOffset});

  final String text;
  final double scrollOffset;

  @override
  State<_SearchTextViewport> createState() => _SearchTextViewportState();
}

class _SearchTextViewportState extends State<_SearchTextViewport> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: widget.scrollOffset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Directionality(
        // RenderEditable's horizontal viewport always scrolls to the right.
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          key: const ValueKey('librarySearchSnapshotViewport'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            // Match the editable line's cursor width and trailing gap.
            padding: const EdgeInsets.only(right: 3),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: (constraints.maxWidth - 3).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Text(
                widget.text,
                textDirection: direction,
                maxLines: 1,
                softWrap: false,
                style: context.text.bodyMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
