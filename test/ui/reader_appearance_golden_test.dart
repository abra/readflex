import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_appearance_cubit.dart';
import 'package:reader/src/reader_appearance_sheet.dart';

import '../support/ui_test_app.dart';
import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);
  late UiTestApp app;
  setUp(() async => app = await UiTestApp.create(withBook: false));
  tearDown(() => app.dispose());
  for (final profile in VisualProfile.values) {
    testWidgets('appearance controls ${profile.name}', (tester) async {
      final cubit = ReaderAppearanceCubit(
        preferencesService: app.preferencesService,
        sourceId: 'appearance-fixture',
      );
      addTearDown(cubit.close);
      late BuildContext sheetContext;
      await pumpGoldenSurface(
        tester,
        profile,
        (_) => BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              sheetContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      showReaderAppearanceSheet(sheetContext);
      await tester.pumpAndSettle();
      for (final label in [
        sheetContext.l10n.readerAppearanceTitle,
        sheetContext.l10n.readerFontSize,
        sheetContext.l10n.readerLineSpacing,
      ]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(label))
              .didExceedMaxLines,
          isFalse,
          reason: '$label must stay readable',
        );
      }
      final value = find.descendant(
        of: find.byKey(const ValueKey('reader-text-scale-value')),
        matching: find.byType(Text),
      );
      expect(
        tester.renderObject<RenderParagraph>(value).didExceedMaxLines,
        isFalse,
        reason: 'Font percentage must not be truncated',
      );
      await expectUiGolden(tester, profile, 'reader-appearance');
      final pageTurn = find.byTooltip(sheetContext.l10n.readerVerticalPageTurn);
      // Short/large-text screens must make the last row reachable, not clip it.
      await tester.ensureVisible(pageTurn);
      await tester.pumpAndSettle();
      expect(pageTurn.hitTestable(), findsOneWidget);
      await expectUiGolden(tester, profile, 'reader-appearance-scrolled');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, tags: ['golden']);
  }
}
