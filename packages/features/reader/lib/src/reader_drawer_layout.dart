import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

import 'reader_control_styles.dart';

/// Native bottom panels share the modal sheet gutter; sidebars retain theirs.
double readerDrawerContentInset(BuildContext context) =>
    context.isCupertino && !AppWindowSize.isWide(context)
    ? AppSpacing.xl
    : AppSpacing.lg;

/// Keeps the 20dp/24dp utility glyph on the drawer gutter while its
/// full 48dp target stays tappable.
double readerDrawerActionEndPadding(
  BuildContext context, {
  bool inPanel = true,
}) =>
    (inPanel ? readerDrawerContentInset(context) : AppSpacing.lg) -
    (AppSizes.buttonHeight - readerControlIconSize(context)) / 2;

/// Visual 16dp below panel lists, plus any insets the shell has not consumed.
/// Cupertino and expanded panels already consume their bottom safe area;
/// every inline sheet removes its keyboard inset before building the list.
double readerDrawerListBottomPadding(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom +
    MediaQuery.paddingOf(context).bottom +
    AppSpacing.lg;
