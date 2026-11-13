import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material;

import '../test_support/platform_test_app.dart';

void main() {
  testWidgets('legacy Material surface keeps its explicit radius argument', (
    tester,
  ) async {
    const radius = BorderRadius.all(Radius.circular(AppRadius.lg));
    await tester.pumpWidget(
      const PlatformTestApp(
        platform: TargetPlatform.android,
        home: AppSurface(
          borderRadius: radius,
          child: SizedBox.square(dimension: 80),
        ),
      ),
    );
    final surface = tester.widget<material.Material>(
      find.descendant(
        of: find.byType(AppSurface),
        matching: find.byType(material.Material),
      ),
    );
    expect(surface.borderRadius, radius);
    expect(surface.shape, isNull);
    expect(surface.elevation, 0);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('a custom role radius keeps its semantic outline $platform', (
      tester,
    ) async {
      const radius = BorderRadius.all(Radius.circular(AppRadius.xl));
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          home: const Center(
            child: AppSurface(
              role: AppSurfaceRole.floatingToolbar,
              borderRadius: radius,
              child: SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(AppSurface));
      final side = AppSurfaceAppearance.resolve(
        context,
        AppSurfaceRole.floatingToolbar,
      ).shape.side;
      if (platform == TargetPlatform.iOS) {
        final painted = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(AppSurface),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is ShapeDecoration &&
                  (widget.decoration as ShapeDecoration).color != null,
            ),
          ),
        );
        final shape = (painted.decoration as ShapeDecoration).shape;
        expect(
          shape,
          RoundedSuperellipseBorder(borderRadius: radius, side: side),
        );
      } else {
        final surface = tester.widget<material.Material>(
          find.descendant(
            of: find.byType(AppSurface),
            matching: find.byType(material.Material),
          ),
        );
        expect(
          surface.shape,
          RoundedRectangleBorder(borderRadius: radius, side: side),
        );
      }
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'content roles are quiet app surfaces $platform/$brightness',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            PlatformTestApp(
              platform: platform,
              brightness: brightness,
              home: const AppSurface(
                role: AppSurfaceRole.reviewCard,
                child: SizedBox(width: 200, height: 100),
              ),
            ),
          );
          final context = tester.element(find.byType(AppSurface));
          for (final role in [
            AppSurfaceRole.contentCard,
            AppSurfaceRole.reviewCard,
            AppSurfaceRole.modal,
            AppSurfaceRole.sidePanel,
          ]) {
            final appearance = AppSurfaceAppearance.resolve(context, role);
            expect(appearance.color.a, 1);
            expect(appearance.elevation, 0);
            expect(appearance.shadows, isEmpty);
            expect(appearance.blurSigma, 0);
          }
          final appearance = AppSurfaceAppearance.resolve(
            context,
            AppSurfaceRole.reviewCard,
          );
          expect(find.byType(BackdropFilter), findsNothing);
          if (platform == TargetPlatform.iOS) {
            expect(appearance.shape, isA<RoundedSuperellipseBorder>());
            expect(appearance.borderRadius, BorderRadius.circular(18));
            expect(appearance.color, context.appTheme.sheetColor);
            expect(appearance.shape.side, BorderSide.none);
            expect(
              find.descendant(
                of: find.byType(AppSurface),
                matching: find.byType(material.Material),
              ),
              findsNothing,
            );
          } else {
            expect(appearance.shape, isA<RoundedRectangleBorder>());
            expect(appearance.shape.side.color, context.colors.outlineVariant);
            expect(appearance.shape.side.width, 1);
          }
          final panel = AppSurfaceAppearance.resolve(
            context,
            AppSurfaceRole.sidePanel,
          );
          expect(panel.borderRadius, BorderRadius.zero);
          expect(panel.shape.side.color, context.colors.outlineVariant);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('explicit surface arguments override its role $platform', (
      tester,
    ) async {
      const explicitShape = CircleBorder(
        side: BorderSide(color: Color(0xFF123456)),
      );
      const explicitColor = Color(0xFFABCDEF);
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          home: const AppSurface(
            role: AppSurfaceRole.contentCard,
            color: explicitColor,
            shape: explicitShape,
            elevation: 0,
            child: SizedBox.square(dimension: 80),
          ),
        ),
      );
      if (platform == TargetPlatform.iOS) {
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(AppSurface),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(decoration.shape, explicitShape);
        expect(decoration.color, explicitColor);
      } else {
        final surface = tester.widget<material.Material>(
          find.descendant(
            of: find.byType(AppSurface),
            matching: find.byType(material.Material),
          ),
        );
        expect(surface.shape, explicitShape);
        expect(surface.color, explicitColor);
        expect(surface.elevation, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
