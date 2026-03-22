// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTableTable extends BooksTable
    with TableInfo<$BooksTableTable, BooksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverImagePathMeta = const VerificationMeta(
    'coverImagePath',
  );
  @override
  late final GeneratedColumn<String> coverImagePath = GeneratedColumn<String>(
    'cover_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalLocationsMeta = const VerificationMeta(
    'totalLocations',
  );
  @override
  late final GeneratedColumn<int> totalLocations = GeneratedColumn<int>(
    'total_locations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentLocationMeta = const VerificationMeta(
    'currentLocation',
  );
  @override
  late final GeneratedColumn<int> currentLocation = GeneratedColumn<int>(
    'current_location',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readingProgressMeta = const VerificationMeta(
    'readingProgress',
  );
  @override
  late final GeneratedColumn<double> readingProgress = GeneratedColumn<double>(
    'reading_progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<String> addedAt = GeneratedColumn<String>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<String> lastOpenedAt = GeneratedColumn<String>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    coverImagePath,
    format,
    filePath,
    totalLocations,
    currentLocation,
    readingProgress,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<BooksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover_image_path')) {
      context.handle(
        _coverImagePathMeta,
        coverImagePath.isAcceptableOrUnknown(
          data['cover_image_path']!,
          _coverImagePathMeta,
        ),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('total_locations')) {
      context.handle(
        _totalLocationsMeta,
        totalLocations.isAcceptableOrUnknown(
          data['total_locations']!,
          _totalLocationsMeta,
        ),
      );
    }
    if (data.containsKey('current_location')) {
      context.handle(
        _currentLocationMeta,
        currentLocation.isAcceptableOrUnknown(
          data['current_location']!,
          _currentLocationMeta,
        ),
      );
    }
    if (data.containsKey('reading_progress')) {
      context.handle(
        _readingProgressMeta,
        readingProgress.isAcceptableOrUnknown(
          data['reading_progress']!,
          _readingProgressMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BooksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BooksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      coverImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_path'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      totalLocations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_locations'],
      )!,
      currentLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_location'],
      )!,
      readingProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reading_progress'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_opened_at'],
      ),
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      )!,
    );
  }

  @override
  $BooksTableTable createAlias(String alias) {
    return $BooksTableTable(attachedDatabase, alias);
  }
}

class BooksTableData extends DataClass implements Insertable<BooksTableData> {
  final String id;
  final String title;
  final String? author;
  final String? coverImagePath;
  final String format;
  final String filePath;
  final int totalLocations;
  final int currentLocation;
  final double readingProgress;
  final String addedAt;
  final String? lastOpenedAt;
  final bool isFinished;
  const BooksTableData({
    required this.id,
    required this.title,
    this.author,
    this.coverImagePath,
    required this.format,
    required this.filePath,
    required this.totalLocations,
    required this.currentLocation,
    required this.readingProgress,
    required this.addedAt,
    this.lastOpenedAt,
    required this.isFinished,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || coverImagePath != null) {
      map['cover_image_path'] = Variable<String>(coverImagePath);
    }
    map['format'] = Variable<String>(format);
    map['file_path'] = Variable<String>(filePath);
    map['total_locations'] = Variable<int>(totalLocations);
    map['current_location'] = Variable<int>(currentLocation);
    map['reading_progress'] = Variable<double>(readingProgress);
    map['added_at'] = Variable<String>(addedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<String>(lastOpenedAt);
    }
    map['is_finished'] = Variable<bool>(isFinished);
    return map;
  }

  BooksTableCompanion toCompanion(bool nullToAbsent) {
    return BooksTableCompanion(
      id: Value(id),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      coverImagePath: coverImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImagePath),
      format: Value(format),
      filePath: Value(filePath),
      totalLocations: Value(totalLocations),
      currentLocation: Value(currentLocation),
      readingProgress: Value(readingProgress),
      addedAt: Value(addedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      isFinished: Value(isFinished),
    );
  }

  factory BooksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BooksTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      coverImagePath: serializer.fromJson<String?>(json['coverImagePath']),
      format: serializer.fromJson<String>(json['format']),
      filePath: serializer.fromJson<String>(json['filePath']),
      totalLocations: serializer.fromJson<int>(json['totalLocations']),
      currentLocation: serializer.fromJson<int>(json['currentLocation']),
      readingProgress: serializer.fromJson<double>(json['readingProgress']),
      addedAt: serializer.fromJson<String>(json['addedAt']),
      lastOpenedAt: serializer.fromJson<String?>(json['lastOpenedAt']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'coverImagePath': serializer.toJson<String?>(coverImagePath),
      'format': serializer.toJson<String>(format),
      'filePath': serializer.toJson<String>(filePath),
      'totalLocations': serializer.toJson<int>(totalLocations),
      'currentLocation': serializer.toJson<int>(currentLocation),
      'readingProgress': serializer.toJson<double>(readingProgress),
      'addedAt': serializer.toJson<String>(addedAt),
      'lastOpenedAt': serializer.toJson<String?>(lastOpenedAt),
      'isFinished': serializer.toJson<bool>(isFinished),
    };
  }

  BooksTableData copyWith({
    String? id,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> coverImagePath = const Value.absent(),
    String? format,
    String? filePath,
    int? totalLocations,
    int? currentLocation,
    double? readingProgress,
    String? addedAt,
    Value<String?> lastOpenedAt = const Value.absent(),
    bool? isFinished,
  }) => BooksTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    coverImagePath: coverImagePath.present
        ? coverImagePath.value
        : this.coverImagePath,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    totalLocations: totalLocations ?? this.totalLocations,
    currentLocation: currentLocation ?? this.currentLocation,
    readingProgress: readingProgress ?? this.readingProgress,
    addedAt: addedAt ?? this.addedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    isFinished: isFinished ?? this.isFinished,
  );
  BooksTableData copyWithCompanion(BooksTableCompanion data) {
    return BooksTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverImagePath: data.coverImagePath.present
          ? data.coverImagePath.value
          : this.coverImagePath,
      format: data.format.present ? data.format.value : this.format,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      totalLocations: data.totalLocations.present
          ? data.totalLocations.value
          : this.totalLocations,
      currentLocation: data.currentLocation.present
          ? data.currentLocation.value
          : this.currentLocation,
      readingProgress: data.readingProgress.present
          ? data.readingProgress.value
          : this.readingProgress,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BooksTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverImagePath: $coverImagePath, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('totalLocations: $totalLocations, ')
          ..write('currentLocation: $currentLocation, ')
          ..write('readingProgress: $readingProgress, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('isFinished: $isFinished')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    coverImagePath,
    format,
    filePath,
    totalLocations,
    currentLocation,
    readingProgress,
    addedAt,
    lastOpenedAt,
    isFinished,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BooksTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverImagePath == this.coverImagePath &&
          other.format == this.format &&
          other.filePath == this.filePath &&
          other.totalLocations == this.totalLocations &&
          other.currentLocation == this.currentLocation &&
          other.readingProgress == this.readingProgress &&
          other.addedAt == this.addedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.isFinished == this.isFinished);
}

