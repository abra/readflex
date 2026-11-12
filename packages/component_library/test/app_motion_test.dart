import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required bool disableAnimations,
    bool reduceMotion = false,
    required Widget child,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          reduceMotion: reduceMotion,
        ),
        child: app!,
      ),
      home: Scaffold(body: child),
    );
  }

  test('motion tokens are ordered from quick to medium', () {
    expect(AppMotion.quick, lessThan(AppMotion.short));
    expect(AppMotion.short, lessThan(AppMotion.medium));
  });

  testWidgets('context.motion returns the token when motion is allowed', (
    tester,
  ) async {
    late Duration resolved;
    late bool reduce;
    await tester.pumpWidget(
      host(
        disableAnimations: false,
        child: Builder(
          builder: (context) {
            resolved = context.motion(AppMotion.short);
            reduce = context.reduceMotion;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, AppMotion.short);
    expect(reduce, isFalse);
  });

  for (final setting in [
    (name: 'Android Remove animations', disable: true, reduce: false),
    (name: 'iOS Reduce Motion', disable: false, reduce: true),
    (name: 'both motion preferences', disable: true, reduce: true),
  ]) {
    testWidgets('context.motion collapses to zero for ${setting.name}', (
      tester,
    ) async {
      late Duration resolved;
      late bool reduce;
      await tester.pumpWidget(
        host(
          disableAnimations: setting.disable,
          reduceMotion: setting.reduce,
          child: Builder(
            builder: (context) {
              resolved = context.motion(AppMotion.medium);
              reduce = context.reduceMotion;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, Duration.zero);
      expect(reduce, isTrue);
    });

    testWidgets('an implicit animation settles in one frame for '
        '${setting.name}', (tester) async {
      var expanded = false;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          disableAnimations: setting.disable,
          reduceMotion: setting.reduce,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AnimatedContainer(
                duration: context.motion(AppMotion.medium),
                width: expanded ? 200 : 100,
                height: 10,
                color: Colors.red,
              );
            },
          ),
        ),
      );
      update(() => expanded = true);
      await tester.pump();
      expect(tester.getSize(find.byType(AnimatedContainer)).width, 200);
    });
  }

  testWidgets('motion responds when either inherited preference changes', (
    tester,
  ) async {
    final settings = ValueNotifier(const MediaQueryData());
    addTearDown(settings.dispose);
    late Duration resolved;
    await tester.pumpWidget(
      ValueListenableBuilder<MediaQueryData>(
        valueListenable: settings,
        builder: (context, data, child) =>
            MediaQuery(data: data, child: child!),
        child: Builder(
          builder: (context) {
            resolved = context.motion(AppMotion.medium);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, AppMotion.medium);
    for (final data in const [
      MediaQueryData(reduceMotion: true),
      MediaQueryData(),
      MediaQueryData(disableAnimations: true),
      MediaQueryData(reduceMotion: true),
      MediaQueryData(),
    ]) {
      settings.value = data;
      await tester.pump();
      expect(
        resolved,
        data.disableAnimations || data.reduceMotion
            ? Duration.zero
            : AppMotion.medium,
      );
    }
  });
}
