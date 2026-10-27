import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home, {TextDirection direction = TextDirection.ltr}) =>
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(textDirection: direction, child: home),
      );

  testWidgets('draws the app chevron named Back on a 48dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        app(const Scaffold(appBar: _TitledAppBar(), body: SizedBox())),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, AppIcons.back);
      expect(icon.size, AppIconSize.lg);
      expect(find.byTooltip('Back'), findsOneWidget);
      final button = find.byType(IconButton);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('pops the enclosing route by default', (tester) async {
    await tester.pumpWidget(app(const _Launcher()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBackButton), findsOneWidget);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AppBackButton), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a given onPressed replaces the pop', (tester) async {
    var calls = 0;
    await tester.pumpWidget(app(_Launcher(onBack: () => calls++)));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('the chevron mirrors in RTL', (tester) async {
    expect(AppIcons.back.matchTextDirection, isTrue);
    await tester.pumpWidget(
      app(
        const Scaffold(appBar: _TitledAppBar(), body: SizedBox()),
        direction: TextDirection.rtl,
      ),
    );

    expect(
      find.descendant(of: find.byType(Icon), matching: find.byType(Transform)),
      findsOneWidget,
    );
  });

  testWidgets('takes the given colour', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          appBar: AppBar(leading: const AppBackButton(color: Colors.red)),
        ),
      ),
    );

    final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
    expect(style.foregroundColor!.resolve({}), Colors.red);
  });
}

class _TitledAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TitledAppBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leading: AppBackButton(onPressed: onBack),
    title: const Text('Title'),
  );
}

/// A home page that pushes a titled page, so Back has somewhere to go.
class _Launcher extends StatelessWidget {
  const _Launcher({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _Pushed(onBack: onBack)),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

class _Pushed extends StatelessWidget {
  const _Pushed({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _TitledAppBar(onBack: onBack),
    body: const SizedBox(),
  );
}
