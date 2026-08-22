# ReadFlex patch

This directory vendors `flutter_inappwebview_ios` 1.1.2.

The upstream implementation filters legacy `UIMenuController` actions through
`canPerformAction`, but modern iOS edit menus are built through
`UIEditMenuInteraction`. Its `buildMenu` implementation also removes only the
Lookup menu before WebKit populates the builder. As a result,
`disableContextMenu` still allows system actions such as Copy Link with
Highlight.

The local patch calls `super.buildMenu` first and then clears the root menu
children when default context-menu items are disabled. Clearing the root also
removes direct actions added by newer iOS releases before the menu can flash.
`willPresentEditMenu` keeps an explicit dismissal as a defensive fallback.
The root `pubspec.yaml` selects this implementation through
`dependency_overrides`.
