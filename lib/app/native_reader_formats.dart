import 'package:domain_models/domain_models.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/config/application_config.dart';

/// The formats the native `vellum` engine draws and imports: the
/// developer override saved in [preferences] when there is one, otherwise
/// the build's `READFLEX_NATIVE_FORMATS`. Read when a book is opened or
/// imported, so a change applies to the next one.
Set<BookFormat> effectiveNativeReaderFormats({
  required ApplicationConfig config,
  required Preferences preferences,
}) {
  final override = preferences.nativeReaderFormats;
  if (override == null) return config.nativeReaderFormats;
  return nativeReaderFormatsFromNames(override);
}

/// The formats [names] (extensions, any case) stand for, with the
/// build setting's rules: unknown names are ignored.
Set<BookFormat> nativeReaderFormatsFromNames(Iterable<String> names) =>
    ApplicationConfig.parseNativeReaderFormats(names.join(','));
