import 'dart:convert';

/// Where an external link goes, as the link sheet shows it.
class ReaderExternalLinkDestination {
  const ReaderExternalLinkDestination._({
    required this.url,
    required this.target,
    required this.address,
  });

  /// The link as the page reported it; it is opened and copied unchanged.
  final String url;

  /// The host of a web link, the address of an email link, the number of a
  /// phone link: what a misleading link text cannot hide.
  final String target;

  /// The whole link with escaped letters decoded, so a Cyrillic or Arabic
  /// path reads as words. Escaped ASCII stays escaped, as browsers show it:
  /// decoding `%2F` or `%3A` would change what the address appears to say.
  final String address;

  /// Readable characters only: decoding must not let `%E2%80%AE` (a
  /// right-to-left override) or a line break disguise the address, so text
  /// that decodes to control or format characters stays escaped.
  static final _invisible = RegExp(
    r'[\u0000-\u001F\u007F-\u009F\u00AD\u061C\u180E\u200B-\u200F'
    r'\u2028-\u202E\u2060-\u206F\uFEFF\uFFF9-\uFFFB]',
  );

  /// A run of escaped bytes above ASCII: one or more encoded characters.
  static final _escapedNonAscii = RegExp(r'(?:%[89a-fA-F][0-9a-fA-F])+');

  /// The destination of [url], or null for a link the reader does not offer
  /// to open: another scheme, a web link without a host, or not a link.
  static ReaderExternalLinkDestination? tryParse(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final target = switch (uri.scheme) {
      'http' || 'https' => uri.host,
      'mailto' || 'tel' => _decoded(uri.path) ?? uri.path,
      _ => '',
    };
    if (target.isEmpty) return null;
    return ReaderExternalLinkDestination._(
      url: trimmed,
      target: target,
      address: trimmed.replaceAllMapped(
        _escapedNonAscii,
        (match) => _decodedBytes(match[0]!) ?? match[0]!,
      ),
    );
  }

  /// [value] fully decoded, or null when it does not decode or decodes to
  /// something invisible.
  static String? _decoded(String value) {
    final String decoded;
    try {
      decoded = Uri.decodeComponent(value);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
    return _invisible.hasMatch(decoded) ? null : decoded;
  }

  static String? _decodedBytes(String escaped) {
    final String decoded;
    try {
      decoded = utf8.decode([
        for (var i = 0; i < escaped.length; i += 3)
          int.parse(escaped.substring(i + 1, i + 3), radix: 16),
      ]);
    } on FormatException {
      return null;
    }
    return _invisible.hasMatch(decoded) ? null : decoded;
  }
}
