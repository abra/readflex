import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('top chrome title keeps base font size when it fits', () {
    const baseStyle = TextStyle(fontSize: 16);

    final style = readerTopChromeTitleStyleForText(
      title: 'Short title',
      baseStyle: baseStyle,
      textDirection: TextDirection.ltr,
      maxWidth: 320,
    );

    expect(style.fontSize, 16);
  });

  test('top chrome title reduces font size for long titles', () {
    const baseStyle = TextStyle(fontSize: 16);

    final style = readerTopChromeTitleStyleForText(
      title:
          'The Trash Droid Files: Phoenix Rising: Book 1 '
          'A Sci Fi Adventure Thriller for Adults Who Love Robot Fiction',
      baseStyle: baseStyle,
      textDirection: TextDirection.ltr,
      maxWidth: 320,
    );

    expect(style.fontSize, lessThan(16));
    expect(style.fontSize, greaterThanOrEqualTo(8));
  });

  test('top chrome title does not shrink below the minimum', () {
    const baseStyle = TextStyle(fontSize: 16);

    final style = readerTopChromeTitleStyleForText(
      title: List.filled(100, 'word').join(' '),
      baseStyle: baseStyle,
      textDirection: TextDirection.ltr,
      maxWidth: 220,
    );

    expect(style.fontSize, 8);
  });
}
