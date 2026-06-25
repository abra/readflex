import 'package:domain_models/domain_models.dart';

abstract class ArticleExtractionService {
  Future<ExtractedArticle> extract(String url);

  /// Default no-op so stateless implementations do not need boilerplate.
  void dispose() {}
}

class ArticleExtractionException implements Exception {
  const ArticleExtractionException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;

  @override
  String toString() {
    final code = statusCode;
    final cleanerCode = errorCode;
    final prefix = code == null
        ? 'ArticleExtractionException'
        : 'ArticleExtractionException($code)';
    if (cleanerCode == null || cleanerCode.isEmpty) {
      return '$prefix: $message';
    }
    return '$prefix[$cleanerCode]: $message';
  }
}
