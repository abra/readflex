import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required bool disableAnimations, required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
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

  testWidgets('context.motion collapses to zero under reduced motion', (
    tester,
  ) async {
    late Duration resolved;
    late bool reduce;
    await tester.pumpWidget(
      host(
        disableAnimations: true,
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

  testWidgets('an implicit animation driven by context.motion settles in one '
      'frame under reduced motion', (tester) async {
    var expanded = false;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        disableAnimations: true,
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
