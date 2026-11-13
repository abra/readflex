part of 'show_app_bottom_sheet.dart';

/// Expanded placement stays in the same route when the window is resized.
class _ExpandedAppSheet extends StatelessWidget {
  const _ExpandedAppSheet({
    required this.presentation,
    required this.animation,
    required this.child,
  });

  final AppSheetPresentation presentation;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contextual = presentation == AppSheetPresentation.contextual;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        left: !contextual,
        right: !contextual,
        bottom: !contextual,
        minimum: contextual ? EdgeInsets.zero : const EdgeInsets.all(24),
        child: Align(
          alignment: switch (presentation) {
            AppSheetPresentation.contextual => AlignmentDirectional.centerEnd,
            AppSheetPresentation.actions => AlignmentDirectional.bottomEnd,
            _ => Alignment.center,
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: contextual
                  ? AppSizes.sidePanelWidth
                  : AppCupertinoSheetSurface.maxWidth,
              maxWidth: contextual
                  ? AppSizes.sidePanelWidth
                  : AppCupertinoSheetSurface.maxWidth,
              minHeight: contextual ? double.infinity : 0,
            ),
            child: _ExpandedAppSheetTransition(
              presentation: presentation,
              animation: animation,
              child: AppSurface(
                role: contextual
                    ? AppSurfaceRole.sidePanel
                    : AppSurfaceRole.modal,
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: contextual,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .removePadding(
                          removeTop: true,
                          removeBottom: true,
                          removeLeft: true,
                          removeRight: true,
                        )
                        .removeViewInsets(removeBottom: true),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedAppSheetTransition extends StatelessWidget {
  const _ExpandedAppSheetTransition({
    required this.presentation,
    required this.animation,
    required this.child,
  });

  final AppSheetPresentation presentation;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final progress = Curves.easeOutCubic.transform(
        animation.value.clamp(0.0, 1.0),
      );
      final trailing = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
      return Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: presentation == AppSheetPresentation.contextual
              ? Offset(24 * trailing * (1 - progress), 0)
              : Offset(0, 12 * (1 - progress)),
          child: child,
        ),
      );
    },
  );
}
