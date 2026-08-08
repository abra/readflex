# ReadFlex patch

This directory vendors `flutter_inappwebview_ios` 1.1.2.

The upstream implementation filters legacy `UIMenuController` actions through
`canPerformAction`, but modern iOS edit menus are built through
`UIEditMenuInteraction`. Its `buildMenu` implementation also removes only the
Lookup menu before WebKit populates the builder. As a result,
`disableContextMenu` still allows system actions such as Copy Link with
Highlight.

The local patch calls `super.buildMenu` first and then removes the standard
edit, share, and lookup menus when default context-menu items are disabled.
The root `pubspec.yaml` selects this implementation through
`dependency_overrides`.
