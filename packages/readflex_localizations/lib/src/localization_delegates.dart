import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import '../generated/l10n/readflex_localizations.dart';

/// App copy and standalone UI delegates. The SDK generator still emits legacy
/// design delegates, so compose these outside generated code.
const readflexLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  ReadflexLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
