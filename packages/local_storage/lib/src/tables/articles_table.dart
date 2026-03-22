import 'package:drift/drift.dart';

class ArticlesTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get siteName => text().nullable()();
  TextColumn get url => text()();
  TextColumn get cleanedHtml => text()();
  TextColumn get coverImageUrl => text().nullable()();
  IntColumn get estimatedWordCount =>
      integer().withDefault(const Constant(0))();
  RealColumn get currentScrollOffset =>
      real().withDefault(const Constant(0.0))();
  TextColumn get addedAt => text()(); // ISO 8601
  TextColumn get lastOpenedAt => text().nullable()(); // ISO 8601
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
