package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

/** Passes the platform-recognized gesture to reader-owned selection controls. */
final class ReaderSelectionLongPress {
  private ReaderSelectionLongPress() {}

  static String script(float x, float y, int width, int height) {
    if (width <= 0 || height <= 0 || Float.isNaN(x) || Float.isInfinite(x) || Float.isNaN(y) || Float.isInfinite(y)
        || x < 0 || y < 0 || x > width || y > height) return null;
    return "window.dispatchEvent(new CustomEvent('readflex-long-press',{detail:{x:"
        + (x / width) + ",y:" + (y / height) + "}}));";
  }
}
