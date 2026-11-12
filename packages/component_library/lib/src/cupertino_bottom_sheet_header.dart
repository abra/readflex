part of 'bottom_sheet_header.dart';

class _CupertinoBottomSheetHeader extends StatelessWidget {
  const _CupertinoBottomSheetHeader({required this.header});

  final BottomSheetHeader header;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final insets = header.padding.resolve(direction);
    final hasNavigation = header.backLabel != null || header.closeLabel != null;
    final outset = hasNavigation
        ? math.min(
            AppPlainIconButton.defaultIconOutsetOf(context),
            math.min(insets.left, insets.right),
          )
        : 0.0;
    final close = header.closeLabel == null
        ? null
        : _CupertinoSheetCloseButton(
            label: header.closeLabel!,
            onPressed: header.onClose,
          );
    return Padding(
      padding: insets.copyWith(
        left: insets.left - outset,
        right: insets.right - outset,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        child: BottomSheetTitleBar(
          centerTitle: true,
          leading: header.backLabel == null
              ? null
              : AppPlainIconButton(
                  icon: direction == TextDirection.rtl
                      ? AppIcons.chevronRight
                      : AppIcons.chevronLeft,
                  tooltip: header.backLabel!,
                  onPressed: header.onBack,
                ),
          title: Semantics(
            header: true,
            namesRoute: true,
            child: Text(
              header.title,
              textAlign: TextAlign.center,
              style: context.text.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing: _CupertinoSheetHeaderActions(
            action: header.trailing,
            close: close,
          ),
          compactTrailing: header.compactTrailing == null
              ? null
              : _CupertinoSheetHeaderActions(
                  action: header.compactTrailing,
                  close: close,
                ),
          spacing: AppSpacing.sm,
          overflowSpacing: AppSpacing.sm,
          minTitleScale: BottomSheetHeader.minTitleScale,
        ),
      ),
    );
  }
}

class _CupertinoSheetHeaderActions extends StatelessWidget {
  const _CupertinoSheetHeaderActions({this.action, this.close});

  final Widget? action;
  final Widget? close;

  @override
  Widget build(BuildContext context) {
    if (action == null && close == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action != null) Flexible(child: action!),
        if (action != null && close != null)
          const SizedBox(width: AppSpacing.xs),
        ?close,
      ],
    );
  }
}

class _CupertinoSheetCloseButton extends StatelessWidget {
  const _CupertinoSheetCloseButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppPlainIconButton(
    tooltip: label,
    onPressed: onPressed,
    color: CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    ),
    iconWidget: SizedBox.square(
      dimension: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.tertiarySystemFill,
            context,
          ),
        ),
        child: const Icon(AppIcons.close, size: 18),
      ),
    ),
  );
}
