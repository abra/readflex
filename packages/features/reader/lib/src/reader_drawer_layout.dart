import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'reader_control_styles.dart';

/// Keeps the 20dp/24dp utility glyph on the 16dp drawer gutter while its
/// full 48dp target stays tappable.
double readerDrawerActionEndPadding(BuildContext context) =>
    AppSpacing.lg -
    (AppSizes.buttonHeight - readerControlIconSize(context)) / 2;

/// Bottom padding for Contents and search lists: the keyboard (zero inside
/// an `AppInlineSheet`, which sits on the keyboard), the system inset and the
/// 16dp content gutter, applied once by the list.
double readerDrawerListBottomPadding(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom +
    MediaQuery.paddingOf(context).bottom +
    AppSpacing.lg;
