package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.os.Build;
import android.view.View;
import android.widget.Magnifier;

import androidx.annotation.RequiresApi;

/** UI-thread controller. Only the gesture token may be read by the JS bridge thread. */
final class ReaderSelectionMagnifier {
  interface Lens {
    void show(float x, float y);
    void dismiss();
  }

  interface Factory {
    Lens create();
  }

  private final View view;
  private final Factory factory;
  private final Runnable render = this::render;
  private volatile long gesture;
  private Lens lens;
  private boolean touching, pending, disposed, unavailable;
  private float x, y;

  ReaderSelectionMagnifier(View view) {
    this(view, () -> Build.VERSION.SDK_INT >= 28 ? new AndroidLens(view) : null);
  }

  ReaderSelectionMagnifier(View view, Factory factory) {
    this.view = view;
    this.factory = factory;
  }

  long gesture() {
    return gesture;
  }

  void beginTouch() {
    endTouch();
    touching = !disposed;
    unavailable = false;
  }

  void endTouch() {
    touching = false;
    gesture++;
    hide();
  }

  void request(long token, double x, double y, boolean visible) {
    if (disposed || token != gesture) return;
    if (!visible) {
      hide();
      return;
    }
    if (!touching || unavailable) return;
    if (!Double.isFinite(x) || !Double.isFinite(y) || x < 0 || x > 1 || y < 0 || y > 1) {
      hide();
      return;
    }
    this.x = (float) x;
    this.y = (float) y;
    if (!pending) {
      pending = true;
      view.postOnAnimation(render);
    }
  }

  private void render() {
    if (!pending) return;
    pending = false;
    if (!touching || disposed || !view.isAttachedToWindow() || !view.isShown()
        || !view.hasWindowFocus() || view.getWidth() <= 0 || view.getHeight() <= 0) {
      hide();
      return;
    }
    try {
      if (lens == null) lens = factory.create();
      if (lens == null) {
        unavailable = true;
        return;
      }
      lens.show(x * view.getWidth(), y * view.getHeight());
    } catch (RuntimeException exception) {
      // Surface teardown or a vendor implementation must not interrupt selection.
      unavailable = true;
      hide();
    }
  }

  private void hide() {
    if (pending) view.removeCallbacks(render);
    pending = false;
    if (lens != null) {
      try {
        lens.dismiss();
      } catch (RuntimeException exception) {
        lens = null;
        unavailable = true;
      }
    }
  }

  void dispose() {
    disposed = true;
    endTouch();
    lens = null;
  }

  @RequiresApi(28)
  private static final class AndroidLens implements Lens {
    private final Magnifier magnifier;
    private boolean visible;
    private float lastX, lastY;

    @SuppressWarnings("deprecation")
    AndroidLens(View view) {
      float density = view.getResources().getDisplayMetrics().density;
      // A text-height aperture keeps the DOM handle below the line out of the loupe.
      magnifier = Build.VERSION.SDK_INT >= 29
          ? new Magnifier.Builder(view)
              .setSize(Math.round(120 * density), Math.round(36 * density))
              .setInitialZoom(1.5f)
              .setCornerRadius(18 * density)
              .setDefaultSourceToMagnifierOffset(0, Math.round(-48 * density))
              .build()
          : new Magnifier(view);
    }

    @Override
    public void show(float x, float y) {
      // WebView paints asynchronously; the caret can stay on the same character
      // while the selection and its controls finish painting underneath it.
      if (visible && x == lastX && y == lastY) magnifier.update();
      else magnifier.show(x, y);
      visible = true;
      lastX = x;
      lastY = y;
    }

    @Override
    public void dismiss() {
      magnifier.dismiss();
      visible = false;
    }
  }
}
