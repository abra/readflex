import 'package:component_library/component_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_font_ink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the reader\'s fonts give their ink from the bundle', () async {
    final ink = await readerFontInk();
    // Literata's tallest ascender and deepest descender (fontTools).
    final literata = ink[AppTypography.fontFamilySerif]!;
    expect(literata.ascent, closeTo(0.786, 1e-9));
    expect(literata.descent, closeTo(0.23, 1e-9));
    expect(
      ink.keys,
      containsAll(ReaderFontPreset.values.map((p) => p.fontFamily)),
    );
    expect(identical(await readerFontInk(), ink), isTrue, reason: 'once');
  });

  // Widget tests run each body in its own fake-async zone: a later test
  // must not wait on a read that an earlier, finished test started.
  testWidgets('a test reads the fonts', (tester) async {
    await tester.runAsync(readerFontInk);
  });

  testWidgets('a later test gets them at once', (tester) async {
    Map<String, Object>? ink;
    readerFontInk().then((value) => ink = value);
    expect(ink, isNotEmpty);
  });
}
