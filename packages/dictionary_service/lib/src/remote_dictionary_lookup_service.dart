import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dictionary_errors.dart';
import 'dictionary_models.dart';
import 'dictionary_service.dart';

class RemoteDictionaryLookupService implements DictionaryLookupService {
  RemoteDictionaryLookupService({
    required Uri baseUri,
    http.Client? httpClient,
    String? apiKey,
    Duration timeout = const Duration(seconds: 40),
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
  Future<DictionaryLookupResult> lookup(DictionaryLookupRequest request) async {
    final uri = _baseUri.resolve('/v1/dictionary/lookup');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _headers(_apiKey),
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DictionaryLookupException(
          DictionaryLookupFailureReason.http,
          _errorMessageFor(response),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const DictionaryLookupException(
          DictionaryLookupFailureReason.invalidResponse,
          'Dictionary service returned an invalid response',
        );
      }
      return DictionaryLookupResult.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on DictionaryLookupException {
      rethrow;
    } on TimeoutException catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.network,
        'Dictionary request timed out',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.network,
        'Dictionary service is unavailable',
        cause: error,
      );
    } on FormatException catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.invalidResponse,
        'Dictionary service returned invalid JSON',
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
      for (final key in const ['detail', 'error', 'message']) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
  } on FormatException {
    // Fall through to the status-code message.
  }
  return 'Dictionary service returned HTTP ${response.statusCode}';
}
