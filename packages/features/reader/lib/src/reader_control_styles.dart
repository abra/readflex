import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';

/// Reader controls use the larger existing label role in tablet windows.
TextStyle readerControlCaptionStyle(BuildContext context) =>
    AppWindowSize.isMedium(context)
    ? context.text.labelLarge
    : context.text.labelSmall;

TextStyle readerChromeLabelStyle(BuildContext context) =>
    AppWindowSize.isMedium(context)
    ? context.text.labelLarge
    : context.text.readerChromeLabel;

TextStyle readerChromeNumberStyle(BuildContext context) =>
    AppWindowSize.isMedium(context)
    ? context.text.labelLarge.copyWith(
        fontFeatures: context.text.readerChromeNumber.fontFeatures,
      )
    : context.text.readerChromeNumber;

double readerControlIconSize(BuildContext context) =>
    AppPlainIconButton.defaultIconSizeOf(context);
