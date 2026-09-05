import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  testWidgets('retries the route source after the initial load fails', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = await PreferencesService.create(
      supportedCodes: const ['en'],
    );
    addTearDown(preferences.dispose);
    final books = _UnavailableBookRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: ReaderScreen(
          sourceId: 'book-1',
          serverBaseUri: Uri.parse('http://127.0.0.1:8080'),
          bookRepository: books,
          highlightRepository: FakeHighlightRepository(),
          preferencesService: preferences,
          screenControlService: _ScreenControlService(),
          textActions: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(books.requestedIds, ['book-1']);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(books.requestedIds, ['book-1', 'book-1']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _UnavailableBookRepository extends FakeBookRepository {
  final requestedIds = <String>[];

  @override
  Future<Book?> getBookById(String id) async {
    requestedIds.add(id);
    throw StateError('Storage unavailable');
  }
}

class _ScreenControlService implements ScreenControlService {
  @override
  Future<void> keepAwake() async {}

  @override
  Future<void> allowSleep() async {}

  @override
  Future<double?> readApplicationBrightness() async => 0.5;

  @override
  Future<void> setApplicationBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationBrightness() async {}
}
