import 'package:equatable/equatable.dart';

/// A single pronunciation variant for a word.
///
/// One word can have several variants (US vs UK English, Standard Mandarin
/// Pinyin plus its Sinological-IPA, a Japanese entry with both IPA and
/// katakana reading, etc.). Each variant is one row in the backing SQLite
/// dictionary — callers receive an ordered list and decide which one to
/// surface.
///
/// `system` is the notation, not the language:
///   * `ipa`      — International Phonetic Alphabet
///   * `pinyin`   — Hanyu Pinyin (Standard Mandarin, Latin script)
///   * `katakana` — Japanese katakana reading (e.g. `ジーディーピー` for `GDP`)
///
/// `tags` carries Wiktionary-level metadata about the variant ("Received
/// Pronunciation", "US", "Standard-Chinese", …) when available, `null`
/// otherwise. UI may use tags for labels but treats them as opaque.
final class Pronunciation extends Equatable {
  const Pronunciation({
    required this.system,
    required this.value,
    this.tags,
  });

  final String system;
  final String value;
  final List<String>? tags;

  @override
  List<Object?> get props => [system, value, tags];
}
