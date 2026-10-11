/// How the translation sheet closed, when it closed with a request for the
/// action that opened it. A plain dismissal returns `null`.
enum TranslateSheetOutcome {
  /// The text is already in the target language; open its definition
  /// instead.
  define,
}
