import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookLayoutPreset', () {
    test('fromId maps known ids and falls back to standard', () {
      expect(BookLayoutPreset.fromId('compact'), BookLayoutPreset.compact);
      expect(BookLayoutPreset.fromId('standard'), BookLayoutPreset.standard);
      expect(
        BookLayoutPreset.fromId('comfortable'),
        BookLayoutPreset.comfortable,
      );
      expect(BookLayoutPreset.fromId(null), BookLayoutPreset.standard);
      expect(BookLayoutPreset.fromId('unknown'), BookLayoutPreset.standard);
    });

    test('id matches enum name', () {
      expect(BookLayoutPreset.compact.id, 'compact');
      expect(BookLayoutPreset.standard.id, 'standard');
      expect(BookLayoutPreset.comfortable.id, 'comfortable');
    });

    test('each preset exposes distinct data', () {
      final compact = BookLayoutPreset.compact.data;
      final standard = BookLayoutPreset.standard.data;
      final comfortable = BookLayoutPreset.comfortable.data;

      expect(compact, isNot(equals(standard)));
      expect(standard, isNot(equals(comfortable)));
      expect(compact.fontSize < standard.fontSize, isTrue);
      expect(standard.fontSize < comfortable.fontSize, isTrue);
      expect(compact.lineHeight < comfortable.lineHeight, isTrue);
      expect(compact.topMargin < comfortable.topMargin, isTrue);
    });

    test('standard preset is justified without hyphenation', () {
      final data = BookLayoutPreset.standard.data;
      expect(data.justify, isTrue);
      expect(data.hyphenate, isFalse);
    });

    test('comfortable preset enables hyphenation and disables justify', () {
      final data = BookLayoutPreset.comfortable.data;
      expect(data.justify, isFalse);
      expect(data.hyphenate, isTrue);
    });
  });

  group('BookLayoutData equality', () {
    test('identical fields are equal', () {
      const a = BookLayoutData(
        fontSize: 1.4,
        lineHeight: 1.8,
        paragraphSpacing: 1.0,
        textIndent: 1.5,
        topMargin: 90,
        bottomMargin: 50,
        sideMargin: 6,
        letterSpacing: 0,
        fontWeight: 400,
        justify: true,
        hyphenate: false,
      );
      const b = BookLayoutData(
        fontSize: 1.4,
        lineHeight: 1.8,
        paragraphSpacing: 1.0,
        textIndent: 1.5,
        topMargin: 90,
        bottomMargin: 50,
        sideMargin: 6,
        letterSpacing: 0,
        fontWeight: 400,
        justify: true,
        hyphenate: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing fontSize makes instances unequal', () {
      const a = BookLayoutData(
        fontSize: 1.4,
        lineHeight: 1.8,
        paragraphSpacing: 1.0,
        textIndent: 1.5,
        topMargin: 90,
        bottomMargin: 50,
        sideMargin: 6,
        letterSpacing: 0,
        fontWeight: 400,
        justify: true,
        hyphenate: false,
      );
      const b = BookLayoutData(
        fontSize: 1.6,
        lineHeight: 1.8,
        paragraphSpacing: 1.0,
        textIndent: 1.5,
        topMargin: 90,
        bottomMargin: 50,
        sideMargin: 6,
        letterSpacing: 0,
        fontWeight: 400,
        justify: true,
        hyphenate: false,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
