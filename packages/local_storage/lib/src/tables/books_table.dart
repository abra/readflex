import 'package:drift/drift.dart';

class BooksTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverImagePath => text().nullable()();
  TextColumn get format => text()(); // epub, fb2, mobi, pdf
  TextColumn get filePath => text()();
  IntColumn get totalLocations => integer().withDefault(const Constant(0))();
  IntColumn get currentLocation => integer().withDefault(const Constant(0))();
  RealColumn get readingProgress => real().withDefault(const Constant(0.0))();
  TextColumn get addedAt => text()(); // ISO 8601
  TextColumn get lastOpenedAt => text().nullable()(); // ISO 8601
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
