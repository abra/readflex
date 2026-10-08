import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

import 'reader_highlight_color.dart';
import 'reader_highlight_quote_background.dart';

/// Saved text with its highlight colour painted under every line, as on the
/// page. The span background wraps line by line, so no rule or box is drawn
/// beside the text.
class ReaderHighlightQuoteText extends StatelessWidget {
  const ReaderHighlightQuoteText(
    this.text, {
    required this.color,
    required this.readerTheme,
    required this.style,
    this.textDirection,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  final String text;
  final HighlightColor color;
  final ReaderThemeData readerTheme;
  final TextStyle style;
  final TextDirection? textDirection;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = readerHighlightQuoteBackground(
      highlight: readerHighlightColor(color, readerTheme),
      surface: colors.surface,
      text: style.color ?? colors.onSurface,
      opacity: readerHighlightOpacity(readerTheme),
    );
    return Text.rich(
      TextSpan(
        text: text,
        style: style.copyWith(backgroundColor: background),
      ),
      textDirection: textDirection,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
