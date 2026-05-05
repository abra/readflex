/// Form payload submitted by `DictionaryAddWordSheet`. Optional fields
/// are normalised to `null` when blank so the bloc/repository layer
/// doesn't have to repeat empty-string checks.
class DictionaryAddWordFormData {
  const DictionaryAddWordFormData({
    required this.word,
    required this.translation,
    this.pronunciation,
    this.partOfSpeech,
  });

  final String word;
  final String translation;
  final String? pronunciation;
  final String? partOfSpeech;
}
