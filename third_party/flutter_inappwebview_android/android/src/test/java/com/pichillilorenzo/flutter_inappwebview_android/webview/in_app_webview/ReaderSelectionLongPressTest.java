package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import org.junit.Test;
import java.util.Collections;
import static org.junit.Assert.*;

public class ReaderSelectionLongPressTest {
  @Test
  public void normalizesCoordinatesWithoutDensityOrLocaleAssumptions() {
    assertEquals("window.dispatchEvent(new CustomEvent('readflex-long-press',{detail:{x:0.5,y:0.25}}));",
        ReaderSelectionLongPress.script(540, 600, 1080, 2400));
    assertNull(ReaderSelectionLongPress.script(10, 10, 0, 100));
    assertNull(ReaderSelectionLongPress.script(-1, 10, 100, 100));
    assertNull(ReaderSelectionLongPress.script(10, 101, 100, 100));
    assertNull(ReaderSelectionLongPress.script(Float.NaN, 10, 100, 100));
    assertNull(ReaderSelectionLongPress.script(10, Float.POSITIVE_INFINITY, 100, 100));
  }

  @Test
  public void customHandlesAreExplicitOptInAndRoundTrip() {
    InAppWebViewSettings settings = new InAppWebViewSettings();
    assertFalse(settings.useCustomSelectionHandles);
    settings.parse(Collections.singletonMap("disableContextMenu", true));
    assertFalse(settings.useCustomSelectionHandles);
    settings.parse(Collections.singletonMap("useCustomSelectionHandles", true));
    assertEquals(Boolean.TRUE, settings.toMap().get("useCustomSelectionHandles"));
    settings.parse(Collections.singletonMap("useCustomSelectionHandles", false));
    assertFalse(settings.useCustomSelectionHandles);
  }
}
