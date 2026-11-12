import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:readflex/app/readflex_platform_app.dart';

void main() {
  testWidgets('Cupertino navigation preserves Hero and interactive back', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _NavigationPage()),
        GoRoute(
          path: '/details',
          builder: (_, _) => const _NavigationPage(details: true),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ReadflexPlatformApp(routerConfig: router));
    await tester.pumpAndSettle();
    router.push<void>('/details');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Hero, skipOffstage: false), findsAtLeastNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();

    final route = ModalRoute.of(tester.element(find.text('Details body')))!;
    expect(route.settings, isA<cupertino.CupertinoPage<void>>());
    expect((route as PageRoute<void>).popGestureEnabled, isTrue);
    final back = find.byType(AppBackButton);
    final settings = find.byKey(const ValueKey('settings'));
    for (final target in [back, settings]) {
      // Cupertino navigation uses Apple's native 44dp toolbar height.
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
      expect(target.hitTestable(), findsOneWidget);
    }
    final navigation = tester.getRect(
      find.byType(cupertino.CupertinoNavigationBar),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
      navigation.bottom,
    );
    await tester.dragFrom(const Offset(1, 400), const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(find.text('Details body'), findsNothing);
    expect(find.text('Library body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system brightness changes preserve the native editor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final controller = TextEditingController(text: 'Retained draft');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ReadflexPlatformApp(
        home: AppScaffold(body: AppTextField(controller: controller)),
      ),
    );
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    expect(
      tester.element(find.byType(AppTextField)).colors.brightness,
      Brightness.light,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(AppTextField)).colors.brightness,
      Brightness.dark,
    );
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
    expect(controller.text, 'Retained draft');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _NavigationPage extends StatelessWidget {
  const _NavigationPage({this.details = false});
  final bool details;

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppNavigationBar(
      title: Text(details ? 'Details' : 'Library'),
      leading: details ? const AppBackButton() : null,
      actions: [
        AppPlainIconButton(
          key: const ValueKey('settings'),
          icon: AppIcons.settings,
          tooltip: 'Settings',
          onPressed: () {},
        ),
      ],
    ),
    body: SizedBox.expand(
      key: const ValueKey('body'),
      child: Text(details ? 'Details body' : 'Library body'),
    ),
  );
}
