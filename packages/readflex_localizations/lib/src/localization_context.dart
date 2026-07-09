import 'package:flutter/widgets.dart';

import '../generated/l10n/readflex_localizations.dart';

extension ReadflexLocalizationsContext on BuildContext {
  /// Localized UI strings with an English fallback for isolated widget tests.
  ReadflexLocalizations get l10n =>
      ReadflexLocalizations.of(this) ??
      lookupReadflexLocalizations(const Locale('en'));
}
