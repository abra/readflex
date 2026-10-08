import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// Trailing inset for a 48dp icon action in a drawer row, so its 20dp glyph
/// sits on the 16dp content gutter while the full target stays tappable.
const readerDrawerActionEndPadding = AppSpacing.lg - AppSizes.iconActionOutset;

/// Bottom padding for Contents and search lists: the keyboard (zero inside
/// an `AppInlineSheet`, which sits on the keyboard), the system inset and the
/// 16dp content gutter, applied once by the list.
double readerDrawerListBottomPadding(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom +
    MediaQuery.paddingOf(context).bottom +
    AppSpacing.lg;
