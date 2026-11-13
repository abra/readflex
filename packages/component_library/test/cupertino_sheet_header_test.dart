import 'package:component_library/component_library.dart';
import 'package:component_library/src/bottom_sheet_title_bar.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder action(String label) => find.byWidgetPredicate(
    (widget) => widget is AppPlainIconButton && widget.tooltip == label,
  );

  for (final direction in TextDirection.values) {
    for (final hasBack in [false, true]) {
      testWidgets(
        'Cupertino title stays centered with Back=$hasBack $direction',
        (
          tester,
        ) async {
          var backs = 0;
          var closes = 0;
          await tester.pumpWidget(
            _HeaderFixture(
              width: 390,
              direction: direction,
              child: BottomSheetHeader(
                title: 'Settings',
                padding: const EdgeInsets.symmetric(horizontal: 24),
                backLabel: hasBack ? 'Zurück' : null,
                onBack: hasBack ? () => backs++ : null,
                closeLabel: 'Schließen',
                onClose: () => closes++,
              ),
            ),
          );
          final header = tester.getRect(find.byType(BottomSheetHeader));
          final title = tester.getRect(find.text('Settings'));
          final close = tester.getRect(action('Schließen'));
          expect(title.center.dx, closeTo(header.center.dx, .01));
          expect(close.size, const Size(48, 48));
          expect(header.height, 48);
          final icon = tester.widget<Icon>(
            find.descendant(
              of: action('Schließen'),
              matching: find.byType(Icon),
            ),
          );
          expect(icon.size, 18);
          await tester.tapAt(close.topLeft + const Offset(2, 2));
          expect(closes, 1);
          if (hasBack) {
            final back = tester.getRect(action('Zurück'));
            expect(back.size, close.size);
            expect(back.center.dy, close.center.dy);
            await tester.tapAt(back.topLeft + const Offset(2, 2));
            expect(backs, 1);
            final backIcon = tester.widget<Icon>(
              find.descendant(
                of: action('Zurück'),
                matching: find.byType(Icon),
              ),
            );
            expect(
              backIcon.icon,
              direction == TextDirection.rtl
                  ? AppIcons.chevronRight
                  : AppIcons.chevronLeft,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Cupertino long 200% title stays whole below actions $direction',
      (
        tester,
      ) async {
        var closes = 0;
        var resets = 0;
        const title = 'A long translated appearance heading';
        await tester.pumpWidget(
          _HeaderFixture(
            width: 320,
            scale: 2,
            direction: direction,
            child: BottomSheetHeader(
              title: title,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              backLabel: 'Back',
              onBack: () {},
              closeLabel: 'Close',
              onClose: () => closes++,
              trailing: CupertinoButton(
                onPressed: () => resets++,
                child: const Text('Reset appearance'),
              ),
            ),
          ),
        );
        final header = tester.getRect(find.byType(BottomSheetHeader));
        final heading = tester.getRect(find.text(title));
        final back = tester.getRect(action('Back'));
        final close = tester.getRect(action('Close'));
        final reset = tester.getRect(find.text('Reset appearance'));
        expect(heading.center.dx, closeTo(header.center.dx, .01));
        expect(heading.top, greaterThanOrEqualTo(back.bottom));
        expect(heading.top, greaterThanOrEqualTo(close.bottom));
        expect(heading.top, greaterThanOrEqualTo(reset.bottom));
        expect(heading.left, greaterThanOrEqualTo(header.left));
        expect(heading.right, lessThanOrEqualTo(header.right));
        expect(tester.widget<Text>(find.text(title)).maxLines, isNull);
        expect(tester.widget<Text>(find.text(title)).overflow, isNull);
        await tester.tap(find.text('Reset appearance'));
        await tester.tap(action('Close'));
        expect(resets, 1);
        expect(closes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cupertino compact action preserves centered title and semantics',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var compactTaps = 0;
        await tester.pumpWidget(
          _HeaderFixture(
            width: 320,
            child: BottomSheetHeader(
              title: 'Title',
              padding: const EdgeInsets.symmetric(horizontal: 24),
              closeLabel: 'Close',
              onClose: () {},
              trailing: CupertinoButton(
                onPressed: () {},
                child: const Text('Reset appearance'),
              ),
              compactTrailing: AppPlainIconButton(
                icon: AppIcons.refresh,
                tooltip: 'Reset appearance',
                onPressed: () => compactTaps++,
              ),
            ),
          ),
        );
        await tester.pump();
        final layout = tester.renderObject<RenderBottomSheetTitleBar>(
          find.byType(BottomSheetTitleBar),
        );
        expect(layout.compactShown, isTrue);
        final header = tester.getRect(find.byType(BottomSheetHeader));
        final title = tester.getRect(find.text('Title'));
        expect(title.center.dx, closeTo(header.center.dx, .01));
        expect(header.height, 48);
        expect(find.text('Reset appearance').hitTestable(), findsNothing);
        final names = <String, int>{};
        final root = tester
            .renderObject(find.byType(BottomSheetHeader))
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!;
        void collect(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.hasAction(SemanticsAction.tap) && data.tooltip.isNotEmpty) {
            names.update(data.tooltip, (count) => count + 1, ifAbsent: () => 1);
          }
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(root);
        expect(names['Close'], 1);
        expect(names['Reset appearance'], 1);
        await tester.tap(action('Reset appearance'));
        expect(compactTaps, 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Cupertino leading and trailing title layouts support dry sizing',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        _HeaderFixture(
          width: 320,
          child: BottomSheetHeader(
            title: 'Settings',
            onBack: () {},
            backLabel: 'Back',
            closeLabel: 'Close',
            onClose: () {},
          ),
        ),
      );
      final render = tester.renderObject<RenderBottomSheetTitleBar>(
        find.byType(BottomSheetTitleBar),
      );
      expect(
        render.getDryLayout(render.constraints),
        render.size,
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Settings'),
      );
      final baseline = paragraph.getDryBaseline(
        paragraph.constraints,
        TextBaseline.alphabetic,
      )!;
      final title = tester.getRect(find.text('Settings'));
      final bar = tester.getRect(find.byType(BottomSheetTitleBar));
      expect(
        render.getDryBaseline(render.constraints, TextBaseline.alphabetic),
        closeTo(title.top - bar.top + baseline * render.titleScale, .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('Cupertino sheet section has native grouped fill $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        _HeaderFixture(
          width: 320,
          brightness: brightness,
          child: const AppSheetSection(
            title: 'Reading',
            child: SizedBox(height: 48, child: Text('Body')),
          ),
        ),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(AppSheetSection),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration;
      expect((decoration.shape as OutlinedBorder).side, BorderSide.none);
      expect(decoration.color!.a, 1);
      final context = tester.element(find.byType(AppSheetSection));
      final appearance = AppSurfaceAppearance.resolve(
        context,
        AppSurfaceRole.field,
      );
      expect(decoration.color, appearance.color);
      expect(decoration.shape, appearance.shape);
      expect(decoration.shape, isA<RoundedSuperellipseBorder>());
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _HeaderFixture extends StatelessWidget {
  const _HeaderFixture({
    required this.width,
    required this.child,
    this.scale = 1,
    this.direction = TextDirection.ltr,
    this.brightness = Brightness.light,
  });

  final double width;
  final double scale;
  final TextDirection direction;
  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final adapter = AppTheme.forPlatform(TargetPlatform.iOS, brightness);
    return CupertinoApp(
      theme: AppTheme.cupertino(adapter),
      builder: (context, child) => AppThemeScope(
        data: AppTheme.dataFor(adapter),
        child: Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
        ),
      ),
      home: CupertinoPageScaffold(
        child: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }
}
