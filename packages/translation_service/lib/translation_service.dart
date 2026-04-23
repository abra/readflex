/// Translation + word-level pronunciation lookup.
///
/// [TranslationService] is the single public contract for both cross-language
/// translation and monolingual pronunciation lookup. The bundled production
/// implementation pulls pronunciations from Wiktionary SQLite shipped with
/// the app; translation is still a stub pending ML Kit / AI backend work.
library;

export 'src/bundled_translation_service.dart' show BundledTranslationService;
export 'src/pronunciation/pronunciation.dart';
export 'src/translation_service.dart';
