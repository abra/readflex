import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// How a link the reader confirmed opens: a web page in the in-app browser
/// (Safari View Controller, Custom Tabs), so Done returns to the same page,
/// an email or phone link in its app. Null for any other scheme.
@visibleForTesting
LaunchMode? readerLinkLaunchMode(Uri uri) => switch (uri.scheme) {
  'http' || 'https' => LaunchMode.inAppBrowserView,
  'mailto' || 'tel' => LaunchMode.externalApplication,
  _ => null,
};

/// Opens a link the reader confirmed in its link sheet. Other schemes and
/// launcher failures leave the reader as it is.
Future<void> openReaderLink(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  final mode = uri == null ? null : readerLinkLaunchMode(uri);
  if (uri == null || mode == null) return;

  try {
    await launchUrl(uri, mode: mode);
  } catch (error) {
    debugPrint('Failed to open URL: $rawUrl ($error)');
  }
}
