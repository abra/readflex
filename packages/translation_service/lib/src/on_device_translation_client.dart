/// Optional adapter for platform on-device translation.
///
/// Kept behind an interface so the app can add ML Kit or another native
/// translator later without changing feature UI or the main translation
/// service contract. The current implementation deliberately ships without a
/// native on-device plugin because Google ML Kit translation breaks Apple
/// Silicon iOS 26 simulator builds.
abstract interface class OnDeviceTranslationClient {
  Future<String?> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  });

  Future<void> dispose();
}

class UnavailableOnDeviceTranslationClient
    implements OnDeviceTranslationClient {
  const UnavailableOnDeviceTranslationClient();

  @override
  Future<String?> translate(
    String text, {
    required String fromLang,
    required String toLang,
    String? contextText,
  }) async => null;

  @override
  Future<void> dispose() async {}
}
