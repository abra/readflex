import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  AppSaveToggleButton button({
    bool saved = false,
    bool busy = false,
    bool failed = false,
    VoidCallback? onPressed,
  }) => AppSaveToggleButton(
    saved: saved,
    busy: busy,
    failed: failed,
    onPressed: onPressed ?? () {},
    saveLabel: 'Save word',
    savedLabel: 'Saved to Words',
    unsaveLabel: 'Remove from Words',
    failureLabel: 'Could not save',
  );

  testWidgets('offers Save with the add glyph', (tester) async {
    await tester.pumpWidget(app(button()));

    expect(find.byTooltip('Save word'), findsOneWidget);
    expect(find.byIcon(AppIcons.bookmarkAdd), findsOneWidget);
  });

  testWidgets('a saved word offers removal with the checked glyph', (
    tester,
  ) async {
    await tester.pumpWidget(app(button(saved: true)));

    expect(find.byTooltip('Remove from Words'), findsOneWidget);
    expect(find.byIcon(AppIcons.bookmarkSaved), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(AppIcons.bookmarkSaved));
    expect(icon.color, isNull);
    final style = tester
        .widget<IconButton>(find.byType(IconButton))
        .style!
        .foregroundColor!
        .resolve({});
    expect(style, AppTheme.light().colorScheme.primary);
  });

  testWidgets('busy disables the button and keeps its glyph', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(button(busy: true, onPressed: () => taps++)));

    await tester.tap(find.byType(IconButton));
    expect(taps, 0);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(find.byIcon(AppIcons.bookmarkAdd), findsOneWidget);
  });

  testWidgets('a failure shows the error glyph and stays tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(button(failed: true, onPressed: () => taps++)),
    );

    expect(find.byIcon(AppIcons.error), findsOneWidget);
    expect(find.byTooltip('Could not save'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });

  testWidgets('a change of state is announced through a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(button()));
    expect(
      tester.getSemantics(find.byType(AppSaveToggleButton)),
      isNot(matchesSemantics(isLiveRegion: true)),
    );

    await tester.pumpWidget(app(button(saved: true)));
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(AppSaveToggleButton)),
      matchesSemantics(isLiveRegion: true, value: 'Saved to Words'),
    );
    handle.dispose();
  });

  testWidgets('tap calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(button(onPressed: () => taps++)));

    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });
}
