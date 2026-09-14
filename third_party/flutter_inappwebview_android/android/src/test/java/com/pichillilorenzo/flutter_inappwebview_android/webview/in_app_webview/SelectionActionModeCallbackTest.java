package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.graphics.Rect;
import android.view.ActionMode;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;

import org.junit.Test;
import org.mockito.InOrder;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class SelectionActionModeCallbackTest {
  @Test
  public void hidesMenuAfterCreationAndEveryPreparationWithoutFinishingSelection() {
    ActionMode mode = mock(ActionMode.class);
    Menu menu = mock(Menu.class);
    ActionMode.Callback delegate = mock(ActionMode.Callback.class);
    when(delegate.onCreateActionMode(mode, menu)).thenReturn(true);
    when(delegate.onPrepareActionMode(mode, menu)).thenReturn(true, false);
    ActionMode.Callback callback = SelectionActionModeCallback.wrap(delegate, 23);

    assertTrue(callback.onCreateActionMode(mode, menu));
    assertTrue(callback.onPrepareActionMode(mode, menu));
    assertFalse(callback.onPrepareActionMode(mode, menu));

    InOrder order = inOrder(delegate, menu);
    order.verify(delegate).onCreateActionMode(mode, menu);
    order.verify(menu).clear();
    order.verify(delegate).onPrepareActionMode(mode, menu);
    order.verify(menu).clear();
    order.verify(delegate).onPrepareActionMode(mode, menu);
    order.verify(menu).clear();
    verifyNoInteractions(mode);
    verify(delegate, never()).onDestroyActionMode(mode);
  }

  @Test
  public void preservesRejectedCreationClicksAndNormalDestruction() {
    ActionMode mode = mock(ActionMode.class);
    Menu menu = mock(Menu.class);
    MenuItem item = mock(MenuItem.class);
    ActionMode.Callback delegate = mock(ActionMode.Callback.class);
    when(delegate.onActionItemClicked(mode, item)).thenReturn(true);
    ActionMode.Callback callback = SelectionActionModeCallback.wrap(delegate, 22);
    assertFalse(callback.onCreateActionMode(mode, menu));
    assertTrue(callback.onActionItemClicked(mode, item));
    callback.onDestroyActionMode(mode);
    verify(delegate).onDestroyActionMode(mode);
    verifyNoInteractions(mode);
    assertFalse(callback instanceof ActionMode.Callback2);
  }

  @Test
  public void forwardsFloatingSelectionGeometryAndDoesNotWrapTwice() {
    ActionMode.Callback2 delegate = mock(ActionMode.Callback2.class);
    ActionMode mode = mock(ActionMode.class);
    View view = mock(View.class);
    Rect rect = new Rect();
    ActionMode.Callback2 callback = (ActionMode.Callback2)
        SelectionActionModeCallback.wrap(delegate, 34);
    callback.onGetContentRect(mode, view, rect);
    verify(delegate).onGetContentRect(mode, view, rect);
    assertSame(callback, SelectionActionModeCallback.wrap(callback, 34));
  }
}
