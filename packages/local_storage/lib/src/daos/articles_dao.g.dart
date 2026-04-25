// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'articles_dao.dart';

// ignore_for_file: type=lint
mixin _$ArticlesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ArticlesTableTable get articlesTable => attachedDatabase.articlesTable;
  ArticlesDaoManager get managers => ArticlesDaoManager(this);
}

class ArticlesDaoManager {
  final _$ArticlesDaoMixin _db;
  ArticlesDaoManager(this._db);
  $$ArticlesTableTableTableManager get articlesTable =>
      $$ArticlesTableTableTableManager(_db.attachedDatabase, _db.articlesTable);
}
