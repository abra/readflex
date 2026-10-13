package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.webkit.ConsoleMessage;

import com.pichillilorenzo.flutter_inappwebview_android.webview.WebViewChannelDelegate;

import org.junit.Test;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ConsoleMessageForwardingTest {
  @Test
  public void forwardsConsoleMessagesToFlutterAndKeepsThemOutOfLogcat() {
    WebViewChannelDelegate channel = mock(WebViewChannelDelegate.class);
    ConsoleMessage message = mock(ConsoleMessage.class);
    when(message.message()).thenReturn("Warning: TT: undefined function");
    when(message.messageLevel()).thenReturn(ConsoleMessage.MessageLevel.LOG);

    // Handled: WebView writes unhandled console messages to logcat in every build.
    assertTrue(InAppWebViewChromeClient.forwardConsoleMessage(channel, message));
    verify(channel).onConsoleMessage(
        "Warning: TT: undefined function", ConsoleMessage.MessageLevel.LOG.ordinal());
  }

  @Test
  public void handlesConsoleMessagesOfADisposedWebView() {
    ConsoleMessage message = mock(ConsoleMessage.class);

    assertTrue(InAppWebViewChromeClient.forwardConsoleMessage(null, message));
    verifyNoInteractions(message);
  }
}
