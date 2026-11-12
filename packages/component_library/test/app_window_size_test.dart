import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isMediumSize', () {
    test('600dp Split View and portrait tablets use medium controls', () {
      for (final size in const [
        Size(600, 480),
        Size(600, 900),
        Size(800, 1280),
        Size(1280, 800),
        Size(1032, 1376),
      ]) {
        expect(AppWindowSize.isMediumSize(size), isTrue, reason: '$size');
      }
    });

    test(
      'both thresholds are inclusive; short landscape phones stay narrow',
      () {
        for (final size in const [
          Size(599, 1280),
          Size(600, 479),
          Size(390, 844),
          Size(844, 390),
        ]) {
          expect(AppWindowSize.isMediumSize(size), isFalse, reason: '$size');
        }
        expect(AppWindowSize.isMediumSize(const Size(600, 480)), isTrue);
        expect(AppWindowSize.isWideSize(const Size(600, 480)), isFalse);
        expect(AppWindowSize.isWideSize(const Size(800, 1280)), isFalse);
      },
    );
  });

  group('isWideSize', () {
    test('phones stay narrow in both orientations', () {
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(430, 932),
        Size(568, 320),
        Size(844, 390),
        Size(932, 430),
      ]) {
        expect(AppWindowSize.isWideSize(size), isFalse, reason: '$size');
      }
    });

    test('full-screen iPads are wide in both orientations', () {
      for (final size in const [
        Size(1032, 1376),
        Size(1376, 1032),
        Size(834, 1194),
        Size(1194, 834),
      ]) {
        expect(
          AppWindowSize.isWideSize(size),
          // An 11-inch iPad in portrait is 834 wide, just short of 840.
          size.width >= 840,
          reason: '$size',
        );
      }
    });

    test('narrow iPad windows stay narrow', () {
      // iPad mini and Split View halves and thirds.
      for (final size in const [
        Size(744, 1133),
        Size(678, 1032),
        Size(320, 1032),
      ]) {
        expect(AppWindowSize.isWideSize(size), isFalse, reason: '$size');
      }
    });

    test('both thresholds are inclusive', () {
      const edge = Size(
        AppWindowSize.wideMinWidth,
        AppWindowSize.wideMinHeight,
      );
      expect(AppWindowSize.isWideSize(edge), isTrue);
      expect(
        AppWindowSize.isWideSize(Size(edge.width - 1, edge.height)),
        isFalse,
      );
      expect(
        AppWindowSize.isWideSize(Size(edge.width, edge.height - 1)),
        isFalse,
      );
    });
  });

  testWidgets('isWide reads the window and follows its resizes', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final results = <bool>[];
    final widget = Builder(
      builder: (context) {
        results.add(AppWindowSize.isWide(context));
        return const SizedBox();
      },
    );

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    await tester.pumpWidget(MaterialApp(home: widget));
    tester.view.physicalSize = const Size(1376, 1032);
    await tester.pump();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();

    expect(results, [false, true, false]);
  });

  testWidgets('isWide does not rebuild for padding or keyboard insets', (
    tester,
  ) async {
    var builds = 0;
    final widget = Builder(
      builder: (context) {
        builds++;
        AppWindowSize.isWide(context);
        return const SizedBox();
      },
    );
    Widget host(EdgeInsets insets) => MediaQuery(
      data: MediaQueryData(
        size: const Size(1376, 1032),
        padding: insets,
        viewInsets: insets,
      ),
      child: widget,
    );

    await tester.pumpWidget(host(EdgeInsets.zero));
    await tester.pumpWidget(host(const EdgeInsets.only(bottom: 320)));

    expect(builds, 1);
  });

  testWidgets('isMedium follows resizes without reading keyboard or padding', (
    tester,
  ) async {
    var builds = 0;
    final values = <bool>[];
    final child = Builder(
      builder: (context) {
        builds++;
        values.add(AppWindowSize.isMedium(context));
        return const SizedBox();
      },
    );
    Widget host(Size size, {EdgeInsets insets = EdgeInsets.zero}) => MediaQuery(
      data: MediaQueryData(size: size, padding: insets, viewInsets: insets),
      child: child,
    );
    await tester.pumpWidget(host(const Size(600, 480)));
    await tester.pumpWidget(
      host(const Size(600, 480), insets: const EdgeInsets.only(bottom: 320)),
    );
    expect(builds, 1);
    await tester.pumpWidget(host(const Size(800, 1280)));
    await tester.pumpWidget(host(const Size(844, 390)));
    await tester.pumpWidget(host(const Size(599, 900)));
    expect(values, [true, true, false, false]);
  });
}
