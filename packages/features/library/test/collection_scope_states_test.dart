import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/select_collection_scope_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  Future<ReadflexLocalizations> open(
    WidgetTester tester,
    LibraryState state, {
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLibraryCollectionScopeSheet(
                context: context,
                state: state,
                onRetry: onRetry,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return tester.element(find.byType(BottomSheet)).l10n;
  }

  testWidgets('load failure uses the shared error state with filled Retry', (
    tester,
  ) async {
    var retries = 0;
    final strings = await open(
      tester,
      LibraryState(collectionsLoadFailed: true),
      onRetry: () => retries++,
    );
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(strings.libraryLoadCollectionsFailed), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, strings.commonRetry),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.refresh), findsNothing);
    expect(find.widgetWithText(TextButton, strings.commonRetry), findsNothing);
    await tester.tap(find.text(strings.commonRetry));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no collections uses a compact empty state', (tester) async {
    final strings = await open(tester, LibraryState());
    final empty = find.byType(EmptyState);
    expect(empty, findsOneWidget);
    expect(tester.widget<EmptyState>(empty).compact, isTrue);
    expect(find.text(strings.libraryNoCollectionsYet), findsOneWidget);
    expect(find.byType(SearchField), findsNothing);
  });

  testWidgets('no matching collections uses a compact empty state', (
    tester,
  ) async {
    final strings = await open(
      tester,
      LibraryState(collectionScopes: [LibraryCollectionScope.favourites()]),
    );
    expect(find.byType(EmptyState), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    final empty = find.byType(EmptyState);
    expect(empty, findsOneWidget);
    expect(tester.widget<EmptyState>(empty).compact, isTrue);
    expect(find.text(strings.libraryNoMatchingCollections), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
