import 'dart:io';

typedef RemoteHostAddressResolver =
    Future<List<InternetAddress>> Function(String host);

enum RemoteUriRejectionReason {
  invalidUri,
  credentialsNotAllowed,
  addressUnavailable,
  privateOrReservedAddress,
}

class RemoteUriPolicyException implements Exception {
  const RemoteUriPolicyException(this.reason);

  final RemoteUriRejectionReason reason;

  @override
  String toString() => 'RemoteUriPolicyException($reason)';
}

/// Allows HTTP(S) resources only when every resolved address is publicly
/// routable. Call this for the initial URL and again for every redirect.
class RemoteUriPolicy {
  RemoteUriPolicy({RemoteHostAddressResolver? resolveHost})
    : _resolveHost = resolveHost ?? InternetAddress.lookup;

  final RemoteHostAddressResolver _resolveHost;

  Future<void> validate(Uri uri) async {
    await resolvePublicAddresses(uri);
  }

  /// Resolves [uri] once and returns only addresses safe for a direct
  /// connection. Consumers that open sockets should connect to one of these
  /// addresses rather than resolving [uri.host] again.
  Future<List<InternetAddress>> resolvePublicAddresses(Uri uri) async {
    if (!(uri.scheme == 'http' || uri.scheme == 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      throw const RemoteUriPolicyException(RemoteUriRejectionReason.invalidUri);
    }
    if (uri.userInfo.isNotEmpty) {
      throw const RemoteUriPolicyException(
        RemoteUriRejectionReason.credentialsNotAllowed,
      );
    }

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host == 'localhost' || host.endsWith('.localhost')) {
      throw const RemoteUriPolicyException(
        RemoteUriRejectionReason.privateOrReservedAddress,
      );
    }

    final literalAddress = InternetAddress.tryParse(host);
    final addresses = literalAddress == null
        ? await _resolveHost(host)
        : [literalAddress];
    if (addresses.isEmpty) {
      throw const RemoteUriPolicyException(
        RemoteUriRejectionReason.addressUnavailable,
      );
    }
    if (addresses.any((address) => !_isPublic(address))) {
      throw const RemoteUriPolicyException(
        RemoteUriRejectionReason.privateOrReservedAddress,
      );
    }
    return List.unmodifiable(addresses);
  }
}

bool _isPublic(InternetAddress address) {
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return _isPublicIpv4(bytes);
  }
  if (address.type != InternetAddressType.IPv6 || bytes.length != 16) {
    return false;
  }

  final isIpv4Mapped =
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;
  if (isIpv4Mapped) return _isPublicIpv4(bytes.sublist(12));

  final isDocumentationAddress =
      bytes[0] == 0x20 &&
      bytes[1] == 0x01 &&
      bytes[2] == 0x0d &&
      bytes[3] == 0xb8;
  if (isDocumentationAddress) return false;

  final isGlobalUnicast = (bytes[0] & 0xe0) == 0x20;
  final isWellKnownNat64 =
      bytes[0] == 0x00 &&
      bytes[1] == 0x64 &&
      bytes[2] == 0xff &&
      bytes[3] == 0x9b &&
      bytes.sublist(4, 12).every((byte) => byte == 0);
  return isGlobalUnicast ||
      (isWellKnownNat64 && _isPublicIpv4(bytes.sublist(12)));
}

bool _isPublicIpv4(List<int> bytes) {
  if (bytes.length != 4) return false;
  final first = bytes[0];
  final second = bytes[1];
  final third = bytes[2];

  if (first == 0 || first == 10 || first == 127 || first >= 224) return false;
  if (first == 100 && second >= 64 && second <= 127) return false;
  if (first == 169 && second == 254) return false;
  if (first == 172 && second >= 16 && second <= 31) return false;
  if (first == 192 && second == 168) return false;
  if (first == 192 && second == 0 && third == 0) return false;
  if (first == 192 && second == 0 && third == 2) return false;
  if (first == 192 && second == 88 && third == 99) return false;
  if (first == 198 && (second == 18 || second == 19)) return false;
  if (first == 198 && second == 51 && third == 100) return false;
  if (first == 203 && second == 0 && third == 113) return false;
  return true;
}
