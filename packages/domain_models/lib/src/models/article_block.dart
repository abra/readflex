import 'dart:convert';

import 'package:equatable/equatable.dart' show Equatable;

/// Structured content block returned by the article extraction service.
///
/// Unknown block types are preserved as [ArticleUnknownBlock] so newer backend
/// output can still be stored and rendered as fallback text instead of crashing
/// older app builds.
sealed class ArticleBlock extends Equatable {
  const ArticleBlock({required this.type});

  final String type;

  Map<String, Object?> toJson();

  String get fallbackText => '';

  static ArticleBlock fromJson(Object? value) {
    final map = _stringKeyMap(value);
    if (map == null) return const ArticleUnknownBlock(type: 'unknown');

    final type = _string(map['type']) ?? 'unknown';
    return switch (type) {
      'paragraph' => ArticleParagraphBlock(text: _string(map['text']) ?? ''),
      'heading' => ArticleHeadingBlock(
        level: _headingLevel(map['level']),
        text: _string(map['text']) ?? '',
      ),
      'image' => ArticleImageBlock(
        src: _string(map['src']) ?? '',
        alt: _string(map['alt']),
        title: _string(map['title']),
      ),
      'list' => ArticleListBlock(items: _stringList(map['items'])),
      'quote' => ArticleQuoteBlock(text: _string(map['text']) ?? ''),
      'code' => ArticleCodeBlock(text: _string(map['text']) ?? ''),
      'table' => ArticleTableBlock(rows: _tableRows(map['rows'])),
      _ => ArticleUnknownBlock(
        type: type,
        text: _string(map['text']),
        rawJson: jsonEncode(map),
      ),
    };
  }
}

final class ArticleParagraphBlock extends ArticleBlock {
  const ArticleParagraphBlock({required this.text}) : super(type: 'paragraph');

  final String text;

  @override
  String get fallbackText => text;

  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text};

  @override
  List<Object?> get props => [type, text];
}

final class ArticleHeadingBlock extends ArticleBlock {
  const ArticleHeadingBlock({required this.level, required this.text})
    : super(type: 'heading');

  final int level;
  final String text;

  @override
  String get fallbackText => text;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'level': level,
    'text': text,
  };

  @override
  List<Object?> get props => [type, level, text];
}

final class ArticleImageBlock extends ArticleBlock {
  const ArticleImageBlock({required this.src, this.alt, this.title})
    : super(type: 'image');

  final String src;
  final String? alt;
  final String? title;

  @override
  String get fallbackText => alt ?? title ?? '';

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'src': src,
    'alt': alt,
    'title': title,
  };

  @override
  List<Object?> get props => [type, src, alt, title];
}

final class ArticleListBlock extends ArticleBlock {
  const ArticleListBlock({required this.items}) : super(type: 'list');

  final List<String> items;

  @override
  String get fallbackText => items.join('\n');

  @override
  Map<String, Object?> toJson() => {'type': type, 'items': items};

  @override
  List<Object?> get props => [type, items];
}

final class ArticleQuoteBlock extends ArticleBlock {
  const ArticleQuoteBlock({required this.text}) : super(type: 'quote');

  final String text;

  @override
  String get fallbackText => text;

  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text};

  @override
  List<Object?> get props => [type, text];
}

final class ArticleCodeBlock extends ArticleBlock {
  const ArticleCodeBlock({required this.text}) : super(type: 'code');

  final String text;

  @override
  String get fallbackText => text;

  @override
  Map<String, Object?> toJson() => {'type': type, 'text': text};

  @override
  List<Object?> get props => [type, text];
}

final class ArticleTableBlock extends ArticleBlock {
  const ArticleTableBlock({required this.rows}) : super(type: 'table');

  final List<List<String>> rows;

  @override
  String get fallbackText => rows.map((row) => row.join('\t')).join('\n');

  @override
  Map<String, Object?> toJson() => {'type': type, 'rows': rows};

  @override
  List<Object?> get props => [type, rows];
}

final class ArticleUnknownBlock extends ArticleBlock {
  const ArticleUnknownBlock({
    required super.type,
    this.text,
    this.rawJson,
  });

  final String? text;
  final String? rawJson;

  @override
  String get fallbackText => text ?? '';

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    if (text != null) 'text': text,
  };

  @override
  List<Object?> get props => [type, text, rawJson];
}

Map<String, Object?>? _stringKeyMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) result[key] = entry.value as Object?;
  }
  return result;
}

String? _string(Object? value) => value is String ? value : null;

int _headingLevel(Object? value) {
  final raw = value is num ? value.toInt() : 2;
  return raw.clamp(1, 6);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null) item.toString(),
  ];
}

List<List<String>> _tableRows(Object? value) {
  if (value is! List) return const [];
  return [
    for (final row in value)
      if (row is List)
        [
          for (final cell in row)
            if (cell != null) cell.toString(),
        ],
  ];
}
