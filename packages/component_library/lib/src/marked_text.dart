import 'package:flutter/material.dart';

/// Renders text with lightweight [[marked]] ranges highlighted.
class MarkedText extends StatelessWidget {
  const MarkedText({
    required this.text,
    this.style,
    this.highlightStyle,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    super.key,
  });

  static const startMarker = '[[';
  static const endMarker = ']]';

  final String text;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;

  static String stripMarkers(String value) {
    final buffer = StringBuffer();
    var index = 0;

    while (index < value.length) {
      final start = value.indexOf(startMarker, index);
      if (start < 0) {
        buffer.write(value.substring(index));
        break;
      }

      final end = value.indexOf(endMarker, start + startMarker.length);
      if (end < 0) {
        buffer.write(value.substring(index));
        break;
      }

      buffer
        ..write(value.substring(index, start))
        ..write(value.substring(start + startMarker.length, end));
      index = end + endMarker.length;
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!text.contains(startMarker)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final markedStyle =
        highlightStyle ??
        baseStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: _spans(text, markedStyle),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  static List<TextSpan> _spans(String value, TextStyle markedStyle) {
    final spans = <TextSpan>[];
    var index = 0;

    while (index < value.length) {
      final start = value.indexOf(startMarker, index);
      if (start < 0) {
        spans.add(TextSpan(text: value.substring(index)));
        break;
      }

      final end = value.indexOf(endMarker, start + startMarker.length);
      if (end < 0) {
        spans.add(TextSpan(text: value.substring(index)));
        break;
      }

      if (start > index) {
        spans.add(TextSpan(text: value.substring(index, start)));
      }

      final marked = value.substring(start + startMarker.length, end);
      if (marked.isNotEmpty) {
        spans.add(TextSpan(text: marked, style: markedStyle));
      }
      index = end + endMarker.length;
    }

    return spans;
  }
}
