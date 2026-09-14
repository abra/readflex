package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.annotation.TargetApi;
import android.graphics.Rect;
import android.view.ActionMode;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;

/** Hides edit commands without finishing WebView's native selection mode. */
final class SelectionActionModeCallback implements ActionMode.Callback {
  private final ActionMode.Callback delegate;

  private SelectionActionModeCallback(ActionMode.Callback delegate) {
    this.delegate = delegate;
  }

  static ActionMode.Callback wrap(ActionMode.Callback callback, int sdk) {
    if (callback instanceof SelectionActionModeCallback) return callback;
    if (sdk >= 23) return Floating.wrap(callback);
    return new SelectionActionModeCallback(callback);
  }

  @Override
  public boolean onCreateActionMode(ActionMode mode, Menu menu) {
    boolean created = delegate.onCreateActionMode(mode, menu);
    menu.clear();
    return created;
  }

  @Override
  public boolean onPrepareActionMode(ActionMode mode, Menu menu) {
    boolean changed = delegate.onPrepareActionMode(mode, menu);
    menu.clear();
    return changed;
  }

  @Override
  public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
    return delegate.onActionItemClicked(mode, item);
  }

  @Override
  public void onDestroyActionMode(ActionMode mode) {
    delegate.onDestroyActionMode(mode);
  }

  @TargetApi(23)
  private static final class Floating extends ActionMode.Callback2 {
    private final SelectionActionModeCallback callback;

    private Floating(ActionMode.Callback delegate) {
      callback = new SelectionActionModeCallback(delegate);
    }

    static ActionMode.Callback wrap(ActionMode.Callback callback) {
      return callback instanceof Floating ? callback : new Floating(callback);
    }

    @Override
    public boolean onCreateActionMode(ActionMode mode, Menu menu) {
      return callback.onCreateActionMode(mode, menu);
    }

    @Override
    public boolean onPrepareActionMode(ActionMode mode, Menu menu) {
      return callback.onPrepareActionMode(mode, menu);
    }

    @Override
    public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
      return callback.onActionItemClicked(mode, item);
    }

    @Override
    public void onDestroyActionMode(ActionMode mode) {
      callback.onDestroyActionMode(mode);
    }

    @Override
    public void onGetContentRect(ActionMode mode, View view, Rect outRect) {
      if (callback.delegate instanceof ActionMode.Callback2) {
        ((ActionMode.Callback2) callback.delegate).onGetContentRect(mode, view, outRect);
      } else {
        super.onGetContentRect(mode, view, outRect);
      }
    }
  }
}
