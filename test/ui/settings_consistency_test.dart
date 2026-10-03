import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_display_sheet.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_locale_cubit.dart';
import 'package:library_feature/src/library_theme_cubit.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';

import '../support/ui_test_app.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final profile in [VisualProfile.phone, VisualProfile.dark]) {
    testWidgets('settings sheets share geometry and roles ${profile.name}', (
      tester,
    ) async {
      final app = await tester.runAsync(
        () => UiTestApp.create(withBook: false),
      );
      addTearDown(app!.dispose);
      final preferences = app.preferencesService;
      final layout = LibraryLayoutCubit(preferencesService: preferences);
      final locale = LibraryLocaleCubit(preferencesService: preferences);
      final theme = LibraryThemeCubit(preferencesService: preferences);
      final appearance = ReaderAppearanceCubit(
        preferencesService: preferences,
        sourceId: 'settings-fixture',
      );
      addTearDown(layout.close);
      addTearDown(locale.close);
      addTearDown(theme.close);
      addTearDown(appearance.close);
      late BuildContext host;
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => BlocProvider.value(
          value: appearance,
          child: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      );

      showLibraryDisplaySheet(
        context: host,
        layoutCubit: layout,
        localeCubit: locale,
        themeCubit: theme,
      );
      await tester.pumpAndSettle();
      final displayHeader = tester.getRect(find.byType(BottomSheetHeader));
      final displaySection = tester.widget<Text>(find.text('View'));
      final displayGap =
          tester.getTopLeft(find.text('View')).dy - displayHeader.bottom;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      showReaderAppearanceSheet(host);
      await tester.pumpAndSettle();
      final readerHeader = tester.getRect(find.byType(BottomSheetHeader));
      expect(readerHeader.height, displayHeader.height);
      expect(
        tester.widget<Text>(find.text('Theme')).style,
        displaySection.style,
      );
      expect(
        tester.getTopLeft(find.text('Theme')).dy - readerHeader.bottom,
        displayGap,
      );
      final sectionLeft = tester.getTopLeft(find.text('Theme')).dx;
      expect(tester.getTopLeft(find.text('Font size')).dx, sectionLeft);
      expect(tester.getTopLeft(find.text('Line spacing')).dx, sectionLeft);
      final decrease = tester.getSize(
        find.byKey(const ValueKey('reader-text-scale-decrease')),
      );
      expect(decrease.width, greaterThanOrEqualTo(48));
      expect(decrease.height, greaterThanOrEqualTo(48));
      final sheet = tester.getRect(find.byType(BottomSheet));
      final fades = tester.getRect(find.byType(ScrollEdgeFadeStack));
      expect(fades.left, sheet.left);
      expect(fades.right, sheet.right);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
