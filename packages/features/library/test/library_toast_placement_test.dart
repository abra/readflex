import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/library_feature.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_list_view.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:toast_service/toast_service.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_collection_repository.dart';

// Its own file: the toast overlay is global for an isolate, and this test
// needs the app's ToastWrapper configuration from its first toast on.
void main() {
  final books = [
    for (final (id, title) in [('b-1', 'First Book'), ('b-2', 'Second Book')])
      Book(
        id: id,
        title: title,
        filePath: '/books/$id.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026),
      ),
  ];

  testWidgets('the deletion toast floats above the capsule, and "+" still '
      'takes taps under it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    await preferences.update(
      (prefs) => prefs.copyWith(libraryLayoutMode: LibraryLayoutMode.list.id),
    );
    final bookRepository = FakeBookRepository()..seedBooks(books);
    var addPresses = 0;
    await tester.pumpWidget(
      ToastWrapper(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: LibraryScreen(
            bookRepository: bookRepository,
            collectionRepository: FakeCollectionRepository(),
            preferencesService: preferences,
            onSourcePressed: (_, {onSourceOpened}) async {},
            onAddPressed:
                ({
                  required onImported,
                  entry = LibraryImportEntry.menu,
                }) async => addPresses++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.descendant(
      of: find.byType(LibraryListView),
      matching: find.text('First Book'),
    );
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-470, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();

    final toast = find.textContaining('deleted');
    expect(toast, findsOneWidget);
    final capsule = tester.getRect(
      find.byKey(const ValueKey('libraryFloatingActions')),
    );
    expect(
      tester.getRect(toast).bottom,
      lessThanOrEqualTo(capsule.top - AppSpacing.sm),
    );
    await tester.tap(find.byKey(const ValueKey('libraryAddButton')));
    await tester.pump();
    expect(addPresses, 1);

    await tester.pump(toastSuccessDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
