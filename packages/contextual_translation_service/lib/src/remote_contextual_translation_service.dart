import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'contextual_translation_errors.dart';
import 'contextual_translation_models.dart';
import 'contextual_translation_service.dart';

class RemoteContextualTranslationService
    implements ContextualTranslationService {
  RemoteContextualTranslationService({
    required Uri baseUri,
    http.Client? httpClient,
    String? apiKey,
    Duration timeout = const Duration(seconds: 45),
  }) : _baseUri = baseUri,
       _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _apiKey = apiKey,
       _timeout = timeout;

  final Uri _baseUri;
  final http.Client _httpClient;
  final bool _ownsClient;
  final String? _apiKey;
  final Duration _timeout;

  @override
  Future<ContextualTranslationResult> translate(
    ContextualTranslationRequest request, {
    bool allowOfflineModelDownload = false,
  }) async {
    final uri = _baseUri.resolve('/v1/contextual-translation/analyze');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _headers(_apiKey),
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ContextualTranslationException(
          ContextualTranslationFailureReason.http,
          _errorMessageFor(response),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const ContextualTranslationException(
          ContextualTranslationFailureReason.invalidResponse,
          'Translation service returned an invalid response',
        );
      }
      return ContextualTranslationResult.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on ContextualTranslationException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.network,
        'Translation request timed out',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.network,
        'Translation service is unavailable',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ContextualTranslationException(
        ContextualTranslationFailureReason.invalidResponse,
        'Translation service returned invalid JSON',
        cause: error,
      );
    }
  }

  @override
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }
}

Map<String, String> _headers(String? apiKey) {
  final headers = {
    'content-type': 'application/json',
    'accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
  if (apiKey != null && apiKey.isNotEmpty) {
    headers['X-API-Key'] = apiKey;
  }
  return headers;
}

String _errorMessageFor(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
  } on FormatException {
    // Fall through to the status-code message.
  }
  return 'Translation service returned HTTP ${response.statusCode}';
}
