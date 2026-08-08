enum DictionaryLookupFailureReason { network, http, invalidResponse }

class DictionaryLookupException implements Exception {
  const DictionaryLookupException(
    this.reason,
    this.message, {
    this.statusCode,
    this.cause,
  });

  final DictionaryLookupFailureReason reason;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
