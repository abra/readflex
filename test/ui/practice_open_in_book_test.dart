import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:practice/practice.dart';
import 'package:reader/reader.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:readflex/app/routing.dart';
import 'package:pagecraft/all_formats.dart' show TextColumnPage, TextPagesView;

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';

/// Open in book from a saved word opens the reader at the word's anchor:
/// the route carries `initialCfi`, the reader applies it once the document
/// is ready, and leaving the reader lands back on the Vocabulary list.
void main() {
  late UiTestApp app;

  setUp(() async {
    app = await UiTestApp.create();
  });
  tearDown(() async => app.dispose());

  // The fixture's third chapter.
  const anchor = 'epubcfi(/6/6)';

  testWidgets('a saved word opens its book at the anchor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = await tester.runAsync(
      () => app.dictionaryRepository.addEntry(
        word: 'power',
        translation: 'Strom',
        sourceId: app.book!.id,
        sourceType: SourceType.book,
        anchorText: 'power',
        anchorCfiRange: anchor,
      ),
    );

    await tester.pumpWidget(app.widgetAt(AppRoutes.practiceWords));
    final word = find.byKey(ValueKey('practiceWord-${entry!.id}'));
    await tapUi(tester, word);
    await tapUi(tester, find.text('Open in book'));
    String? chapter() => tester
        .element(find.byType(TextPagesView))
        .read<ReaderBloc>()
        .state
        .chapterTitle;
    await waitForUi(
      tester,
      () =>
          find.byType(TextColumnPage).evaluate().isNotEmpty &&
          chapter() == 'Chapter 3',
      description: 'reader at the word anchor',
      timeout: const Duration(seconds: 30),
    );
    expect(find.byType(ReaderScreen), findsOneWidget);
    // The reader saves its place after a pause.
    await tester.pump(const Duration(seconds: 1));

    // Leaving the reader lands on the Vocabulary list it was opened from.
    GoRouter.of(tester.element(find.byType(ReaderScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.byType(PracticeWordsScreen), findsOneWidget);
    await unmountUi(tester);
  });
}
