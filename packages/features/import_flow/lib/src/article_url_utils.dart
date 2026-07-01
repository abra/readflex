import 'dart:io';

final _whitespaceRegex = RegExp(r'\s');
final _explicitSchemeRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

String? normalizeArticleUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty || value.contains(_whitespaceRegex)) return null;

  final hasExplicitScheme = _explicitSchemeRegex.hasMatch(value);
  final candidate = hasExplicitScheme ? value : 'https://$value';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty) {
    return null;
  }
  if (!_looksLikeHost(uri.host)) return null;

  return uri.toString();
}

bool _looksLikeHost(String host) {
  if (host == 'localhost') return true;
  if (InternetAddress.tryParse(host) != null) return true;
  final labels = host.split('.');
  return labels.length > 1 && labels.every((label) => label.isNotEmpty);
}
