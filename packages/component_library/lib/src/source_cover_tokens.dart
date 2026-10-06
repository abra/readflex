import 'package:flutter/painting.dart';

import 'theme/tokens/app_radius.dart';

/// Shared visual treatment for book/comic source covers.
const double appSourceCoverRadius = AppRadius.xs;

/// Canonical cover slot ratio used by Library and Hero flights.
const double appSourceCoverAspectRatio = 2 / 3;

/// Bottom scrim behind a cover's progress overlay; a fixed dark ink so the
/// white bar reads over any artwork in both themes.
const Color appSourceCoverScrimColor = Color(0x4D1B1F30);
