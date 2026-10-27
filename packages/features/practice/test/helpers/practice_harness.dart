import 'dart:io';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:local_storage/local_storage.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Real repositories over an in-memory database with an adjustable clock.
class PracticeHarness {
  PracticeHarness._(this.database, this.directory);

  final AppDatabase database;
  final Directory directory;
  DateTime now = DateTime(2026, 10, 26, 12);
  late final BookRepository books = BookRepository(
    database: database,
    booksDirectory: Directory('${directory.path}/books'),
  );
  late final ArticleRepository articles = ArticleRepository(
    database: database,
    articlesDirectory: Directory('${directory.path}/articles'),
  );
  late final HighlightRepository highlights = HighlightRepository(
    database: database,
  );
  late final DictionaryRepository dictionary = DictionaryRepository(
    database: database,
  );
  late final FsrsRepository fsrs = FsrsRepository(
    database: database,
    clock: () => now,
  );
  late final PreferencesService preferences;

  static Future<PracticeHarness> create() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final directory = await Directory.systemTemp.createTemp('practice-test-');
    final harness = PracticeHarness._(
      AppDatabase.forTesting(NativeDatabase.memory()),
      directory,
    );
    harness.preferences = await PreferencesService.create(
      supportedCodes: ReadflexSupportedLocales.codes,
    );
    return harness;
  }

  Future<void> dispose() async {
    await preferences.dispose();
    articles.dispose();
    await dictionary.dispose();
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> addBook(String id, {String title = 'A Book'}) =>
      database.booksDao.insertBook(
        BooksTableCompanion.insert(
          id: id,
          title: title,
          author: const Value('Author'),
          filePath: '$id.epub',
          format: 'epub',
          addedAt: DateTime(2026, 1, 1).toIso8601String(),
        ),
      );

  Future<DictionaryEntry> addWord(
    String word, {
    String translation = 'перевод',
    String? sourceId,
    String? context,
    String? base,
    String? contextTranslation,
    DateTime? addedAt,
  }) => dictionary.addEntry(
    word: word,
    translation: translation,
    sourceId: sourceId,
    sourceType: sourceId == null ? null : SourceType.book,
    context: context,
    baseTranslation: base,
    contextTranslation: contextTranslation,
    addedAt: addedAt,
    anchorText: word,
    anchorCfiRange: sourceId == null ? null : 'epubcfi(/6/4!/4/2,/1:0,/1:5)',
  );

  Future<Highlight> addHighlight(
    String sourceId,
    String text, {
    String? note,
    HighlightColor color = HighlightColor.yellow,
  }) => highlights.addHighlight(
    sourceId: sourceId,
    sourceType: SourceType.book,
    text: text,
    note: note,
    color: color,
    cfiRange: 'epubcfi(/6/4!/4/2,/1:0,/1:${text.length})',
    chapterTitle: 'Chapter 1',
  );

  Future<void> review(String itemId, ReviewableType type, Rating rating) =>
      fsrs.recordReview(itemId: itemId, itemType: type, rating: rating);

  Widget app(
    Widget home, {
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
  }) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: home,
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
