import 'dart:io';

import 'package:remote_content_policy/remote_content_policy.dart';
import 'package:test/test.dart';

void main() {
  test('allows a host when all resolved addresses are public', () async {
    final policy = RemoteUriPolicy(
      resolveHost: (_) async => [InternetAddress('93.184.216.34')],
    );

    await expectLater(
      policy.validate(Uri.parse('https://example.com/a')),
      completes,
    );
  });

  test('returns an immutable snapshot of validated addresses', () async {
    final address = InternetAddress('93.184.216.34');
    final policy = RemoteUriPolicy(resolveHost: (_) async => [address]);

    final addresses = await policy.resolvePublicAddresses(
      Uri.parse('https://example.com/a'),
    );

    expect(addresses, [address]);
    expect(
      () => addresses.add(InternetAddress('1.1.1.1')),
      throwsUnsupportedError,
    );
  });

  test('revalidates DNS and rejects rebinding before connecting', () async {
    var lookupCount = 0;
    final policy = RemoteUriPolicy(
      resolveHost: (_) async {
        lookupCount++;
        return [
          InternetAddress(lookupCount == 1 ? '93.184.216.34' : '127.0.0.1'),
        ];
      },
    );
    final uri = Uri.parse('https://example.com/a');
    await policy.validate(uri);
    final client = createPublicRemoteHttpClient(uriPolicy: policy);

    try {
      await expectLater(
        () => client.getUrl(uri),
        throwsA(_rejectedAs(RemoteUriRejectionReason.privateOrReservedAddress)),
      );
      expect(lookupCount, 2);
    } finally {
      client.close(force: true);
    }
  });

  test('rejects mixed public and private DNS answers', () async {
    final policy = RemoteUriPolicy(
      resolveHost: (_) async => [
        InternetAddress('93.184.216.34'),
        InternetAddress('127.0.0.1'),
      ],
    );

    await expectLater(
      policy.validate(Uri.parse('https://example.com/a')),
      throwsA(_rejectedAs(RemoteUriRejectionReason.privateOrReservedAddress)),
    );
  });

  test('rejects private, local, and reserved literal addresses', () async {
    final policy = RemoteUriPolicy();
    const hosts = [
      '0.0.0.0',
      '10.0.0.1',
      '100.64.0.1',
      '127.0.0.1',
      '169.254.1.1',
      '172.16.0.1',
      '192.168.0.1',
      '198.18.0.1',
      '224.0.0.1',
      '::1',
      'fc00::1',
      'fe80::1',
      '2001:db8::1',
    ];

    for (final host in hosts) {
      await expectLater(
        policy.validate(Uri(scheme: 'http', host: host)),
        throwsA(_rejectedAs(RemoteUriRejectionReason.privateOrReservedAddress)),
        reason: host,
      );
    }
  });

  test('rejects URL credentials', () async {
    final policy = RemoteUriPolicy(
      resolveHost: (_) async => [InternetAddress('93.184.216.34')],
    );

    await expectLater(
      policy.validate(Uri.parse('https://user:pass@example.com/a')),
      throwsA(_rejectedAs(RemoteUriRejectionReason.credentialsNotAllowed)),
    );
  });

  test('rejects hostnames without resolved addresses', () async {
    final policy = RemoteUriPolicy(resolveHost: (_) async => []);

    await expectLater(
      policy.validate(Uri.parse('https://example.com/a')),
      throwsA(_rejectedAs(RemoteUriRejectionReason.addressUnavailable)),
    );
  });
}

Matcher _rejectedAs(RemoteUriRejectionReason reason) {
  return isA<RemoteUriPolicyException>().having(
    (error) => error.reason,
    'reason',
    reason,
  );
}
