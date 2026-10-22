import 'package:flutter/widgets.dart';

/// One step of a sheet flow whose steps slide in place, such as Display and
/// Language or Appearance and Font.
///
/// An inactive step stops its tickers and leaves semantics, focus and pointer
/// input to the active one while it slides by [position]. [visible] is the
/// caller's on-screen state, usually [active] or a running transition: a
/// hidden step stays laid out offstage, or keeps its size and state with
/// [maintainSize] when it is the step that sizes the flow.
///
/// [textDirection] mirrors the slide; pass the direction captured when the
/// transition started so a locale change cannot flip it midway. Without it
/// the ambient direction applies.
class AppSheetStep extends StatelessWidget {
  const AppSheetStep({
    required this.active,
    required this.visible,
    required this.position,
    required this.child,
    this.maintainSize = false,
    this.textDirection,
    super.key,
  });

  final bool active;
  final bool visible;
  final Animation<Offset> position;
  final bool maintainSize;
  final TextDirection? textDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = TickerMode(
      enabled: active,
      child: ExcludeSemantics(
        excluding: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: SlideTransition(
              position: position,
              textDirection: textDirection ?? Directionality.of(context),
              child: child,
            ),
          ),
        ),
      ),
    );
    return maintainSize
        ? Visibility(
            visible: visible,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: content,
          )
        : Offstage(offstage: !visible, child: content);
  }
}
