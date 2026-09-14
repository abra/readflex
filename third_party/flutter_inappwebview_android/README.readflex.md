# Readflex patch

This directory vendors `flutter_inappwebview_android` 1.1.3 from the published
pub.dev package. The upstream license and sources are retained. The root
`pubspec.yaml` selects it through `dependency_overrides`.

## Native text selection

Upstream `disableContextMenu` clears the Android action menu and calls
`ActionMode.finish()`. Finishing the mode also dismisses WebView's selection
handles, although the DOM range may remain selected.

Both `InAppWebView.startActionMode` overloads now wrap the platform callback
when `disableContextMenu` is enabled. `SelectionActionModeCallback` lets WebView
create/prepare the mode, then clears menu items without finishing selection.
Creation results, destruction and `Callback2` content geometry are delegated.
When context menus are enabled, the upstream path remains unchanged.

Visible Readflex readers additionally send the private, reader-only setting
`useCustomSelectionHandles` through their `InAppWebViewSettings.toMap()` adapter.
It defaults to false and is independent of `disableContextMenu`. When enabled,
the platform long-click listener consumes native selection UI and sends a
`readflex-long-press` event with normalized viewport coordinates to the reader.
The JS runtime creates a DOM selection using browser word boundaries and owns
both handles from that point onward. There are no transparent native handles,
theme overrides, WebView reflection, JS long-press timers or selection polling.
The existing long-press hit-test callback is preserved. Other WebViews keep the
native selection path, and composition/selection behavior is unchanged.

## Reader magnifier

The private `_readerSelectionMagnifier(x, y, visible)` JavaScript interface
accepts only normalized viewport coordinates and visibility. It does not send
selected text through Flutter or expose screenshots to JavaScript. It is gated
by `useCustomSelectionHandles` and an active physical touch on this WebView;
other WebViews cannot display it. The existing bridge is visible to frames, so
this is a reader UI enhancement, not a privileged content or capture API.

`ReaderSelectionMagnifier` owns the native Android `Magnifier` (API 28+) and
batches requests on animation frames. A gesture token prevents previously queued
bridge requests from resurrecting the loupe after release, cancellation or a new
touch. Focus loss, pause, hidden window, detachment and disposal dismiss it even
if JavaScript cannot run. Native surface errors disable it for the current
gesture without affecting selection. API 24-27 retain working selection without
a loupe. No polling timer is installed.

The source is the moving text boundary in WebView coordinates, not the finger.
On API 29+ a compact rounded aperture avoids magnifying the DOM knob below the
line. Repeated source coordinates use `Magnifier.update()` because WebView may
finish painting after the first `show()`. Keep Hybrid Composition enabled;
verify both content freshness and placement on actual devices when changing
Flutter or WebView versions.
The JS book/article controllers ignore native long-press events while dragging
a reader handle; native input delays must not reset the selected range.

## Verification

With Flutter dependencies resolved and the project's supported JDK selected,
run from `android/`:

```sh
./gradlew :flutter_inappwebview_android:testDebugUnitTest
```

JUnit/Mockito tests cover repeated menu preparation, rejected creation, normal
destruction, callback wrapping, floating-mode geometry, reader opt-in settings
and finite normalized gesture coordinates. Magnifier tests cover coordinate
conversion, frame coalescing, stale gesture requests, cancellation, disposal,
hidden/detached/unfocused views and unsupported/failing native implementations.
They cannot certify
WebView or OEM selection rendering. Native device checks must long-press a word,
drag both handles, open/dismiss reader actions, and repeat after backgrounding
the application. Recheck these flows when updating this vendored package.
