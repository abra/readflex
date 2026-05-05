import 'dart:async';

import 'package:translation_service/translation_service.dart';

class FakeTranslationService implements TranslationService {
  bool shouldThrow = false;
  TranslationResult? resultOverride;

  /// When set, `translate` blocks on this completer's future before
  /// resolving. Tests that need to simulate "user dismissed the sheet
  /// while the network call was in flight" complete it after closing
  /// the cubit.
  Completer<void>? awaitGate;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String fromLang,
    required String toLang,
  }) async {
    if (awaitGate != null) await awaitGate!.future;
    if (shouldThrow) throw const TranslationException('Translation failed');

    return resultOverride ??
        TranslationResult(
          originalText: text,
          translatedText: '[$toLang] $text',
          source: TranslationSource.platform,
        );
  }

  @override
  Future<List<Pronunciation>> lookupPronunciation({
    required String word,
    required String lang,
  }) async => const [];

  @override
  Future<void> dispose() async {}
}