class BooksTableCompanion extends UpdateCompanion<BooksTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> coverImagePath;
  final Value<String> format;
  final Value<String> filePath;
  final Value<int> totalLocations;
  final Value<int> currentLocation;
  final Value<double> readingProgress;
  final Value<String> addedAt;
  final Value<String?> lastOpenedAt;
  final Value<bool> isFinished;
  final Value<int> rowid;
  const BooksTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverImagePath = const Value.absent(),
    this.format = const Value.absent(),
    this.filePath = const Value.absent(),
    this.totalLocations = const Value.absent(),
    this.currentLocation = const Value.absent(),
    this.readingProgress = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksTableCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    this.coverImagePath = const Value.absent(),
    required String format,
    required String filePath,
    this.totalLocations = const Value.absent(),
    this.currentLocation = const Value.absent(),
    this.readingProgress = const Value.absent(),
    required String addedAt,
    this.lastOpenedAt = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       filePath = Value(filePath),
       addedAt = Value(addedAt);
  static Insertable<BooksTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverImagePath,
    Expression<String>? format,
    Expression<String>? filePath,
    Expression<int>? totalLocations,
    Expression<int>? currentLocation,
    Expression<double>? readingProgress,
    Expression<String>? addedAt,
    Expression<String>? lastOpenedAt,
    Expression<bool>? isFinished,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverImagePath != null) 'cover_image_path': coverImagePath,
      if (format != null) 'format': format,
      if (filePath != null) 'file_path': filePath,
      if (totalLocations != null) 'total_locations': totalLocations,
      if (currentLocation != null) 'current_location': currentLocation,
      if (readingProgress != null) 'reading_progress': readingProgress,
      if (addedAt != null) 'added_at': addedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (isFinished != null) 'is_finished': isFinished,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? coverImagePath,
    Value<String>? format,
    Value<String>? filePath,
    Value<int>? totalLocations,
    Value<int>? currentLocation,
    Value<double>? readingProgress,
    Value<String>? addedAt,
    Value<String?>? lastOpenedAt,
    Value<bool>? isFinished,
    Value<int>? rowid,
  }) {
    return BooksTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      totalLocations: totalLocations ?? this.totalLocations,
      currentLocation: currentLocation ?? this.currentLocation,
      readingProgress: readingProgress ?? this.readingProgress,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isFinished: isFinished ?? this.isFinished,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverImagePath.present) {
      map['cover_image_path'] = Variable<String>(coverImagePath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (totalLocations.present) {
      map['total_locations'] = Variable<int>(totalLocations.value);
    }
    if (currentLocation.present) {
      map['current_location'] = Variable<int>(currentLocation.value);
    }
    if (readingProgress.present) {
      map['reading_progress'] = Variable<double>(readingProgress.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<String>(addedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<String>(lastOpenedAt.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverImagePath: $coverImagePath, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('totalLocations: $totalLocations, ')
          ..write('currentLocation: $currentLocation, ')
          ..write('readingProgress: $readingProgress, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('isFinished: $isFinished, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticlesTableTable extends ArticlesTable
    with TableInfo<$ArticlesTableTable, ArticlesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siteNameMeta = const VerificationMeta(
    'siteName',
  );
  @override
  late final GeneratedColumn<String> siteName = GeneratedColumn<String>(
    'site_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cleanedHtmlMeta = const VerificationMeta(
    'cleanedHtml',
  );
  @override
  late final GeneratedColumn<String> cleanedHtml = GeneratedColumn<String>(
    'cleaned_html',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverImageUrlMeta = const VerificationMeta(
    'coverImageUrl',
  );
  @override
  late final GeneratedColumn<String> coverImageUrl = GeneratedColumn<String>(
    'cover_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedWordCountMeta =
      const VerificationMeta('estimatedWordCount');
  @override
  late final GeneratedColumn<int> estimatedWordCount = GeneratedColumn<int>(
    'estimated_word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentScrollOffsetMeta =
      const VerificationMeta('currentScrollOffset');
  @override
  late final GeneratedColumn<double> currentScrollOffset =
      GeneratedColumn<double>(
        'current_scroll_offset',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<String> addedAt = GeneratedColumn<String>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<String> lastOpenedAt = GeneratedColumn<String>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    siteName,
    url,
    cleanedHtml,
    coverImageUrl,
    estimatedWordCount,
    currentScrollOffset,
    addedAt,
    lastOpenedAt,
    isFinished,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticlesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('site_name')) {
      context.handle(
        _siteNameMeta,
        siteName.isAcceptableOrUnknown(data['site_name']!, _siteNameMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('cleaned_html')) {
      context.handle(
        _cleanedHtmlMeta,
        cleanedHtml.isAcceptableOrUnknown(
          data['cleaned_html']!,
          _cleanedHtmlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cleanedHtmlMeta);
    }
    if (data.containsKey('cover_image_url')) {
      context.handle(
        _coverImageUrlMeta,
        coverImageUrl.isAcceptableOrUnknown(
          data['cover_image_url']!,
          _coverImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('estimated_word_count')) {
      context.handle(
        _estimatedWordCountMeta,
        estimatedWordCount.isAcceptableOrUnknown(
          data['estimated_word_count']!,
          _estimatedWordCountMeta,
        ),
      );
    }
    if (data.containsKey('current_scroll_offset')) {
      context.handle(
        _currentScrollOffsetMeta,
        currentScrollOffset.isAcceptableOrUnknown(
          data['current_scroll_offset']!,
          _currentScrollOffsetMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArticlesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticlesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      siteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_name'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      cleanedHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cleaned_html'],
      )!,
      coverImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_url'],
      ),
      estimatedWordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_word_count'],
      )!,
      currentScrollOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_scroll_offset'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_opened_at'],
      ),
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      )!,
    );
  }

  @override
  $ArticlesTableTable createAlias(String alias) {
    return $ArticlesTableTable(attachedDatabase, alias);
  }
}

class ArticlesTableData extends DataClass
    implements Insertable<ArticlesTableData> {
  final String id;
  final String title;
  final String? siteName;
  final String url;
  final String cleanedHtml;
  final String? coverImageUrl;
  final int estimatedWordCount;
  final double currentScrollOffset;
  final String addedAt;
  final String? lastOpenedAt;
  final bool isFinished;
  const ArticlesTableData({
    required this.id,
    required this.title,
    this.siteName,
    required this.url,
    required this.cleanedHtml,
    this.coverImageUrl,
    required this.estimatedWordCount,
    required this.currentScrollOffset,
    required this.addedAt,
    this.lastOpenedAt,
    required this.isFinished,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || siteName != null) {
      map['site_name'] = Variable<String>(siteName);
    }
    map['url'] = Variable<String>(url);
    map['cleaned_html'] = Variable<String>(cleanedHtml);
    if (!nullToAbsent || coverImageUrl != null) {
      map['cover_image_url'] = Variable<String>(coverImageUrl);
    }
    map['estimated_word_count'] = Variable<int>(estimatedWordCount);
    map['current_scroll_offset'] = Variable<double>(currentScrollOffset);
    map['added_at'] = Variable<String>(addedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<String>(lastOpenedAt);
    }
    map['is_finished'] = Variable<bool>(isFinished);
    return map;
  }

  ArticlesTableCompanion toCompanion(bool nullToAbsent) {
    return ArticlesTableCompanion(
      id: Value(id),
      title: Value(title),
      siteName: siteName == null && nullToAbsent
          ? const Value.absent()
          : Value(siteName),
      url: Value(url),
      cleanedHtml: Value(cleanedHtml),
      coverImageUrl: coverImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageUrl),
      estimatedWordCount: Value(estimatedWordCount),
      currentScrollOffset: Value(currentScrollOffset),
      addedAt: Value(addedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      isFinished: Value(isFinished),
    );
  }

  factory ArticlesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticlesTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      siteName: serializer.fromJson<String?>(json['siteName']),
      url: serializer.fromJson<String>(json['url']),
      cleanedHtml: serializer.fromJson<String>(json['cleanedHtml']),
      coverImageUrl: serializer.fromJson<String?>(json['coverImageUrl']),
      estimatedWordCount: serializer.fromJson<int>(json['estimatedWordCount']),
      currentScrollOffset: serializer.fromJson<double>(
        json['currentScrollOffset'],
      ),
      addedAt: serializer.fromJson<String>(json['addedAt']),
      lastOpenedAt: serializer.fromJson<String?>(json['lastOpenedAt']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'siteName': serializer.toJson<String?>(siteName),
      'url': serializer.toJson<String>(url),
      'cleanedHtml': serializer.toJson<String>(cleanedHtml),
      'coverImageUrl': serializer.toJson<String?>(coverImageUrl),
      'estimatedWordCount': serializer.toJson<int>(estimatedWordCount),
      'currentScrollOffset': serializer.toJson<double>(currentScrollOffset),
      'addedAt': serializer.toJson<String>(addedAt),
      'lastOpenedAt': serializer.toJson<String?>(lastOpenedAt),
      'isFinished': serializer.toJson<bool>(isFinished),
    };
  }

  ArticlesTableData copyWith({
    String? id,
    String? title,
    Value<String?> siteName = const Value.absent(),
    String? url,
    String? cleanedHtml,
    Value<String?> coverImageUrl = const Value.absent(),
    int? estimatedWordCount,
    double? currentScrollOffset,
    String? addedAt,
    Value<String?> lastOpenedAt = const Value.absent(),
    bool? isFinished,
  }) => ArticlesTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    siteName: siteName.present ? siteName.value : this.siteName,
    url: url ?? this.url,
    cleanedHtml: cleanedHtml ?? this.cleanedHtml,
    coverImageUrl: coverImageUrl.present
        ? coverImageUrl.value
        : this.coverImageUrl,
    estimatedWordCount: estimatedWordCount ?? this.estimatedWordCount,
    currentScrollOffset: currentScrollOffset ?? this.currentScrollOffset,
    addedAt: addedAt ?? this.addedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    isFinished: isFinished ?? this.isFinished,
  );
  ArticlesTableData copyWithCompanion(ArticlesTableCompanion data) {
    return ArticlesTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      siteName: data.siteName.present ? data.siteName.value : this.siteName,
      url: data.url.present ? data.url.value : this.url,
      cleanedHtml: data.cleanedHtml.present
          ? data.cleanedHtml.value
          : this.cleanedHtml,
      coverImageUrl: data.coverImageUrl.present
          ? data.coverImageUrl.value
          : this.coverImageUrl,
      estimatedWordCount: data.estimatedWordCount.present
          ? data.estimatedWordCount.value
          : this.estimatedWordCount,
      currentScrollOffset: data.currentScrollOffset.present
          ? data.currentScrollOffset.value
          : this.currentScrollOffset,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('siteName: $siteName, ')
          ..write('url: $url, ')
          ..write('cleanedHtml: $cleanedHtml, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('estimatedWordCount: $estimatedWordCount, ')
          ..write('currentScrollOffset: $currentScrollOffset, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('isFinished: $isFinished')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    siteName,
    url,
    cleanedHtml,
    coverImageUrl,
    estimatedWordCount,
    currentScrollOffset,
    addedAt,
    lastOpenedAt,
    isFinished,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticlesTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.siteName == this.siteName &&
          other.url == this.url &&
          other.cleanedHtml == this.cleanedHtml &&
          other.coverImageUrl == this.coverImageUrl &&
          other.estimatedWordCount == this.estimatedWordCount &&
          other.currentScrollOffset == this.currentScrollOffset &&
          other.addedAt == this.addedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.isFinished == this.isFinished);
}

class ArticlesTableCompanion extends UpdateCompanion<ArticlesTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> siteName;
  final Value<String> url;
  final Value<String> cleanedHtml;
  final Value<String?> coverImageUrl;
  final Value<int> estimatedWordCount;
  final Value<double> currentScrollOffset;
  final Value<String> addedAt;
  final Value<String?> lastOpenedAt;
  final Value<bool> isFinished;
  final Value<int> rowid;
  const ArticlesTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.siteName = const Value.absent(),
    this.url = const Value.absent(),
    this.cleanedHtml = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.estimatedWordCount = const Value.absent(),
    this.currentScrollOffset = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesTableCompanion.insert({
    required String id,
    required String title,
    this.siteName = const Value.absent(),
    required String url,
    required String cleanedHtml,
    this.coverImageUrl = const Value.absent(),
    this.estimatedWordCount = const Value.absent(),
    this.currentScrollOffset = const Value.absent(),
    required String addedAt,
    this.lastOpenedAt = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       url = Value(url),
       cleanedHtml = Value(cleanedHtml),
       addedAt = Value(addedAt);
  static Insertable<ArticlesTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? siteName,
    Expression<String>? url,
    Expression<String>? cleanedHtml,
    Expression<String>? coverImageUrl,
    Expression<int>? estimatedWordCount,
    Expression<double>? currentScrollOffset,
    Expression<String>? addedAt,
    Expression<String>? lastOpenedAt,
    Expression<bool>? isFinished,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (siteName != null) 'site_name': siteName,
      if (url != null) 'url': url,
      if (cleanedHtml != null) 'cleaned_html': cleanedHtml,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (estimatedWordCount != null)
        'estimated_word_count': estimatedWordCount,
      if (currentScrollOffset != null)
        'current_scroll_offset': currentScrollOffset,
      if (addedAt != null) 'added_at': addedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (isFinished != null) 'is_finished': isFinished,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? siteName,
    Value<String>? url,
    Value<String>? cleanedHtml,
    Value<String?>? coverImageUrl,
    Value<int>? estimatedWordCount,
    Value<double>? currentScrollOffset,
    Value<String>? addedAt,
    Value<String?>? lastOpenedAt,
    Value<bool>? isFinished,
    Value<int>? rowid,
  }) {
    return ArticlesTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      siteName: siteName ?? this.siteName,
      url: url ?? this.url,
      cleanedHtml: cleanedHtml ?? this.cleanedHtml,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      estimatedWordCount: estimatedWordCount ?? this.estimatedWordCount,
      currentScrollOffset: currentScrollOffset ?? this.currentScrollOffset,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isFinished: isFinished ?? this.isFinished,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (siteName.present) {
      map['site_name'] = Variable<String>(siteName.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (cleanedHtml.present) {
      map['cleaned_html'] = Variable<String>(cleanedHtml.value);
    }
    if (coverImageUrl.present) {
      map['cover_image_url'] = Variable<String>(coverImageUrl.value);
    }
    if (estimatedWordCount.present) {
      map['estimated_word_count'] = Variable<int>(estimatedWordCount.value);
    }
    if (currentScrollOffset.present) {
      map['current_scroll_offset'] = Variable<double>(
        currentScrollOffset.value,
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<String>(addedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<String>(lastOpenedAt.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('siteName: $siteName, ')
          ..write('url: $url, ')
          ..write('cleanedHtml: $cleanedHtml, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('estimatedWordCount: $estimatedWordCount, ')
          ..write('currentScrollOffset: $currentScrollOffset, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('isFinished: $isFinished, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HighlightsTableTable extends HighlightsTable
    with TableInfo<$HighlightsTableTable, HighlightsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HighlightsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highlightTextMeta = const VerificationMeta(
    'highlightText',
  );
  @override
  late final GeneratedColumn<String> highlightText = GeneratedColumn<String>(
    'highlight_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cfiRangeMeta = const VerificationMeta(
    'cfiRange',
  );
  @override
  late final GeneratedColumn<String> cfiRange = GeneratedColumn<String>(
    'cfi_range',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scrollOffsetMeta = const VerificationMeta(
    'scrollOffset',
  );
  @override
  late final GeneratedColumn<double> scrollOffset = GeneratedColumn<double>(
    'scroll_offset',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yellow'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    sourceType,
    highlightText,
    note,
    cfiRange,
    pageNumber,
    scrollOffset,
    color,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'highlights_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<HighlightsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('highlight_text')) {
      context.handle(
        _highlightTextMeta,
        highlightText.isAcceptableOrUnknown(
          data['highlight_text']!,
          _highlightTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highlightTextMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('cfi_range')) {
      context.handle(
        _cfiRangeMeta,
        cfiRange.isAcceptableOrUnknown(data['cfi_range']!, _cfiRangeMeta),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('scroll_offset')) {
      context.handle(
        _scrollOffsetMeta,
        scrollOffset.isAcceptableOrUnknown(
          data['scroll_offset']!,
          _scrollOffsetMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HighlightsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HighlightsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      highlightText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlight_text'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      cfiRange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cfi_range'],
      ),
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      scrollOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scroll_offset'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HighlightsTableTable createAlias(String alias) {
    return $HighlightsTableTable(attachedDatabase, alias);
  }
}

class HighlightsTableData extends DataClass
    implements Insertable<HighlightsTableData> {
  final String id;
  final String sourceId;
  final String sourceType;
  final String highlightText;
  final String? note;
  final String? cfiRange;
  final int? pageNumber;
  final double? scrollOffset;
  final String color;
  final String createdAt;
  const HighlightsTableData({
    required this.id,
    required this.sourceId,
    required this.sourceType,
    required this.highlightText,
    this.note,
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
    required this.color,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['source_type'] = Variable<String>(sourceType);
    map['highlight_text'] = Variable<String>(highlightText);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || cfiRange != null) {
      map['cfi_range'] = Variable<String>(cfiRange);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    if (!nullToAbsent || scrollOffset != null) {
      map['scroll_offset'] = Variable<double>(scrollOffset);
    }
    map['color'] = Variable<String>(color);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  HighlightsTableCompanion toCompanion(bool nullToAbsent) {
    return HighlightsTableCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      sourceType: Value(sourceType),
      highlightText: Value(highlightText),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      cfiRange: cfiRange == null && nullToAbsent
          ? const Value.absent()
          : Value(cfiRange),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      scrollOffset: scrollOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(scrollOffset),
      color: Value(color),
      createdAt: Value(createdAt),
    );
  }

  factory HighlightsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HighlightsTableData(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      highlightText: serializer.fromJson<String>(json['highlightText']),
      note: serializer.fromJson<String?>(json['note']),
      cfiRange: serializer.fromJson<String?>(json['cfiRange']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      scrollOffset: serializer.fromJson<double?>(json['scrollOffset']),
      color: serializer.fromJson<String>(json['color']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceType': serializer.toJson<String>(sourceType),
      'highlightText': serializer.toJson<String>(highlightText),
      'note': serializer.toJson<String?>(note),
      'cfiRange': serializer.toJson<String?>(cfiRange),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'scrollOffset': serializer.toJson<double?>(scrollOffset),
      'color': serializer.toJson<String>(color),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  HighlightsTableData copyWith({
    String? id,
    String? sourceId,
    String? sourceType,
    String? highlightText,
    Value<String?> note = const Value.absent(),
    Value<String?> cfiRange = const Value.absent(),
    Value<int?> pageNumber = const Value.absent(),
    Value<double?> scrollOffset = const Value.absent(),
    String? color,
    String? createdAt,
  }) => HighlightsTableData(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    sourceType: sourceType ?? this.sourceType,
    highlightText: highlightText ?? this.highlightText,
    note: note.present ? note.value : this.note,
    cfiRange: cfiRange.present ? cfiRange.value : this.cfiRange,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    scrollOffset: scrollOffset.present ? scrollOffset.value : this.scrollOffset,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
  );
  HighlightsTableData copyWithCompanion(HighlightsTableCompanion data) {
    return HighlightsTableData(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      highlightText: data.highlightText.present
          ? data.highlightText.value
          : this.highlightText,
      note: data.note.present ? data.note.value : this.note,
      cfiRange: data.cfiRange.present ? data.cfiRange.value : this.cfiRange,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      scrollOffset: data.scrollOffset.present
          ? data.scrollOffset.value
          : this.scrollOffset,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HighlightsTableData(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceType: $sourceType, ')
          ..write('highlightText: $highlightText, ')
          ..write('note: $note, ')
          ..write('cfiRange: $cfiRange, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    sourceType,
    highlightText,
    note,
    cfiRange,
    pageNumber,
    scrollOffset,
    color,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HighlightsTableData &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.sourceType == this.sourceType &&
          other.highlightText == this.highlightText &&
          other.note == this.note &&
          other.cfiRange == this.cfiRange &&
          other.pageNumber == this.pageNumber &&
          other.scrollOffset == this.scrollOffset &&
          other.color == this.color &&
          other.createdAt == this.createdAt);
}

class HighlightsTableCompanion extends UpdateCompanion<HighlightsTableData> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> sourceType;
  final Value<String> highlightText;
  final Value<String?> note;
  final Value<String?> cfiRange;
  final Value<int?> pageNumber;
  final Value<double?> scrollOffset;
  final Value<String> color;
  final Value<String> createdAt;
  final Value<int> rowid;
  const HighlightsTableCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.highlightText = const Value.absent(),
    this.note = const Value.absent(),
    this.cfiRange = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HighlightsTableCompanion.insert({
    required String id,
    required String sourceId,
    required String sourceType,
    required String highlightText,
    this.note = const Value.absent(),
    this.cfiRange = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.color = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       sourceType = Value(sourceType),
       highlightText = Value(highlightText),
       createdAt = Value(createdAt);
  static Insertable<HighlightsTableData> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? sourceType,
    Expression<String>? highlightText,
    Expression<String>? note,
    Expression<String>? cfiRange,
    Expression<int>? pageNumber,
    Expression<double>? scrollOffset,
    Expression<String>? color,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceType != null) 'source_type': sourceType,
      if (highlightText != null) 'highlight_text': highlightText,
      if (note != null) 'note': note,
      if (cfiRange != null) 'cfi_range': cfiRange,
      if (pageNumber != null) 'page_number': pageNumber,
      if (scrollOffset != null) 'scroll_offset': scrollOffset,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HighlightsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? sourceType,
    Value<String>? highlightText,
    Value<String?>? note,
    Value<String?>? cfiRange,
    Value<int?>? pageNumber,
    Value<double?>? scrollOffset,
    Value<String>? color,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return HighlightsTableCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      highlightText: highlightText ?? this.highlightText,
      note: note ?? this.note,
      cfiRange: cfiRange ?? this.cfiRange,
      pageNumber: pageNumber ?? this.pageNumber,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (highlightText.present) {
      map['highlight_text'] = Variable<String>(highlightText.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (cfiRange.present) {
      map['cfi_range'] = Variable<String>(cfiRange.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (scrollOffset.present) {
      map['scroll_offset'] = Variable<double>(scrollOffset.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HighlightsTableCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceType: $sourceType, ')
          ..write('highlightText: $highlightText, ')
          ..write('note: $note, ')
          ..write('cfiRange: $cfiRange, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTableTable extends FlashcardsTable
    with TableInfo<$FlashcardsTableTable, FlashcardsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frontMeta = const VerificationMeta('front');
  @override
  late final GeneratedColumn<String> front = GeneratedColumn<String>(
    'front',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backMeta = const VerificationMeta('back');
  @override
  late final GeneratedColumn<String> back = GeneratedColumn<String>(
    'back',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hintMeta = const VerificationMeta('hint');
  @override
  late final GeneratedColumn<String> hint = GeneratedColumn<String>(
    'hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceHighlightIdMeta = const VerificationMeta(
    'sourceHighlightId',
  );
  @override
  late final GeneratedColumn<String> sourceHighlightId =
      GeneratedColumn<String>(
        'source_highlight_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _creationSourceMeta = const VerificationMeta(
    'creationSource',
  );
  @override
  late final GeneratedColumn<String> creationSource = GeneratedColumn<String>(
    'creation_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fsrsStateMeta = const VerificationMeta(
    'fsrsState',
  );
  @override
  late final GeneratedColumn<String> fsrsState = GeneratedColumn<String>(
    'fsrs_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _retrievabilityMeta = const VerificationMeta(
    'retrievability',
  );
  @override
  late final GeneratedColumn<double> retrievability = GeneratedColumn<double>(
    'retrievability',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReviewAtMeta = const VerificationMeta(
    'lastReviewAt',
  );
  @override
  late final GeneratedColumn<String> lastReviewAt = GeneratedColumn<String>(
    'last_review_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<String> nextReviewAt = GeneratedColumn<String>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledDaysMeta = const VerificationMeta(
    'scheduledDays',
  );
  @override
  late final GeneratedColumn<int> scheduledDays = GeneratedColumn<int>(
    'scheduled_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _elapsedDaysMeta = const VerificationMeta(
    'elapsedDays',
  );
  @override
  late final GeneratedColumn<int> elapsedDays = GeneratedColumn<int>(
    'elapsed_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    front,
    back,
    hint,
    sourceHighlightId,
    creationSource,
    createdAt,
    fsrsState,
    stability,
    difficulty,
    retrievability,
    reps,
    lapses,
    lastReviewAt,
    nextReviewAt,
    scheduledDays,
    elapsedDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FlashcardsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('front')) {
      context.handle(
        _frontMeta,
        front.isAcceptableOrUnknown(data['front']!, _frontMeta),
      );
    } else if (isInserting) {
      context.missing(_frontMeta);
    }
    if (data.containsKey('back')) {
      context.handle(
        _backMeta,
        back.isAcceptableOrUnknown(data['back']!, _backMeta),
      );
    } else if (isInserting) {
      context.missing(_backMeta);
    }
    if (data.containsKey('hint')) {
      context.handle(
        _hintMeta,
        hint.isAcceptableOrUnknown(data['hint']!, _hintMeta),
      );
    }
    if (data.containsKey('source_highlight_id')) {
      context.handle(
        _sourceHighlightIdMeta,
        sourceHighlightId.isAcceptableOrUnknown(
          data['source_highlight_id']!,
          _sourceHighlightIdMeta,
        ),
      );
    }
    if (data.containsKey('creation_source')) {
      context.handle(
        _creationSourceMeta,
        creationSource.isAcceptableOrUnknown(
          data['creation_source']!,
          _creationSourceMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('fsrs_state')) {
      context.handle(
        _fsrsStateMeta,
        fsrsState.isAcceptableOrUnknown(data['fsrs_state']!, _fsrsStateMeta),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('retrievability')) {
      context.handle(
        _retrievabilityMeta,
        retrievability.isAcceptableOrUnknown(
          data['retrievability']!,
          _retrievabilityMeta,
        ),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('last_review_at')) {
      context.handle(
        _lastReviewAtMeta,
        lastReviewAt.isAcceptableOrUnknown(
          data['last_review_at']!,
          _lastReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
        _scheduledDaysMeta,
        scheduledDays.isAcceptableOrUnknown(
          data['scheduled_days']!,
          _scheduledDaysMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_days')) {
      context.handle(
        _elapsedDaysMeta,
        elapsedDays.isAcceptableOrUnknown(
          data['elapsed_days']!,
          _elapsedDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlashcardsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlashcardsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      front: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}front'],
      )!,
      back: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back'],
      )!,
      hint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hint'],
      ),
      sourceHighlightId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_highlight_id'],
      ),
      creationSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creation_source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      fsrsState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fsrs_state'],
      )!,
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      )!,
      retrievability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}retrievability'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      lastReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_review_at'],
      ),
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_review_at'],
      ),
      scheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_days'],
      )!,
      elapsedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_days'],
      )!,
    );
  }

  @override
  $FlashcardsTableTable createAlias(String alias) {
    return $FlashcardsTableTable(attachedDatabase, alias);
  }
}

class FlashcardsTableData extends DataClass
    implements Insertable<FlashcardsTableData> {
  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? hint;
  final String? sourceHighlightId;
  final String creationSource;
  final String createdAt;
  final String fsrsState;
  final double stability;
  final double difficulty;
  final double retrievability;
  final int reps;
  final int lapses;
  final String? lastReviewAt;
  final String? nextReviewAt;
  final int scheduledDays;
  final int elapsedDays;
  const FlashcardsTableData({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.hint,
    this.sourceHighlightId,
    required this.creationSource,
    required this.createdAt,
    required this.fsrsState,
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.reps,
    required this.lapses,
    this.lastReviewAt,
    this.nextReviewAt,
    required this.scheduledDays,
    required this.elapsedDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['front'] = Variable<String>(front);
    map['back'] = Variable<String>(back);
    if (!nullToAbsent || hint != null) {
      map['hint'] = Variable<String>(hint);
    }
    if (!nullToAbsent || sourceHighlightId != null) {
      map['source_highlight_id'] = Variable<String>(sourceHighlightId);
    }
    map['creation_source'] = Variable<String>(creationSource);
    map['created_at'] = Variable<String>(createdAt);
    map['fsrs_state'] = Variable<String>(fsrsState);
    map['stability'] = Variable<double>(stability);
    map['difficulty'] = Variable<double>(difficulty);
    map['retrievability'] = Variable<double>(retrievability);
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || lastReviewAt != null) {
      map['last_review_at'] = Variable<String>(lastReviewAt);
    }
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<String>(nextReviewAt);
    }
    map['scheduled_days'] = Variable<int>(scheduledDays);
    map['elapsed_days'] = Variable<int>(elapsedDays);
    return map;
  }

  FlashcardsTableCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsTableCompanion(
      id: Value(id),
      deckId: Value(deckId),
      front: Value(front),
      back: Value(back),
      hint: hint == null && nullToAbsent ? const Value.absent() : Value(hint),
      sourceHighlightId: sourceHighlightId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceHighlightId),
      creationSource: Value(creationSource),
      createdAt: Value(createdAt),
      fsrsState: Value(fsrsState),
      stability: Value(stability),
      difficulty: Value(difficulty),
      retrievability: Value(retrievability),
      reps: Value(reps),
      lapses: Value(lapses),
      lastReviewAt: lastReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewAt),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
      scheduledDays: Value(scheduledDays),
      elapsedDays: Value(elapsedDays),
    );
  }

  factory FlashcardsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlashcardsTableData(
      id: serializer.fromJson<String>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      front: serializer.fromJson<String>(json['front']),
      back: serializer.fromJson<String>(json['back']),
      hint: serializer.fromJson<String?>(json['hint']),
      sourceHighlightId: serializer.fromJson<String?>(
        json['sourceHighlightId'],
      ),
      creationSource: serializer.fromJson<String>(json['creationSource']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      fsrsState: serializer.fromJson<String>(json['fsrsState']),
      stability: serializer.fromJson<double>(json['stability']),
      difficulty: serializer.fromJson<double>(json['difficulty']),
      retrievability: serializer.fromJson<double>(json['retrievability']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      lastReviewAt: serializer.fromJson<String?>(json['lastReviewAt']),
      nextReviewAt: serializer.fromJson<String?>(json['nextReviewAt']),
      scheduledDays: serializer.fromJson<int>(json['scheduledDays']),
      elapsedDays: serializer.fromJson<int>(json['elapsedDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deckId': serializer.toJson<String>(deckId),
      'front': serializer.toJson<String>(front),
      'back': serializer.toJson<String>(back),
      'hint': serializer.toJson<String?>(hint),
      'sourceHighlightId': serializer.toJson<String?>(sourceHighlightId),
      'creationSource': serializer.toJson<String>(creationSource),
      'createdAt': serializer.toJson<String>(createdAt),
      'fsrsState': serializer.toJson<String>(fsrsState),
      'stability': serializer.toJson<double>(stability),
      'difficulty': serializer.toJson<double>(difficulty),
      'retrievability': serializer.toJson<double>(retrievability),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'lastReviewAt': serializer.toJson<String?>(lastReviewAt),
      'nextReviewAt': serializer.toJson<String?>(nextReviewAt),
      'scheduledDays': serializer.toJson<int>(scheduledDays),
      'elapsedDays': serializer.toJson<int>(elapsedDays),
    };
  }

  FlashcardsTableData copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    Value<String?> hint = const Value.absent(),
    Value<String?> sourceHighlightId = const Value.absent(),
    String? creationSource,
    String? createdAt,
    String? fsrsState,
    double? stability,
    double? difficulty,
    double? retrievability,
    int? reps,
    int? lapses,
    Value<String?> lastReviewAt = const Value.absent(),
    Value<String?> nextReviewAt = const Value.absent(),
    int? scheduledDays,
    int? elapsedDays,
  }) => FlashcardsTableData(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    front: front ?? this.front,
    back: back ?? this.back,
    hint: hint.present ? hint.value : this.hint,
    sourceHighlightId: sourceHighlightId.present
        ? sourceHighlightId.value
        : this.sourceHighlightId,
    creationSource: creationSource ?? this.creationSource,
    createdAt: createdAt ?? this.createdAt,
    fsrsState: fsrsState ?? this.fsrsState,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    retrievability: retrievability ?? this.retrievability,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastReviewAt: lastReviewAt.present ? lastReviewAt.value : this.lastReviewAt,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
    scheduledDays: scheduledDays ?? this.scheduledDays,
    elapsedDays: elapsedDays ?? this.elapsedDays,
  );
  FlashcardsTableData copyWithCompanion(FlashcardsTableCompanion data) {
    return FlashcardsTableData(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      front: data.front.present ? data.front.value : this.front,
      back: data.back.present ? data.back.value : this.back,
      hint: data.hint.present ? data.hint.value : this.hint,
      sourceHighlightId: data.sourceHighlightId.present
          ? data.sourceHighlightId.value
          : this.sourceHighlightId,
      creationSource: data.creationSource.present
          ? data.creationSource.value
          : this.creationSource,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      fsrsState: data.fsrsState.present ? data.fsrsState.value : this.fsrsState,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      retrievability: data.retrievability.present
          ? data.retrievability.value
          : this.retrievability,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      lastReviewAt: data.lastReviewAt.present
          ? data.lastReviewAt.value
          : this.lastReviewAt,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      elapsedDays: data.elapsedDays.present
          ? data.elapsedDays.value
          : this.elapsedDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsTableData(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('hint: $hint, ')
          ..write('sourceHighlightId: $sourceHighlightId, ')
          ..write('creationSource: $creationSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('fsrsState: $fsrsState, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('retrievability: $retrievability, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReviewAt: $lastReviewAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('elapsedDays: $elapsedDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deckId,
    front,
    back,
    hint,
    sourceHighlightId,
    creationSource,
    createdAt,
    fsrsState,
    stability,
    difficulty,
    retrievability,
    reps,
    lapses,
    lastReviewAt,
    nextReviewAt,
    scheduledDays,
    elapsedDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlashcardsTableData &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.front == this.front &&
          other.back == this.back &&
          other.hint == this.hint &&
          other.sourceHighlightId == this.sourceHighlightId &&
          other.creationSource == this.creationSource &&
          other.createdAt == this.createdAt &&
          other.fsrsState == this.fsrsState &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.retrievability == this.retrievability &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.lastReviewAt == this.lastReviewAt &&
          other.nextReviewAt == this.nextReviewAt &&
          other.scheduledDays == this.scheduledDays &&
          other.elapsedDays == this.elapsedDays);
}

class FlashcardsTableCompanion extends UpdateCompanion<FlashcardsTableData> {
  final Value<String> id;
  final Value<String> deckId;
  final Value<String> front;
  final Value<String> back;
  final Value<String?> hint;
  final Value<String?> sourceHighlightId;
  final Value<String> creationSource;
  final Value<String> createdAt;
  final Value<String> fsrsState;
  final Value<double> stability;
  final Value<double> difficulty;
  final Value<double> retrievability;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<String?> lastReviewAt;
  final Value<String?> nextReviewAt;
  final Value<int> scheduledDays;
  final Value<int> elapsedDays;
  final Value<int> rowid;
  const FlashcardsTableCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.front = const Value.absent(),
    this.back = const Value.absent(),
    this.hint = const Value.absent(),
    this.sourceHighlightId = const Value.absent(),
    this.creationSource = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.fsrsState = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReviewAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FlashcardsTableCompanion.insert({
    required String id,
    required String deckId,
    required String front,
    required String back,
    this.hint = const Value.absent(),
    this.sourceHighlightId = const Value.absent(),
    this.creationSource = const Value.absent(),
    required String createdAt,
    this.fsrsState = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.retrievability = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.lastReviewAt = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deckId = Value(deckId),
       front = Value(front),
       back = Value(back),
       createdAt = Value(createdAt);
  static Insertable<FlashcardsTableData> custom({
    Expression<String>? id,
    Expression<String>? deckId,
    Expression<String>? front,
    Expression<String>? back,
    Expression<String>? hint,
    Expression<String>? sourceHighlightId,
    Expression<String>? creationSource,
    Expression<String>? createdAt,
    Expression<String>? fsrsState,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<double>? retrievability,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<String>? lastReviewAt,
    Expression<String>? nextReviewAt,
    Expression<int>? scheduledDays,
    Expression<int>? elapsedDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (front != null) 'front': front,
      if (back != null) 'back': back,
      if (hint != null) 'hint': hint,
      if (sourceHighlightId != null) 'source_highlight_id': sourceHighlightId,
      if (creationSource != null) 'creation_source': creationSource,
      if (createdAt != null) 'created_at': createdAt,
      if (fsrsState != null) 'fsrs_state': fsrsState,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (retrievability != null) 'retrievability': retrievability,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (lastReviewAt != null) 'last_review_at': lastReviewAt,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (elapsedDays != null) 'elapsed_days': elapsedDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlashcardsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? deckId,
    Value<String>? front,
    Value<String>? back,
    Value<String?>? hint,
    Value<String?>? sourceHighlightId,
    Value<String>? creationSource,
    Value<String>? createdAt,
    Value<String>? fsrsState,
    Value<double>? stability,
    Value<double>? difficulty,
    Value<double>? retrievability,
    Value<int>? reps,
    Value<int>? lapses,
    Value<String?>? lastReviewAt,
    Value<String?>? nextReviewAt,
    Value<int>? scheduledDays,
    Value<int>? elapsedDays,
    Value<int>? rowid,
  }) {
    return FlashcardsTableCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      sourceHighlightId: sourceHighlightId ?? this.sourceHighlightId,
      creationSource: creationSource ?? this.creationSource,
      createdAt: createdAt ?? this.createdAt,
      fsrsState: fsrsState ?? this.fsrsState,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (front.present) {
      map['front'] = Variable<String>(front.value);
    }
    if (back.present) {
      map['back'] = Variable<String>(back.value);
    }
    if (hint.present) {
      map['hint'] = Variable<String>(hint.value);
    }
    if (sourceHighlightId.present) {
      map['source_highlight_id'] = Variable<String>(sourceHighlightId.value);
    }
    if (creationSource.present) {
      map['creation_source'] = Variable<String>(creationSource.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (fsrsState.present) {
      map['fsrs_state'] = Variable<String>(fsrsState.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (retrievability.present) {
      map['retrievability'] = Variable<double>(retrievability.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (lastReviewAt.present) {
      map['last_review_at'] = Variable<String>(lastReviewAt.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<String>(nextReviewAt.value);
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<int>(scheduledDays.value);
    }
    if (elapsedDays.present) {
      map['elapsed_days'] = Variable<int>(elapsedDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsTableCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('front: $front, ')
          ..write('back: $back, ')
          ..write('hint: $hint, ')
          ..write('sourceHighlightId: $sourceHighlightId, ')
          ..write('creationSource: $creationSource, ')
          ..write('createdAt: $createdAt, ')
          ..write('fsrsState: $fsrsState, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('retrievability: $retrievability, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('lastReviewAt: $lastReviewAt, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DictionaryEntriesTableTable extends DictionaryEntriesTable
    with TableInfo<$DictionaryEntriesTableTable, DictionaryEntriesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryEntriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationMeta = const VerificationMeta(
    'translation',
  );
  @override
  late final GeneratedColumn<String> translation = GeneratedColumn<String>(
    'translation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageExamplesMeta = const VerificationMeta(
    'usageExamples',
  );
  @override
  late final GeneratedColumn<String> usageExamples = GeneratedColumn<String>(
    'usage_examples',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<String> addedAt = GeneratedColumn<String>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    translation,
    context,
    sourceId,
    sourceType,
    usageExamples,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_entries_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictionaryEntriesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('translation')) {
      context.handle(
        _translationMeta,
        translation.isAcceptableOrUnknown(
          data['translation']!,
          _translationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translationMeta);
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('usage_examples')) {
      context.handle(
        _usageExamplesMeta,
        usageExamples.isAcceptableOrUnknown(
          data['usage_examples']!,
          _usageExamplesMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictionaryEntriesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryEntriesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      translation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translation'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      ),
      usageExamples: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_examples'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $DictionaryEntriesTableTable createAlias(String alias) {
    return $DictionaryEntriesTableTable(attachedDatabase, alias);
  }
}

class DictionaryEntriesTableData extends DataClass
    implements Insertable<DictionaryEntriesTableData> {
  final String id;
  final String word;
  final String translation;
  final String? context;
  final String? sourceId;
  final String? sourceType;
  final String? usageExamples;
  final String addedAt;
  const DictionaryEntriesTableData({
    required this.id,
    required this.word,
    required this.translation,
    this.context,
    this.sourceId,
    this.sourceType,
    this.usageExamples,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['word'] = Variable<String>(word);
    map['translation'] = Variable<String>(translation);
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<String>(context);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || sourceType != null) {
      map['source_type'] = Variable<String>(sourceType);
    }
    if (!nullToAbsent || usageExamples != null) {
      map['usage_examples'] = Variable<String>(usageExamples);
    }
    map['added_at'] = Variable<String>(addedAt);
    return map;
  }

  DictionaryEntriesTableCompanion toCompanion(bool nullToAbsent) {
    return DictionaryEntriesTableCompanion(
      id: Value(id),
      word: Value(word),
      translation: Value(translation),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      sourceType: sourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceType),
      usageExamples: usageExamples == null && nullToAbsent
          ? const Value.absent()
          : Value(usageExamples),
      addedAt: Value(addedAt),
    );
  }

  factory DictionaryEntriesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryEntriesTableData(
      id: serializer.fromJson<String>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      translation: serializer.fromJson<String>(json['translation']),
      context: serializer.fromJson<String?>(json['context']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      sourceType: serializer.fromJson<String?>(json['sourceType']),
      usageExamples: serializer.fromJson<String?>(json['usageExamples']),
      addedAt: serializer.fromJson<String>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'word': serializer.toJson<String>(word),
      'translation': serializer.toJson<String>(translation),
      'context': serializer.toJson<String?>(context),
      'sourceId': serializer.toJson<String?>(sourceId),
      'sourceType': serializer.toJson<String?>(sourceType),
      'usageExamples': serializer.toJson<String?>(usageExamples),
      'addedAt': serializer.toJson<String>(addedAt),
    };
  }

  DictionaryEntriesTableData copyWith({
    String? id,
    String? word,
    String? translation,
    Value<String?> context = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    Value<String?> sourceType = const Value.absent(),
    Value<String?> usageExamples = const Value.absent(),
    String? addedAt,
  }) => DictionaryEntriesTableData(
    id: id ?? this.id,
    word: word ?? this.word,
    translation: translation ?? this.translation,
    context: context.present ? context.value : this.context,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    sourceType: sourceType.present ? sourceType.value : this.sourceType,
    usageExamples: usageExamples.present
        ? usageExamples.value
        : this.usageExamples,
    addedAt: addedAt ?? this.addedAt,
  );
  DictionaryEntriesTableData copyWithCompanion(
    DictionaryEntriesTableCompanion data,
  ) {
    return DictionaryEntriesTableData(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      translation: data.translation.present
          ? data.translation.value
          : this.translation,
      context: data.context.present ? data.context.value : this.context,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      usageExamples: data.usageExamples.present
          ? data.usageExamples.value
          : this.usageExamples,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryEntriesTableData(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('translation: $translation, ')
          ..write('context: $context, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceType: $sourceType, ')
          ..write('usageExamples: $usageExamples, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    word,
    translation,
    context,
    sourceId,
    sourceType,
    usageExamples,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryEntriesTableData &&
          other.id == this.id &&
          other.word == this.word &&
          other.translation == this.translation &&
          other.context == this.context &&
          other.sourceId == this.sourceId &&
          other.sourceType == this.sourceType &&
          other.usageExamples == this.usageExamples &&
          other.addedAt == this.addedAt);
}

class DictionaryEntriesTableCompanion
    extends UpdateCompanion<DictionaryEntriesTableData> {
  final Value<String> id;
  final Value<String> word;
  final Value<String> translation;
  final Value<String?> context;
  final Value<String?> sourceId;
  final Value<String?> sourceType;
  final Value<String?> usageExamples;
  final Value<String> addedAt;
  final Value<int> rowid;
  const DictionaryEntriesTableCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.translation = const Value.absent(),
    this.context = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.usageExamples = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DictionaryEntriesTableCompanion.insert({
    required String id,
    required String word,
    required String translation,
    this.context = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.usageExamples = const Value.absent(),
    required String addedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       word = Value(word),
       translation = Value(translation),
       addedAt = Value(addedAt);
  static Insertable<DictionaryEntriesTableData> custom({
    Expression<String>? id,
    Expression<String>? word,
    Expression<String>? translation,
    Expression<String>? context,
    Expression<String>? sourceId,
    Expression<String>? sourceType,
    Expression<String>? usageExamples,
    Expression<String>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (translation != null) 'translation': translation,
      if (context != null) 'context': context,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceType != null) 'source_type': sourceType,
      if (usageExamples != null) 'usage_examples': usageExamples,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictionaryEntriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? word,
    Value<String>? translation,
    Value<String?>? context,
    Value<String?>? sourceId,
    Value<String?>? sourceType,
    Value<String?>? usageExamples,
    Value<String>? addedAt,
    Value<int>? rowid,
  }) {
    return DictionaryEntriesTableCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      context: context ?? this.context,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      usageExamples: usageExamples ?? this.usageExamples,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (translation.present) {
      map['translation'] = Variable<String>(translation.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (usageExamples.present) {
      map['usage_examples'] = Variable<String>(usageExamples.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<String>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryEntriesTableCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('translation: $translation, ')
          ..write('context: $context, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceType: $sourceType, ')
          ..write('usageExamples: $usageExamples, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTableTable extends ReviewLogsTable
    with TableInfo<$ReviewLogsTableTable, ReviewLogsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flashcardIdMeta = const VerificationMeta(
    'flashcardId',
  );
  @override
  late final GeneratedColumn<String> flashcardId = GeneratedColumn<String>(
    'flashcard_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateBeforeMeta = const VerificationMeta(
    'stateBefore',
  );
  @override
  late final GeneratedColumn<String> stateBefore = GeneratedColumn<String>(
    'state_before',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stabilityBeforeMeta = const VerificationMeta(
    'stabilityBefore',
  );
  @override
  late final GeneratedColumn<double> stabilityBefore = GeneratedColumn<double>(
    'stability_before',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyBeforeMeta = const VerificationMeta(
    'difficultyBefore',
  );
  @override
  late final GeneratedColumn<double> difficultyBefore = GeneratedColumn<double>(
    'difficulty_before',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retrievabilityAtReviewMeta =
      const VerificationMeta('retrievabilityAtReview');
  @override
  late final GeneratedColumn<double> retrievabilityAtReview =
      GeneratedColumn<double>(
        'retrievability_at_review',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _scheduledDaysMeta = const VerificationMeta(
    'scheduledDays',
  );
  @override
  late final GeneratedColumn<int> scheduledDays = GeneratedColumn<int>(
    'scheduled_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elapsedDaysMeta = const VerificationMeta(
    'elapsedDays',
  );
  @override
  late final GeneratedColumn<int> elapsedDays = GeneratedColumn<int>(
    'elapsed_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewDurationMsMeta = const VerificationMeta(
    'reviewDurationMs',
  );
  @override
  late final GeneratedColumn<int> reviewDurationMs = GeneratedColumn<int>(
    'review_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<String> reviewedAt = GeneratedColumn<String>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    flashcardId,
    rating,
    stateBefore,
    stabilityBefore,
    difficultyBefore,
    retrievabilityAtReview,
    scheduledDays,
    elapsedDays,
    reviewDurationMs,
    reviewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLogsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('flashcard_id')) {
      context.handle(
        _flashcardIdMeta,
        flashcardId.isAcceptableOrUnknown(
          data['flashcard_id']!,
          _flashcardIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_flashcardIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('state_before')) {
      context.handle(
        _stateBeforeMeta,
        stateBefore.isAcceptableOrUnknown(
          data['state_before']!,
          _stateBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stateBeforeMeta);
    }
    if (data.containsKey('stability_before')) {
      context.handle(
        _stabilityBeforeMeta,
        stabilityBefore.isAcceptableOrUnknown(
          data['stability_before']!,
          _stabilityBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stabilityBeforeMeta);
    }
    if (data.containsKey('difficulty_before')) {
      context.handle(
        _difficultyBeforeMeta,
        difficultyBefore.isAcceptableOrUnknown(
          data['difficulty_before']!,
          _difficultyBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_difficultyBeforeMeta);
    }
    if (data.containsKey('retrievability_at_review')) {
      context.handle(
        _retrievabilityAtReviewMeta,
        retrievabilityAtReview.isAcceptableOrUnknown(
          data['retrievability_at_review']!,
          _retrievabilityAtReviewMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_retrievabilityAtReviewMeta);
    }
    if (data.containsKey('scheduled_days')) {
      context.handle(
        _scheduledDaysMeta,
        scheduledDays.isAcceptableOrUnknown(
          data['scheduled_days']!,
          _scheduledDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDaysMeta);
    }
    if (data.containsKey('elapsed_days')) {
      context.handle(
        _elapsedDaysMeta,
        elapsedDays.isAcceptableOrUnknown(
          data['elapsed_days']!,
          _elapsedDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elapsedDaysMeta);
    }
    if (data.containsKey('review_duration_ms')) {
      context.handle(
        _reviewDurationMsMeta,
        reviewDurationMs.isAcceptableOrUnknown(
          data['review_duration_ms']!,
          _reviewDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLogsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      flashcardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flashcard_id'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      )!,
      stateBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_before'],
      )!,
      stabilityBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability_before'],
      )!,
      difficultyBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty_before'],
      )!,
      retrievabilityAtReview: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}retrievability_at_review'],
      )!,
      scheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_days'],
      )!,
      elapsedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_days'],
      )!,
      reviewDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_duration_ms'],
      ),
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_at'],
      )!,
    );
  }

  @override
  $ReviewLogsTableTable createAlias(String alias) {
    return $ReviewLogsTableTable(attachedDatabase, alias);
  }
}

class ReviewLogsTableData extends DataClass
    implements Insertable<ReviewLogsTableData> {
  final String id;
  final String flashcardId;
  final String rating;
  final String stateBefore;
  final double stabilityBefore;
  final double difficultyBefore;
  final double retrievabilityAtReview;
  final int scheduledDays;
  final int elapsedDays;
  final int? reviewDurationMs;
  final String reviewedAt;
  const ReviewLogsTableData({
    required this.id,
    required this.flashcardId,
    required this.rating,
    required this.stateBefore,
    required this.stabilityBefore,
    required this.difficultyBefore,
    required this.retrievabilityAtReview,
    required this.scheduledDays,
    required this.elapsedDays,
    this.reviewDurationMs,
    required this.reviewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['flashcard_id'] = Variable<String>(flashcardId);
    map['rating'] = Variable<String>(rating);
    map['state_before'] = Variable<String>(stateBefore);
    map['stability_before'] = Variable<double>(stabilityBefore);
    map['difficulty_before'] = Variable<double>(difficultyBefore);
    map['retrievability_at_review'] = Variable<double>(retrievabilityAtReview);
    map['scheduled_days'] = Variable<int>(scheduledDays);
    map['elapsed_days'] = Variable<int>(elapsedDays);
    if (!nullToAbsent || reviewDurationMs != null) {
      map['review_duration_ms'] = Variable<int>(reviewDurationMs);
    }
    map['reviewed_at'] = Variable<String>(reviewedAt);
    return map;
  }

  ReviewLogsTableCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsTableCompanion(
      id: Value(id),
      flashcardId: Value(flashcardId),
      rating: Value(rating),
      stateBefore: Value(stateBefore),
      stabilityBefore: Value(stabilityBefore),
      difficultyBefore: Value(difficultyBefore),
      retrievabilityAtReview: Value(retrievabilityAtReview),
      scheduledDays: Value(scheduledDays),
      elapsedDays: Value(elapsedDays),
      reviewDurationMs: reviewDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewDurationMs),
      reviewedAt: Value(reviewedAt),
    );
  }

  factory ReviewLogsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogsTableData(
      id: serializer.fromJson<String>(json['id']),
      flashcardId: serializer.fromJson<String>(json['flashcardId']),
      rating: serializer.fromJson<String>(json['rating']),
      stateBefore: serializer.fromJson<String>(json['stateBefore']),
      stabilityBefore: serializer.fromJson<double>(json['stabilityBefore']),
      difficultyBefore: serializer.fromJson<double>(json['difficultyBefore']),
      retrievabilityAtReview: serializer.fromJson<double>(
        json['retrievabilityAtReview'],
      ),
      scheduledDays: serializer.fromJson<int>(json['scheduledDays']),
      elapsedDays: serializer.fromJson<int>(json['elapsedDays']),
      reviewDurationMs: serializer.fromJson<int?>(json['reviewDurationMs']),
      reviewedAt: serializer.fromJson<String>(json['reviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'flashcardId': serializer.toJson<String>(flashcardId),
      'rating': serializer.toJson<String>(rating),
      'stateBefore': serializer.toJson<String>(stateBefore),
      'stabilityBefore': serializer.toJson<double>(stabilityBefore),
      'difficultyBefore': serializer.toJson<double>(difficultyBefore),
      'retrievabilityAtReview': serializer.toJson<double>(
        retrievabilityAtReview,
      ),
      'scheduledDays': serializer.toJson<int>(scheduledDays),
      'elapsedDays': serializer.toJson<int>(elapsedDays),
      'reviewDurationMs': serializer.toJson<int?>(reviewDurationMs),
      'reviewedAt': serializer.toJson<String>(reviewedAt),
    };
  }

  ReviewLogsTableData copyWith({
    String? id,
    String? flashcardId,
    String? rating,
    String? stateBefore,
    double? stabilityBefore,
    double? difficultyBefore,
    double? retrievabilityAtReview,
    int? scheduledDays,
    int? elapsedDays,
    Value<int?> reviewDurationMs = const Value.absent(),
    String? reviewedAt,
  }) => ReviewLogsTableData(
    id: id ?? this.id,
    flashcardId: flashcardId ?? this.flashcardId,
    rating: rating ?? this.rating,
    stateBefore: stateBefore ?? this.stateBefore,
    stabilityBefore: stabilityBefore ?? this.stabilityBefore,
    difficultyBefore: difficultyBefore ?? this.difficultyBefore,
    retrievabilityAtReview:
        retrievabilityAtReview ?? this.retrievabilityAtReview,
    scheduledDays: scheduledDays ?? this.scheduledDays,
    elapsedDays: elapsedDays ?? this.elapsedDays,
    reviewDurationMs: reviewDurationMs.present
        ? reviewDurationMs.value
        : this.reviewDurationMs,
    reviewedAt: reviewedAt ?? this.reviewedAt,
  );
  ReviewLogsTableData copyWithCompanion(ReviewLogsTableCompanion data) {
    return ReviewLogsTableData(
      id: data.id.present ? data.id.value : this.id,
      flashcardId: data.flashcardId.present
          ? data.flashcardId.value
          : this.flashcardId,
      rating: data.rating.present ? data.rating.value : this.rating,
      stateBefore: data.stateBefore.present
          ? data.stateBefore.value
          : this.stateBefore,
      stabilityBefore: data.stabilityBefore.present
          ? data.stabilityBefore.value
          : this.stabilityBefore,
      difficultyBefore: data.difficultyBefore.present
          ? data.difficultyBefore.value
          : this.difficultyBefore,
      retrievabilityAtReview: data.retrievabilityAtReview.present
          ? data.retrievabilityAtReview.value
          : this.retrievabilityAtReview,
      scheduledDays: data.scheduledDays.present
          ? data.scheduledDays.value
          : this.scheduledDays,
      elapsedDays: data.elapsedDays.present
          ? data.elapsedDays.value
          : this.elapsedDays,
      reviewDurationMs: data.reviewDurationMs.present
          ? data.reviewDurationMs.value
          : this.reviewDurationMs,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsTableData(')
          ..write('id: $id, ')
          ..write('flashcardId: $flashcardId, ')
          ..write('rating: $rating, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stabilityBefore: $stabilityBefore, ')
          ..write('difficultyBefore: $difficultyBefore, ')
          ..write('retrievabilityAtReview: $retrievabilityAtReview, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('reviewDurationMs: $reviewDurationMs, ')
          ..write('reviewedAt: $reviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    flashcardId,
    rating,
    stateBefore,
    stabilityBefore,
    difficultyBefore,
    retrievabilityAtReview,
    scheduledDays,
    elapsedDays,
    reviewDurationMs,
    reviewedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogsTableData &&
          other.id == this.id &&
          other.flashcardId == this.flashcardId &&
          other.rating == this.rating &&
          other.stateBefore == this.stateBefore &&
          other.stabilityBefore == this.stabilityBefore &&
          other.difficultyBefore == this.difficultyBefore &&
          other.retrievabilityAtReview == this.retrievabilityAtReview &&
          other.scheduledDays == this.scheduledDays &&
          other.elapsedDays == this.elapsedDays &&
          other.reviewDurationMs == this.reviewDurationMs &&
          other.reviewedAt == this.reviewedAt);
}

class ReviewLogsTableCompanion extends UpdateCompanion<ReviewLogsTableData> {
  final Value<String> id;
  final Value<String> flashcardId;
  final Value<String> rating;
  final Value<String> stateBefore;
  final Value<double> stabilityBefore;
  final Value<double> difficultyBefore;
  final Value<double> retrievabilityAtReview;
  final Value<int> scheduledDays;
  final Value<int> elapsedDays;
  final Value<int?> reviewDurationMs;
  final Value<String> reviewedAt;
  final Value<int> rowid;
  const ReviewLogsTableCompanion({
    this.id = const Value.absent(),
    this.flashcardId = const Value.absent(),
    this.rating = const Value.absent(),
    this.stateBefore = const Value.absent(),
    this.stabilityBefore = const Value.absent(),
    this.difficultyBefore = const Value.absent(),
    this.retrievabilityAtReview = const Value.absent(),
    this.scheduledDays = const Value.absent(),
    this.elapsedDays = const Value.absent(),
    this.reviewDurationMs = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewLogsTableCompanion.insert({
    required String id,
    required String flashcardId,
    required String rating,
    required String stateBefore,
    required double stabilityBefore,
    required double difficultyBefore,
    required double retrievabilityAtReview,
    required int scheduledDays,
    required int elapsedDays,
    this.reviewDurationMs = const Value.absent(),
    required String reviewedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       flashcardId = Value(flashcardId),
       rating = Value(rating),
       stateBefore = Value(stateBefore),
       stabilityBefore = Value(stabilityBefore),
       difficultyBefore = Value(difficultyBefore),
       retrievabilityAtReview = Value(retrievabilityAtReview),
       scheduledDays = Value(scheduledDays),
       elapsedDays = Value(elapsedDays),
       reviewedAt = Value(reviewedAt);
  static Insertable<ReviewLogsTableData> custom({
    Expression<String>? id,
    Expression<String>? flashcardId,
    Expression<String>? rating,
    Expression<String>? stateBefore,
    Expression<double>? stabilityBefore,
    Expression<double>? difficultyBefore,
    Expression<double>? retrievabilityAtReview,
    Expression<int>? scheduledDays,
    Expression<int>? elapsedDays,
    Expression<int>? reviewDurationMs,
    Expression<String>? reviewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (flashcardId != null) 'flashcard_id': flashcardId,
      if (rating != null) 'rating': rating,
      if (stateBefore != null) 'state_before': stateBefore,
      if (stabilityBefore != null) 'stability_before': stabilityBefore,
      if (difficultyBefore != null) 'difficulty_before': difficultyBefore,
      if (retrievabilityAtReview != null)
        'retrievability_at_review': retrievabilityAtReview,
      if (scheduledDays != null) 'scheduled_days': scheduledDays,
      if (elapsedDays != null) 'elapsed_days': elapsedDays,
      if (reviewDurationMs != null) 'review_duration_ms': reviewDurationMs,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewLogsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? flashcardId,
    Value<String>? rating,
    Value<String>? stateBefore,
    Value<double>? stabilityBefore,
    Value<double>? difficultyBefore,
    Value<double>? retrievabilityAtReview,
    Value<int>? scheduledDays,
    Value<int>? elapsedDays,
    Value<int?>? reviewDurationMs,
    Value<String>? reviewedAt,
    Value<int>? rowid,
  }) {
    return ReviewLogsTableCompanion(
      id: id ?? this.id,
      flashcardId: flashcardId ?? this.flashcardId,
      rating: rating ?? this.rating,
      stateBefore: stateBefore ?? this.stateBefore,
      stabilityBefore: stabilityBefore ?? this.stabilityBefore,
      difficultyBefore: difficultyBefore ?? this.difficultyBefore,
      retrievabilityAtReview:
          retrievabilityAtReview ?? this.retrievabilityAtReview,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      reviewDurationMs: reviewDurationMs ?? this.reviewDurationMs,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (flashcardId.present) {
      map['flashcard_id'] = Variable<String>(flashcardId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (stateBefore.present) {
      map['state_before'] = Variable<String>(stateBefore.value);
    }
    if (stabilityBefore.present) {
      map['stability_before'] = Variable<double>(stabilityBefore.value);
    }
    if (difficultyBefore.present) {
      map['difficulty_before'] = Variable<double>(difficultyBefore.value);
    }
    if (retrievabilityAtReview.present) {
      map['retrievability_at_review'] = Variable<double>(
        retrievabilityAtReview.value,
      );
    }
    if (scheduledDays.present) {
      map['scheduled_days'] = Variable<int>(scheduledDays.value);
    }
    if (elapsedDays.present) {
      map['elapsed_days'] = Variable<int>(elapsedDays.value);
    }
    if (reviewDurationMs.present) {
      map['review_duration_ms'] = Variable<int>(reviewDurationMs.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<String>(reviewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsTableCompanion(')
          ..write('id: $id, ')
          ..write('flashcardId: $flashcardId, ')
          ..write('rating: $rating, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stabilityBefore: $stabilityBefore, ')
          ..write('difficultyBefore: $difficultyBefore, ')
          ..write('retrievabilityAtReview: $retrievabilityAtReview, ')
          ..write('scheduledDays: $scheduledDays, ')
          ..write('elapsedDays: $elapsedDays, ')
          ..write('reviewDurationMs: $reviewDurationMs, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTableTable booksTable = $BooksTableTable(this);
  late final $ArticlesTableTable articlesTable = $ArticlesTableTable(this);
  late final $HighlightsTableTable highlightsTable = $HighlightsTableTable(
    this,
  );
  late final $FlashcardsTableTable flashcardsTable = $FlashcardsTableTable(
    this,
  );
  late final $DictionaryEntriesTableTable dictionaryEntriesTable =
      $DictionaryEntriesTableTable(this);
  late final $ReviewLogsTableTable reviewLogsTable = $ReviewLogsTableTable(
    this,
  );
  late final BooksDao booksDao = BooksDao(this as AppDatabase);
  late final HighlightsDao highlightsDao = HighlightsDao(this as AppDatabase);
  late final FlashcardsDao flashcardsDao = FlashcardsDao(this as AppDatabase);
  late final DictionaryDao dictionaryDao = DictionaryDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    booksTable,
    articlesTable,
    highlightsTable,
    flashcardsTable,
    dictionaryEntriesTable,
    reviewLogsTable,
  ];
}

typedef $$BooksTableTableCreateCompanionBuilder =
    BooksTableCompanion Function({
      required String id,
      required String title,
      Value<String?> author,
      Value<String?> coverImagePath,
      required String format,
      required String filePath,
      Value<int> totalLocations,
      Value<int> currentLocation,
      Value<double> readingProgress,
      required String addedAt,
      Value<String?> lastOpenedAt,
      Value<bool> isFinished,
      Value<int> rowid,
    });
typedef $$BooksTableTableUpdateCompanionBuilder =
    BooksTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> author,
      Value<String?> coverImagePath,
      Value<String> format,
      Value<String> filePath,
      Value<int> totalLocations,
      Value<int> currentLocation,
      Value<double> readingProgress,
      Value<String> addedAt,
      Value<String?> lastOpenedAt,
      Value<bool> isFinished,
      Value<int> rowid,
    });

class $$BooksTableTableFilterComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLocations => $composableBuilder(
    column: $table.totalLocations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentLocation => $composableBuilder(
    column: $table.currentLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get readingProgress => $composableBuilder(
    column: $table.readingProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLocations => $composableBuilder(
    column: $table.totalLocations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentLocation => $composableBuilder(
    column: $table.currentLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get readingProgress => $composableBuilder(
    column: $table.readingProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverImagePath => $composableBuilder(
    column: $table.coverImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get totalLocations => $composableBuilder(
    column: $table.totalLocations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentLocation => $composableBuilder(
    column: $table.currentLocation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get readingProgress => $composableBuilder(
    column: $table.readingProgress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );
}

class $$BooksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTableTable,
          BooksTableData,
          $$BooksTableTableFilterComposer,
          $$BooksTableTableOrderingComposer,
          $$BooksTableTableAnnotationComposer,
          $$BooksTableTableCreateCompanionBuilder,
          $$BooksTableTableUpdateCompanionBuilder,
          (
            BooksTableData,
            BaseReferences<_$AppDatabase, $BooksTableTable, BooksTableData>,
          ),
          BooksTableData,
          PrefetchHooks Function()
        > {
  $$BooksTableTableTableManager(_$AppDatabase db, $BooksTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> coverImagePath = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> totalLocations = const Value.absent(),
                Value<int> currentLocation = const Value.absent(),
                Value<double> readingProgress = const Value.absent(),
                Value<String> addedAt = const Value.absent(),
                Value<String?> lastOpenedAt = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksTableCompanion(
                id: id,
                title: title,
                author: author,
                coverImagePath: coverImagePath,
                format: format,
                filePath: filePath,
                totalLocations: totalLocations,
                currentLocation: currentLocation,
                readingProgress: readingProgress,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                isFinished: isFinished,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> coverImagePath = const Value.absent(),
                required String format,
                required String filePath,
                Value<int> totalLocations = const Value.absent(),
                Value<int> currentLocation = const Value.absent(),
                Value<double> readingProgress = const Value.absent(),
                required String addedAt,
                Value<String?> lastOpenedAt = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksTableCompanion.insert(
                id: id,
                title: title,
                author: author,
                coverImagePath: coverImagePath,
                format: format,
                filePath: filePath,
                totalLocations: totalLocations,
                currentLocation: currentLocation,
                readingProgress: readingProgress,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                isFinished: isFinished,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTableTable,
      BooksTableData,
      $$BooksTableTableFilterComposer,
      $$BooksTableTableOrderingComposer,
      $$BooksTableTableAnnotationComposer,
      $$BooksTableTableCreateCompanionBuilder,
      $$BooksTableTableUpdateCompanionBuilder,
      (
        BooksTableData,
        BaseReferences<_$AppDatabase, $BooksTableTable, BooksTableData>,
      ),
      BooksTableData,
      PrefetchHooks Function()
    >;
typedef $$ArticlesTableTableCreateCompanionBuilder =
    ArticlesTableCompanion Function({
      required String id,
      required String title,
      Value<String?> siteName,
      required String url,
      required String cleanedHtml,
      Value<String?> coverImageUrl,
      Value<int> estimatedWordCount,
      Value<double> currentScrollOffset,
      required String addedAt,
      Value<String?> lastOpenedAt,
      Value<bool> isFinished,
      Value<int> rowid,
    });
typedef $$ArticlesTableTableUpdateCompanionBuilder =
    ArticlesTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> siteName,
      Value<String> url,
      Value<String> cleanedHtml,
      Value<String?> coverImageUrl,
      Value<int> estimatedWordCount,
      Value<double> currentScrollOffset,
      Value<String> addedAt,
      Value<String?> lastOpenedAt,
      Value<bool> isFinished,
      Value<int> rowid,
    });

class $$ArticlesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesTableTable> {
  $$ArticlesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanedHtml => $composableBuilder(
    column: $table.cleanedHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedWordCount => $composableBuilder(
    column: $table.estimatedWordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentScrollOffset => $composableBuilder(
    column: $table.currentScrollOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArticlesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesTableTable> {
  $$ArticlesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanedHtml => $composableBuilder(
    column: $table.cleanedHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedWordCount => $composableBuilder(
    column: $table.estimatedWordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentScrollOffset => $composableBuilder(
    column: $table.currentScrollOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArticlesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesTableTable> {
  $$ArticlesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get siteName =>
      $composableBuilder(column: $table.siteName, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get cleanedHtml => $composableBuilder(
    column: $table.cleanedHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedWordCount => $composableBuilder(
    column: $table.estimatedWordCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentScrollOffset => $composableBuilder(
    column: $table.currentScrollOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );
}

class $$ArticlesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticlesTableTable,
          ArticlesTableData,
          $$ArticlesTableTableFilterComposer,
          $$ArticlesTableTableOrderingComposer,
          $$ArticlesTableTableAnnotationComposer,
          $$ArticlesTableTableCreateCompanionBuilder,
          $$ArticlesTableTableUpdateCompanionBuilder,
          (
            ArticlesTableData,
            BaseReferences<
              _$AppDatabase,
              $ArticlesTableTable,
              ArticlesTableData
            >,
          ),
          ArticlesTableData,
          PrefetchHooks Function()
        > {
  $$ArticlesTableTableTableManager(_$AppDatabase db, $ArticlesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> siteName = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> cleanedHtml = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<int> estimatedWordCount = const Value.absent(),
                Value<double> currentScrollOffset = const Value.absent(),
                Value<String> addedAt = const Value.absent(),
                Value<String?> lastOpenedAt = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesTableCompanion(
                id: id,
                title: title,
                siteName: siteName,
                url: url,
                cleanedHtml: cleanedHtml,
                coverImageUrl: coverImageUrl,
                estimatedWordCount: estimatedWordCount,
                currentScrollOffset: currentScrollOffset,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                isFinished: isFinished,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> siteName = const Value.absent(),
                required String url,
                required String cleanedHtml,
                Value<String?> coverImageUrl = const Value.absent(),
                Value<int> estimatedWordCount = const Value.absent(),
                Value<double> currentScrollOffset = const Value.absent(),
                required String addedAt,
                Value<String?> lastOpenedAt = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesTableCompanion.insert(
                id: id,
                title: title,
                siteName: siteName,
                url: url,
                cleanedHtml: cleanedHtml,
                coverImageUrl: coverImageUrl,
                estimatedWordCount: estimatedWordCount,
                currentScrollOffset: currentScrollOffset,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                isFinished: isFinished,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArticlesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticlesTableTable,
      ArticlesTableData,
      $$ArticlesTableTableFilterComposer,
      $$ArticlesTableTableOrderingComposer,
      $$ArticlesTableTableAnnotationComposer,
      $$ArticlesTableTableCreateCompanionBuilder,
      $$ArticlesTableTableUpdateCompanionBuilder,
      (
        ArticlesTableData,
        BaseReferences<_$AppDatabase, $ArticlesTableTable, ArticlesTableData>,
      ),
      ArticlesTableData,
      PrefetchHooks Function()
    >;
typedef $$HighlightsTableTableCreateCompanionBuilder =
    HighlightsTableCompanion Function({
      required String id,
      required String sourceId,
      required String sourceType,
      required String highlightText,
      Value<String?> note,
      Value<String?> cfiRange,
      Value<int?> pageNumber,
      Value<double?> scrollOffset,
      Value<String> color,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$HighlightsTableTableUpdateCompanionBuilder =
    HighlightsTableCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> sourceType,
      Value<String> highlightText,
      Value<String?> note,
      Value<String?> cfiRange,
      Value<int?> pageNumber,
      Value<double?> scrollOffset,
      Value<String> color,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$HighlightsTableTableFilterComposer
    extends Composer<_$AppDatabase, $HighlightsTableTable> {
  $$HighlightsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightText => $composableBuilder(
    column: $table.highlightText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cfiRange => $composableBuilder(
    column: $table.cfiRange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HighlightsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HighlightsTableTable> {
  $$HighlightsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightText => $composableBuilder(
    column: $table.highlightText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cfiRange => $composableBuilder(
    column: $table.cfiRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HighlightsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HighlightsTableTable> {
  $$HighlightsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highlightText => $composableBuilder(
    column: $table.highlightText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get cfiRange =>
      $composableBuilder(column: $table.cfiRange, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HighlightsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HighlightsTableTable,
          HighlightsTableData,
          $$HighlightsTableTableFilterComposer,
          $$HighlightsTableTableOrderingComposer,
          $$HighlightsTableTableAnnotationComposer,
          $$HighlightsTableTableCreateCompanionBuilder,
          $$HighlightsTableTableUpdateCompanionBuilder,
          (
            HighlightsTableData,
            BaseReferences<
              _$AppDatabase,
              $HighlightsTableTable,
              HighlightsTableData
            >,
          ),
          HighlightsTableData,
          PrefetchHooks Function()
        > {
  $$HighlightsTableTableTableManager(
    _$AppDatabase db,
    $HighlightsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HighlightsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HighlightsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HighlightsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> highlightText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> cfiRange = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HighlightsTableCompanion(
                id: id,
                sourceId: sourceId,
                sourceType: sourceType,
                highlightText: highlightText,
                note: note,
                cfiRange: cfiRange,
                pageNumber: pageNumber,
                scrollOffset: scrollOffset,
                color: color,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String sourceType,
                required String highlightText,
                Value<String?> note = const Value.absent(),
                Value<String?> cfiRange = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<String> color = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => HighlightsTableCompanion.insert(
                id: id,
                sourceId: sourceId,
                sourceType: sourceType,
                highlightText: highlightText,
                note: note,
                cfiRange: cfiRange,
                pageNumber: pageNumber,
                scrollOffset: scrollOffset,
                color: color,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HighlightsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HighlightsTableTable,
      HighlightsTableData,
      $$HighlightsTableTableFilterComposer,
      $$HighlightsTableTableOrderingComposer,
      $$HighlightsTableTableAnnotationComposer,
      $$HighlightsTableTableCreateCompanionBuilder,
      $$HighlightsTableTableUpdateCompanionBuilder,
      (
        HighlightsTableData,
        BaseReferences<
          _$AppDatabase,
          $HighlightsTableTable,
          HighlightsTableData
        >,
      ),
      HighlightsTableData,
      PrefetchHooks Function()
    >;
typedef $$FlashcardsTableTableCreateCompanionBuilder =
    FlashcardsTableCompanion Function({
      required String id,
      required String deckId,
      required String front,
      required String back,
      Value<String?> hint,
      Value<String?> sourceHighlightId,
      Value<String> creationSource,
      required String createdAt,
      Value<String> fsrsState,
      Value<double> stability,
      Value<double> difficulty,
      Value<double> retrievability,
      Value<int> reps,
      Value<int> lapses,
      Value<String?> lastReviewAt,
      Value<String?> nextReviewAt,
      Value<int> scheduledDays,
      Value<int> elapsedDays,
      Value<int> rowid,
    });
typedef $$FlashcardsTableTableUpdateCompanionBuilder =
    FlashcardsTableCompanion Function({
      Value<String> id,
      Value<String> deckId,
      Value<String> front,
      Value<String> back,
      Value<String?> hint,
      Value<String?> sourceHighlightId,
      Value<String> creationSource,
      Value<String> createdAt,
      Value<String> fsrsState,
      Value<double> stability,
      Value<double> difficulty,
      Value<double> retrievability,
      Value<int> reps,
      Value<int> lapses,
      Value<String?> lastReviewAt,
      Value<String?> nextReviewAt,
      Value<int> scheduledDays,
      Value<int> elapsedDays,
      Value<int> rowid,
    });

class $$FlashcardsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FlashcardsTableTable> {
  $$FlashcardsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hint => $composableBuilder(
    column: $table.hint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHighlightId => $composableBuilder(
    column: $table.sourceHighlightId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creationSource => $composableBuilder(
    column: $table.creationSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fsrsState => $composableBuilder(
    column: $table.fsrsState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retrievability => $composableBuilder(
    column: $table.retrievability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FlashcardsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FlashcardsTableTable> {
  $$FlashcardsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get front => $composableBuilder(
    column: $table.front,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get back => $composableBuilder(
    column: $table.back,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hint => $composableBuilder(
    column: $table.hint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHighlightId => $composableBuilder(
    column: $table.sourceHighlightId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creationSource => $composableBuilder(
    column: $table.creationSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fsrsState => $composableBuilder(
    column: $table.fsrsState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retrievability => $composableBuilder(
    column: $table.retrievability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FlashcardsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlashcardsTableTable> {
  $$FlashcardsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<String> get front =>
      $composableBuilder(column: $table.front, builder: (column) => column);

  GeneratedColumn<String> get back =>
      $composableBuilder(column: $table.back, builder: (column) => column);

  GeneratedColumn<String> get hint =>
      $composableBuilder(column: $table.hint, builder: (column) => column);

  GeneratedColumn<String> get sourceHighlightId => $composableBuilder(
    column: $table.sourceHighlightId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creationSource => $composableBuilder(
    column: $table.creationSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get fsrsState =>
      $composableBuilder(column: $table.fsrsState, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get retrievability => $composableBuilder(
    column: $table.retrievability,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<String> get lastReviewAt => $composableBuilder(
    column: $table.lastReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => column,
  );
}

class $$FlashcardsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlashcardsTableTable,
          FlashcardsTableData,
          $$FlashcardsTableTableFilterComposer,
          $$FlashcardsTableTableOrderingComposer,
          $$FlashcardsTableTableAnnotationComposer,
          $$FlashcardsTableTableCreateCompanionBuilder,
          $$FlashcardsTableTableUpdateCompanionBuilder,
          (
            FlashcardsTableData,
            BaseReferences<
              _$AppDatabase,
              $FlashcardsTableTable,
              FlashcardsTableData
            >,
          ),
          FlashcardsTableData,
          PrefetchHooks Function()
        > {
  $$FlashcardsTableTableTableManager(
    _$AppDatabase db,
    $FlashcardsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<String> front = const Value.absent(),
                Value<String> back = const Value.absent(),
                Value<String?> hint = const Value.absent(),
                Value<String?> sourceHighlightId = const Value.absent(),
                Value<String> creationSource = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> fsrsState = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> retrievability = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String?> lastReviewAt = const Value.absent(),
                Value<String?> nextReviewAt = const Value.absent(),
                Value<int> scheduledDays = const Value.absent(),
                Value<int> elapsedDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlashcardsTableCompanion(
                id: id,
                deckId: deckId,
                front: front,
                back: back,
                hint: hint,
                sourceHighlightId: sourceHighlightId,
                creationSource: creationSource,
                createdAt: createdAt,
                fsrsState: fsrsState,
                stability: stability,
                difficulty: difficulty,
                retrievability: retrievability,
                reps: reps,
                lapses: lapses,
                lastReviewAt: lastReviewAt,
                nextReviewAt: nextReviewAt,
                scheduledDays: scheduledDays,
                elapsedDays: elapsedDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deckId,
                required String front,
                required String back,
                Value<String?> hint = const Value.absent(),
                Value<String?> sourceHighlightId = const Value.absent(),
                Value<String> creationSource = const Value.absent(),
                required String createdAt,
                Value<String> fsrsState = const Value.absent(),
                Value<double> stability = const Value.absent(),
                Value<double> difficulty = const Value.absent(),
                Value<double> retrievability = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<String?> lastReviewAt = const Value.absent(),
                Value<String?> nextReviewAt = const Value.absent(),
                Value<int> scheduledDays = const Value.absent(),
                Value<int> elapsedDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FlashcardsTableCompanion.insert(
                id: id,
                deckId: deckId,
                front: front,
                back: back,
                hint: hint,
                sourceHighlightId: sourceHighlightId,
                creationSource: creationSource,
                createdAt: createdAt,
                fsrsState: fsrsState,
                stability: stability,
                difficulty: difficulty,
                retrievability: retrievability,
                reps: reps,
                lapses: lapses,
                lastReviewAt: lastReviewAt,
                nextReviewAt: nextReviewAt,
                scheduledDays: scheduledDays,
                elapsedDays: elapsedDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FlashcardsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlashcardsTableTable,
      FlashcardsTableData,
      $$FlashcardsTableTableFilterComposer,
      $$FlashcardsTableTableOrderingComposer,
      $$FlashcardsTableTableAnnotationComposer,
      $$FlashcardsTableTableCreateCompanionBuilder,
      $$FlashcardsTableTableUpdateCompanionBuilder,
      (
        FlashcardsTableData,
        BaseReferences<
          _$AppDatabase,
          $FlashcardsTableTable,
          FlashcardsTableData
        >,
      ),
      FlashcardsTableData,
      PrefetchHooks Function()
    >;
typedef $$DictionaryEntriesTableTableCreateCompanionBuilder =
    DictionaryEntriesTableCompanion Function({
      required String id,
      required String word,
      required String translation,
      Value<String?> context,
      Value<String?> sourceId,
      Value<String?> sourceType,
      Value<String?> usageExamples,
      required String addedAt,
      Value<int> rowid,
    });
typedef $$DictionaryEntriesTableTableUpdateCompanionBuilder =
    DictionaryEntriesTableCompanion Function({
      Value<String> id,
      Value<String> word,
      Value<String> translation,
      Value<String?> context,
      Value<String?> sourceId,
      Value<String?> sourceType,
      Value<String?> usageExamples,
      Value<String> addedAt,
      Value<int> rowid,
    });

class $$DictionaryEntriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTableTable> {
  $$DictionaryEntriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageExamples => $composableBuilder(
    column: $table.usageExamples,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DictionaryEntriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTableTable> {
  $$DictionaryEntriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageExamples => $composableBuilder(
    column: $table.usageExamples,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DictionaryEntriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTableTable> {
  $$DictionaryEntriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get translation => $composableBuilder(
    column: $table.translation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usageExamples => $composableBuilder(
    column: $table.usageExamples,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$DictionaryEntriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DictionaryEntriesTableTable,
          DictionaryEntriesTableData,
          $$DictionaryEntriesTableTableFilterComposer,
          $$DictionaryEntriesTableTableOrderingComposer,
          $$DictionaryEntriesTableTableAnnotationComposer,
          $$DictionaryEntriesTableTableCreateCompanionBuilder,
          $$DictionaryEntriesTableTableUpdateCompanionBuilder,
          (
            DictionaryEntriesTableData,
            BaseReferences<
              _$AppDatabase,
              $DictionaryEntriesTableTable,
              DictionaryEntriesTableData
            >,
          ),
          DictionaryEntriesTableData,
          PrefetchHooks Function()
        > {
  $$DictionaryEntriesTableTableTableManager(
    _$AppDatabase db,
    $DictionaryEntriesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryEntriesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DictionaryEntriesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DictionaryEntriesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String> translation = const Value.absent(),
                Value<String?> context = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> usageExamples = const Value.absent(),
                Value<String> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictionaryEntriesTableCompanion(
                id: id,
                word: word,
                translation: translation,
                context: context,
                sourceId: sourceId,
                sourceType: sourceType,
                usageExamples: usageExamples,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String word,
                required String translation,
                Value<String?> context = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> usageExamples = const Value.absent(),
                required String addedAt,
                Value<int> rowid = const Value.absent(),
              }) => DictionaryEntriesTableCompanion.insert(
                id: id,
                word: word,
                translation: translation,
                context: context,
                sourceId: sourceId,
                sourceType: sourceType,
                usageExamples: usageExamples,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DictionaryEntriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DictionaryEntriesTableTable,
      DictionaryEntriesTableData,
      $$DictionaryEntriesTableTableFilterComposer,
      $$DictionaryEntriesTableTableOrderingComposer,
      $$DictionaryEntriesTableTableAnnotationComposer,
      $$DictionaryEntriesTableTableCreateCompanionBuilder,
      $$DictionaryEntriesTableTableUpdateCompanionBuilder,
      (
        DictionaryEntriesTableData,
        BaseReferences<
          _$AppDatabase,
          $DictionaryEntriesTableTable,
          DictionaryEntriesTableData
        >,
      ),
      DictionaryEntriesTableData,
      PrefetchHooks Function()
    >;
typedef $$ReviewLogsTableTableCreateCompanionBuilder =
    ReviewLogsTableCompanion Function({
      required String id,
      required String flashcardId,
      required String rating,
      required String stateBefore,
      required double stabilityBefore,
      required double difficultyBefore,
      required double retrievabilityAtReview,
      required int scheduledDays,
      required int elapsedDays,
      Value<int?> reviewDurationMs,
      required String reviewedAt,
      Value<int> rowid,
    });
typedef $$ReviewLogsTableTableUpdateCompanionBuilder =
    ReviewLogsTableCompanion Function({
      Value<String> id,
      Value<String> flashcardId,
      Value<String> rating,
      Value<String> stateBefore,
      Value<double> stabilityBefore,
      Value<double> difficultyBefore,
      Value<double> retrievabilityAtReview,
      Value<int> scheduledDays,
      Value<int> elapsedDays,
      Value<int?> reviewDurationMs,
      Value<String> reviewedAt,
      Value<int> rowid,
    });

class $$ReviewLogsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewLogsTableTable> {
  $$ReviewLogsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flashcardId => $composableBuilder(
    column: $table.flashcardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retrievabilityAtReview => $composableBuilder(
    column: $table.retrievabilityAtReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewDurationMs => $composableBuilder(
    column: $table.reviewDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReviewLogsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewLogsTableTable> {
  $$ReviewLogsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flashcardId => $composableBuilder(
    column: $table.flashcardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retrievabilityAtReview => $composableBuilder(
    column: $table.retrievabilityAtReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewDurationMs => $composableBuilder(
    column: $table.reviewDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewLogsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewLogsTableTable> {
  $$ReviewLogsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get flashcardId => $composableBuilder(
    column: $table.flashcardId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stabilityBefore => $composableBuilder(
    column: $table.stabilityBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difficultyBefore => $composableBuilder(
    column: $table.difficultyBefore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get retrievabilityAtReview => $composableBuilder(
    column: $table.retrievabilityAtReview,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledDays => $composableBuilder(
    column: $table.scheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedDays => $composableBuilder(
    column: $table.elapsedDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reviewDurationMs => $composableBuilder(
    column: $table.reviewDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );
}

class $$ReviewLogsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReviewLogsTableTable,
          ReviewLogsTableData,
          $$ReviewLogsTableTableFilterComposer,
          $$ReviewLogsTableTableOrderingComposer,
          $$ReviewLogsTableTableAnnotationComposer,
          $$ReviewLogsTableTableCreateCompanionBuilder,
          $$ReviewLogsTableTableUpdateCompanionBuilder,
          (
            ReviewLogsTableData,
            BaseReferences<
              _$AppDatabase,
              $ReviewLogsTableTable,
              ReviewLogsTableData
            >,
          ),
          ReviewLogsTableData,
          PrefetchHooks Function()
        > {
  $$ReviewLogsTableTableTableManager(
    _$AppDatabase db,
    $ReviewLogsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> flashcardId = const Value.absent(),
                Value<String> rating = const Value.absent(),
                Value<String> stateBefore = const Value.absent(),
                Value<double> stabilityBefore = const Value.absent(),
                Value<double> difficultyBefore = const Value.absent(),
                Value<double> retrievabilityAtReview = const Value.absent(),
                Value<int> scheduledDays = const Value.absent(),
                Value<int> elapsedDays = const Value.absent(),
                Value<int?> reviewDurationMs = const Value.absent(),
                Value<String> reviewedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsTableCompanion(
                id: id,
                flashcardId: flashcardId,
                rating: rating,
                stateBefore: stateBefore,
                stabilityBefore: stabilityBefore,
                difficultyBefore: difficultyBefore,
                retrievabilityAtReview: retrievabilityAtReview,
                scheduledDays: scheduledDays,
                elapsedDays: elapsedDays,
                reviewDurationMs: reviewDurationMs,
                reviewedAt: reviewedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String flashcardId,
                required String rating,
                required String stateBefore,
                required double stabilityBefore,
                required double difficultyBefore,
                required double retrievabilityAtReview,
                required int scheduledDays,
                required int elapsedDays,
                Value<int?> reviewDurationMs = const Value.absent(),
                required String reviewedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsTableCompanion.insert(
                id: id,
                flashcardId: flashcardId,
                rating: rating,
                stateBefore: stateBefore,
                stabilityBefore: stabilityBefore,
                difficultyBefore: difficultyBefore,
                retrievabilityAtReview: retrievabilityAtReview,
                scheduledDays: scheduledDays,
                elapsedDays: elapsedDays,
                reviewDurationMs: reviewDurationMs,
                reviewedAt: reviewedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReviewLogsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReviewLogsTableTable,
      ReviewLogsTableData,
      $$ReviewLogsTableTableFilterComposer,
      $$ReviewLogsTableTableOrderingComposer,
      $$ReviewLogsTableTableAnnotationComposer,
      $$ReviewLogsTableTableCreateCompanionBuilder,
      $$ReviewLogsTableTableUpdateCompanionBuilder,
      (
        ReviewLogsTableData,
        BaseReferences<
          _$AppDatabase,
          $ReviewLogsTableTable,
          ReviewLogsTableData
        >,
      ),
      ReviewLogsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db, _db.booksTable);
  $$ArticlesTableTableTableManager get articlesTable =>
      $$ArticlesTableTableTableManager(_db, _db.articlesTable);
  $$HighlightsTableTableTableManager get highlightsTable =>
      $$HighlightsTableTableTableManager(_db, _db.highlightsTable);
  $$FlashcardsTableTableTableManager get flashcardsTable =>
      $$FlashcardsTableTableTableManager(_db, _db.flashcardsTable);
  $$DictionaryEntriesTableTableTableManager get dictionaryEntriesTable =>
      $$DictionaryEntriesTableTableTableManager(
        _db,
        _db.dictionaryEntriesTable,
      );
  $$ReviewLogsTableTableTableManager get reviewLogsTable =>
      $$ReviewLogsTableTableTableManager(_db, _db.reviewLogsTable);
}
