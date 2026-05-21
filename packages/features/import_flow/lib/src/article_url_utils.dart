import 'dart:io';

String? normalizeArticleUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) return null;

  final hasExplicitScheme = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9+.-]*://',
  ).hasMatch(value);
  final candidate = hasExplicitScheme ? value : 'https://$value';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty) {
    return null;
  }
  if (!hasExplicitScheme && !_looksLikeHost(uri.host)) return null;

  return uri.toString();
}

bool _looksLikeHost(String host) {
  if (host == 'localhost') return true;
  if (InternetAddress.tryParse(host) != null) return true;
  final labels = host.split('.');
  return labels.length > 1 && labels.every((label) => label.isNotEmpty);
}
