import 'package:domain_models/domain_models.dart';

abstract class ArticleExtractionService {
  Future<ExtractedArticle> extract(String url);

  /// Default no-op so stateless implementations do not need boilerplate.
  void dispose() {}
}

class ArticleExtractionException implements Exception {
  const ArticleExtractionException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode;
    return code == null
        ? 'ArticleExtractionException: $message'
        : 'ArticleExtractionException($code): $message';
  }
}
