import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_tap_action.dart';
import 'package:reader/src/reader_tap_zone_hint.dart';
import 'package:reader/src/reader_ui_cubit.dart';

void main() {
  group('ReaderTapZoneHintDriver', () {
    testWidgets('renders the latest requested tap zones', (tester) async {
      final cubit = ReaderUiCubit();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: SizedBox(
              width: 300,
              height: 600,
              child: Stack(
                children: [
                  ReaderTapZoneHintDriver(
                    readerTheme: ReaderThemePreset.paper.data,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(AppIcons.chevronUp), findsNothing);
      expect(find.byIcon(AppIcons.chevronDown), findsNothing);

      cubit.showTapZoneHint(ReaderTapAxis.vertical);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(AppIcons.chevronUp), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronLeft), findsNothing);
      expect(find.byIcon(AppIcons.chevronRight), findsNothing);
      expect(find.text('Tap area'), findsNWidgets(2));

      cubit.showTapZoneHint(ReaderTapAxis.horizontal);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(AppIcons.chevronLeft), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronUp), findsNothing);
      expect(find.byIcon(AppIcons.chevronDown), findsNothing);
      expect(find.text('Tap area'), findsNWidgets(2));
    });

    testWidgets(
      'shows persistent vertical top and bottom edge lines only when available',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 300,
              height: 600,
              child: Stack(
                children: [
                  ReaderTapEdgeIndicator(
                    readerTheme: ReaderThemePreset.paper.data,
                    axis: ReaderTapAxis.vertical,
                    pageProgressionRtl: false,
                    canGoPrevious: false,
                    canGoNext: true,
                    contentTopMargin: 65,
                    contentBottomMargin: 35,
                    contentSideMargin: 8,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('readerTapEdgeTop')), findsNothing);
        expect(find.byKey(const Key('readerTapEdgeBottom')), findsOneWidget);
        expect(find.byKey(const Key('readerTapEdgeLeft')), findsNothing);
        expect(find.byKey(const Key('readerTapEdgeRight')), findsNothing);

        final bottomLine = tester.widget<Positioned>(
          find.byKey(const Key('readerTapEdgeBottom')),
        );
        expect(bottomLine.bottom, 29.0);
        expect(bottomLine.left, 386.0);
        expect(bottomLine.width, 28.0);
        expect(bottomLine.height, 2.0);
      },
    );

    testWidgets('hides persistent edge lines while reader page is not ready', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 600,
            child: Stack(
              children: [
                ReaderTapEdgeIndicator(
                  readerTheme: ReaderThemePreset.paper.data,
                  axis: ReaderTapAxis.vertical,
                  pageProgressionRtl: false,
                  canGoPrevious: true,
                  canGoNext: true,
                  contentTopMargin: 65,
                  contentBottomMargin: 35,
                  contentSideMargin: 8,
                  visible: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('readerTapEdgeTop')), findsNothing);
      expect(find.byKey(const Key('readerTapEdgeBottom')), findsNothing);
      expect(find.byKey(const Key('readerTapEdgeLeft')), findsNothing);
      expect(find.byKey(const Key('readerTapEdgeRight')), findsNothing);
    });

    testWidgets(
      'maps persistent horizontal edge lines through RTL progression',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 300,
              height: 600,
              child: Stack(
                children: [
                  ReaderTapEdgeIndicator(
                    readerTheme: ReaderThemePreset.paper.data,
                    axis: ReaderTapAxis.horizontal,
                    pageProgressionRtl: true,
                    canGoPrevious: false,
                    canGoNext: true,
                    contentTopMargin: 65,
                    contentBottomMargin: 35,
                    contentSideMargin: 8,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('readerTapEdgeLeft')), findsOneWidget);
        expect(find.byKey(const Key('readerTapEdgeRight')), findsNothing);
        expect(find.byKey(const Key('readerTapEdgeTop')), findsNothing);
        expect(find.byKey(const Key('readerTapEdgeBottom')), findsNothing);

        final leftLine = tester.widget<Positioned>(
          find.byKey(const Key('readerTapEdgeLeft')),
        );
        expect(leftLine.left, 4.0);
        expect(leftLine.top, 302.5);
        expect(leftLine.width, 2.0);
        expect(leftLine.height, 25.0);
      },
    );
  });

  group('readerTapZoneHintInk', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final preset in ReaderThemePreset.values) {
      test('hint text reaches 4.5:1 on ${preset.id}', () {
        final theme = preset.data;
        final composite = Color.alphaBlend(
          theme.accentColor.withValues(alpha: 0.45),
          theme.backgroundColor,
        );
        for (final app in [AppTheme.light(), AppTheme.dark()]) {
          final ink = readerTapZoneHintInk(app.ext, composite);
          expect(contrast(ink, composite), greaterThanOrEqualTo(4.5));
        }
      });
    }
  });
}
