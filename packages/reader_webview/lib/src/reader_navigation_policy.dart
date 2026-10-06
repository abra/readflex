import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// What a reader WebView should do with a navigation request.
enum ReaderNavigationDecision {
  /// Load inside the WebView.
  allow,

  /// Drop the request silently.
  cancel,

  /// Drop the request and hand the URL to the host's external-link callback.
  cancelAndOpenExternally,
}

/// Pure navigation rules for both reader shells.
///
/// Reader documents come from the token-scoped loopback server only. Link
/// taps are intercepted in JS and reach Flutter as `onExternalLink`; this
/// policy is the safety net for anything the shells miss (publisher scripts,
/// meta refresh, window.location writes). Sub-frames are held to the same
/// origin rule, which matches the section CSP (`frame-src 'none'`), while
/// `blob:`/`data:`/`about:` stay available for loader-generated documents.
final class ReaderNavigationPolicy {
  const ReaderNavigationPolicy({required this.serverBaseUri});

  final Uri serverBaseUri;

  static const _opaqueSchemes = {'about', 'blob', 'data'};
  static const _externalSchemes = {'http', 'https'};

  ReaderNavigationDecision decide({
    required Uri? url,
    required bool isForMainFrame,
  }) {
    if (url == null) return ReaderNavigationDecision.cancel;
    final scheme = url.scheme.toLowerCase();
    if (_opaqueSchemes.contains(scheme)) {
      return ReaderNavigationDecision.allow;
    }
    if (_isLoopbackOrigin(url)) return ReaderNavigationDecision.allow;
    if (isForMainFrame && _externalSchemes.contains(scheme)) {
      return ReaderNavigationDecision.cancelAndOpenExternally;
    }
    return ReaderNavigationDecision.cancel;
  }

  bool _isLoopbackOrigin(Uri url) {
    return url.scheme.toLowerCase() == serverBaseUri.scheme.toLowerCase() &&
        url.host.toLowerCase() == serverBaseUri.host.toLowerCase() &&
        url.port == serverBaseUri.port;
  }
}

/// Builds the `shouldOverrideUrlLoading` callback shared by both readers.
///
/// `isActive` ignores late decisions from a replaced native WebView; a
/// cancelled external main-frame navigation is reported through
/// [onExternalLink] exactly like a JS-intercepted link.
typedef ReaderNavigationActionHandler =
    Future<NavigationActionPolicy?> Function(
      InAppWebViewController controller,
      NavigationAction action,
    );

ReaderNavigationActionHandler readerNavigationActionHandler({
  required ReaderNavigationPolicy policy,
  required bool Function(InAppWebViewController controller) isActive,
  required ValueChanged<String>? onExternalLink,
}) {
  return (controller, action) async {
    final url = action.request.url;
    final decision = policy.decide(
      url: url,
      isForMainFrame: action.isForMainFrame,
    );
    switch (decision) {
      case ReaderNavigationDecision.allow:
        return NavigationActionPolicy.ALLOW;
      case ReaderNavigationDecision.cancel:
        return NavigationActionPolicy.CANCEL;
      case ReaderNavigationDecision.cancelAndOpenExternally:
        if (isActive(controller) && url != null) {
          onExternalLink?.call(url.toString());
        }
        return NavigationActionPolicy.CANCEL;
    }
  };
}
