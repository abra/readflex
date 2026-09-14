package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.view.View;
import org.junit.Before;
import org.junit.Test;
import org.mockito.ArgumentCaptor;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ReaderSelectionMagnifierTest {
  private final View view = mock(View.class);
  private final ReaderSelectionMagnifier.Lens lens = mock(ReaderSelectionMagnifier.Lens.class);
  private final ReaderSelectionMagnifier controller = new ReaderSelectionMagnifier(view, () -> lens);

  @Before
  public void setUp() {
    when(view.getWidth()).thenReturn(1080);
    when(view.getHeight()).thenReturn(1920);
    when(view.isAttachedToWindow()).thenReturn(true);
    when(view.isShown()).thenReturn(true);
    when(view.hasWindowFocus()).thenReturn(true);
  }

  private Runnable frame() {
    ArgumentCaptor<Runnable> runnable = ArgumentCaptor.forClass(Runnable.class);
    verify(view, atLeastOnce()).postOnAnimation(runnable.capture());
    return runnable.getValue();
  }

  @Test
  public void coalescesPointsAndConvertsViewportFractionsToViewPixels() {
    controller.beginTouch();
    long gesture = controller.gesture();
    controller.request(gesture, .1, .2, true);
    controller.request(gesture, .5, .75, true);
    verify(view, times(1)).postOnAnimation(any());
    verifyNoInteractions(lens);
    frame().run();
    verify(lens).show(540, 1440);
    controller.request(gesture, .25, .5, true);
    frame().run();
    verify(lens).show(270, 960);
  }

  @Test
  public void releaseCancelsFrameAndRejectsLateMessagesIncludingAfterAnotherTouch() {
    controller.beginTouch();
    long old = controller.gesture();
    controller.request(old, .5, .5, true);
    Runnable pending = frame();
    controller.endTouch();
    verify(view).removeCallbacks(pending);
    pending.run();
    controller.request(old, .5, .5, true);
    controller.beginTouch();
    controller.request(old, .5, .5, true);
    verifyNoInteractions(lens);
  }

  @Test
  public void hideDismissesWithoutEndingThePhysicalTouch() {
    controller.beginTouch();
    long gesture = controller.gesture();
    controller.request(gesture, .5, .5, true);
    frame().run();
    controller.request(gesture, 0, 0, false);
    verify(lens).dismiss();
    controller.request(gesture, .25, .25, true);
    frame().run();
    verify(lens).show(270, 480);
  }

  @Test
  public void rejectsInvalidCoordinatesInactiveTouchesAndDisposedControllers() {
    controller.request(controller.gesture(), .5, .5, true);
    controller.beginTouch();
    for (double coordinate : new double[] {Double.NaN, Double.POSITIVE_INFINITY, -.1, 1.1}) {
      controller.request(controller.gesture(), coordinate, .5, true);
      controller.request(controller.gesture(), .5, coordinate, true);
    }
    controller.dispose();
    controller.beginTouch();
    controller.request(controller.gesture(), .5, .5, true);
    verify(view, never()).postOnAnimation(any());
    verifyNoInteractions(lens);
  }

  @Test
  public void hiddenDetachedUnfocusedAndZeroSizeViewsNeverShowLens() {
    controller.beginTouch();
    when(view.isAttachedToWindow()).thenReturn(false);
    controller.request(controller.gesture(), .5, .5, true);
    frame().run();
    when(view.isAttachedToWindow()).thenReturn(true);
    when(view.hasWindowFocus()).thenReturn(false);
    controller.request(controller.gesture(), .5, .5, true);
    frame().run();
    when(view.hasWindowFocus()).thenReturn(true);
    when(view.isShown()).thenReturn(false);
    controller.request(controller.gesture(), .5, .5, true);
    frame().run();
    when(view.isShown()).thenReturn(true);
    when(view.getWidth()).thenReturn(0);
    controller.request(controller.gesture(), .5, .5, true);
    frame().run();
    verifyNoInteractions(lens);
  }

  @Test
  public void unsupportedPlatformAndNativeFailureDoNotBreakSelection() {
    ReaderSelectionMagnifier unsupported = new ReaderSelectionMagnifier(view, () -> null);
    unsupported.beginTouch();
    unsupported.request(unsupported.gesture(), .5, .5, true);
    frame().run();
    unsupported.endTouch();
    controller.beginTouch();
    doThrow(new IllegalArgumentException("Surface unavailable")).when(lens).show(anyFloat(), anyFloat());
    controller.request(controller.gesture(), .5, .5, true);
    frame().run();
    controller.request(controller.gesture(), .5, .5, true);
    verify(lens, times(1)).show(anyFloat(), anyFloat());
    verify(lens).dismiss();
  }
}
