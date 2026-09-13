import 'dart:ui' show TextDirection;

import 'package:intl/intl.dart' show Bidi;

// Content can have a different writing direction from the app's controls.
TextDirection translationTextDirection(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
