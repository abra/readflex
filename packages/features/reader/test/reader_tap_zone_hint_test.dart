import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_tap_action.dart';
import 'package:reader/src/reader_tap_zone_hint.dart';
import 'package:reader/src/reader_ui_cubit.dart';

void main() {
  group('ReaderTapZoneHintDriver', () {
    testWidgets('renders the latest requested tap zones', (tester) async {
      final cubit = ReaderUiCubit();
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: Directionality(
            textDirection: TextDirection.ltr,
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

      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      cubit.showTapZoneHint(ReaderTapAxis.vertical);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsNothing);
      expect(find.text('TAP AREA'), findsNWidgets(2));

      cubit.showTapZoneHint(ReaderTapAxis.horizontal);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(find.text('TAP AREA'), findsNWidgets(2));
    });
  });
}
