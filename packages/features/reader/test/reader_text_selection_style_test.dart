import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_text_selection_style.dart';

const _readerText = ValueKey('readerSelectionText');
const _outsideText = ValueKey('outsideSelectionText');
final _readerParagraph = find.descendant(
  of: find.byKey(_readerText),
  matching: find.byType(RichText),
);

void main() {
  Future<void> pumpSurface(
    WidgetTester tester,
    ThemeData theme, {
    CupertinoThemeData? cupertinoTheme,
    ValueChanged<SelectedContent?>? onSelectionChanged,
  }) async {
    final surface = _SelectionSurface(onSelectionChanged: onSelectionChanged);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: cupertinoTheme == null
              ? surface
              : CupertinoTheme(data: cupertinoTheme, child: surface),
        ),
      ),
    );
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'reader fill matches platform handles: $platform $brightness',
        (
          tester,
        ) async {
          final theme =
              (brightness == Brightness.light
                      ? AppTheme.light()
                      : AppTheme.dark())
                  .copyWith(platform: platform);
          await pumpSurface(tester, theme);
          final reader = tester.element(find.byKey(_readerText));
          final outside = tester.element(find.byKey(_outsideText));
          final cupertino = platform != TargetPlatform.android;
          final handleColor = cupertino
              ? CupertinoTheme.of(reader).selectionHandleColor
              : theme.colorScheme.primary;
          final expectedFill = handleColor.withValues(
            alpha: cupertino ? 0.2 : 0.4,
          );
          expect(
            tester
                .renderObject<RenderParagraph>(_readerParagraph)
                .selectionColor,
            expectedFill,
          );
          expect(
            DefaultSelectionStyle.of(outside).selectionColor,
            theme.colorScheme.primary.withValues(alpha: 0.4),
            reason: 'the rest of the app keeps its Material selection colour',
          );
          expect(
            DefaultSelectionStyle.of(reader).cursorColor,
            DefaultSelectionStyle.of(outside).cursorColor,
          );
          expect(
            DefaultSelectionStyle.of(reader).mouseCursor,
            SystemMouseCursors.precise,
          );
          expect(
            CupertinoTheme.of(reader).selectionHandleColor,
            CupertinoTheme.of(outside).selectionHandleColor,
          );
          expect(TextSelectionTheme.of(reader), TextSelectionTheme.of(outside));
        },
      );
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'honours custom selection handles without changing siblings: $platform',
      (
        tester,
      ) async {
        const handleColor = Color(0xFF126B45);
        const cursorColor = Color(0xFF452912);
        const previousFill = Color(0x66552277);
        final theme = AppTheme.light().copyWith(
          platform: platform,
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: handleColor,
            selectionColor: previousFill,
            cursorColor: cursorColor,
          ),
        );
        await pumpSurface(tester, theme);
        final reader = DefaultSelectionStyle.of(
          tester.element(find.byKey(_readerText)),
        );
        final outside = DefaultSelectionStyle.of(
          tester.element(find.byKey(_outsideText)),
        );
        expect(
          reader.selectionColor,
          handleColor.withValues(
            alpha: platform == TargetPlatform.iOS ? 0.2 : 0.4,
          ),
        );
        expect(reader.cursorColor, cursorColor);
        expect(reader.mouseCursor, SystemMouseCursors.precise);
        expect(outside.selectionColor, previousFill);
      },
    );
  }

  testWidgets('iOS honours the actual Cupertino handle override', (
    tester,
  ) async {
    const materialHandle = Color(0xFFAC3520);
    const cupertinoHandle = Color(0xFF127755);
    final theme = AppTheme.light().copyWith(
      platform: TargetPlatform.iOS,
      textSelectionTheme: const TextSelectionThemeData(
        selectionHandleColor: materialHandle,
      ),
    );
    await pumpSurface(
      tester,
      theme,
      cupertinoTheme: const CupertinoThemeData(
        selectionHandleColor: cupertinoHandle,
      ),
    );
    final reader = tester.element(find.byKey(_readerText));
    expect(TextSelectionTheme.of(reader).selectionHandleColor, materialHandle);
    expect(CupertinoTheme.of(reader).selectionHandleColor, cupertinoHandle);
    expect(
      DefaultSelectionStyle.of(reader).selectionColor,
      cupertinoHandle.withValues(alpha: 0.2),
    );
  });

  testWidgets(
    'long press uses the matching fill and standard iOS selection controls',
    (tester) async {
      String? selectedText;
      await pumpSurface(
        tester,
        AppTheme.light().copyWith(platform: TargetPlatform.iOS),
        onSelectionChanged: (selection) => selectedText = selection?.plainText,
      );
      await tester.longPress(find.byKey(_readerText));
      await tester.pumpAndSettle();
      expect(selectedText, isNotEmpty);
      final context = tester.element(find.byKey(_readerText));
      expect(
        tester.renderObject<RenderParagraph>(_readerParagraph).selectionColor,
        CupertinoTheme.of(context).selectionHandleColor.withValues(alpha: 0.2),
      );
      expect(
        tester
            .widget<SelectableRegion>(find.byType(SelectableRegion))
            .selectionControls,
        same(cupertinoTextSelectionHandleControls),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _SelectionSurface extends StatelessWidget {
  const _SelectionSurface({this.onSelectionChanged});

  final ValueChanged<SelectedContent?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) => DefaultSelectionStyle.merge(
    mouseCursor: SystemMouseCursors.precise,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ReaderTextSelectionStyle(
            child: SelectionArea(
              onSelectionChanged: onSelectionChanged,
              child: const Text('Select these reader words', key: _readerText),
            ),
          ),
        ),
        const Expanded(child: Text('Other app words', key: _outsideText)),
      ],
    ),
  );
}
