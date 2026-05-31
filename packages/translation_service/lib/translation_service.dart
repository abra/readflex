// Translation + word-level pronunciation lookup.
//
// TranslationService is the single public contract for both cross-language
// translation and monolingual pronunciation lookup. The production wiring
// layers bundled SQLite and optional direct DeepSeek behind this package.
// The on-device translation adapter is intentionally plugin-free for now so
// iOS simulator builds stay usable.

export 'src/bundled_translation_service.dart' show BundledTranslationService;
export 'src/deepseek_direct_translation_client.dart'
    show DeepSeekDirectTranslationClient;
export 'src/on_device_translation_client.dart'
    show OnDeviceTranslationClient, UnavailableOnDeviceTranslationClient;
export 'src/pronunciation/pronunciation.dart';
export 'src/remote_translation_client.dart' show RemoteTranslationClient;
export 'src/translation_service.dart';
