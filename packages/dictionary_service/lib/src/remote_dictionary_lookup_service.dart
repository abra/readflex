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
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) async {
    final uri = _baseUri.resolve('/v1/dictionary/lookup');
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    abortTrigger?.then((_) => cancel());
    try {
      final httpRequest =
          http.AbortableRequest('POST', uri, abortTrigger: abort.future)
            ..headers.addAll(_headers(_apiKey))
            ..body = jsonEncode(request.toJson());
      final response = await _httpClient
          .send(httpRequest)
          .then(http.Response.fromStream)
          .timeout(
            _timeout,
            onTimeout: () {
              cancel();
              throw TimeoutException('Dictionary request timed out', _timeout);
            },
          );
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
      final result = DictionaryLookupResult.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (result.requestId != request.requestId) {
        throw const DictionaryLookupException(
          DictionaryLookupFailureReason.invalidResponse,
          'Dictionary response does not match the request',
        );
      }
      return result;
    } on DictionaryLookupException {
      rethrow;
    } on TimeoutException catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.network,
        'Dictionary request timed out',
        cause: error,
      );
    } on http.RequestAbortedException catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.cancelled,
        'Dictionary request cancelled',
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
        'Dictionary service returned an invalid response',
        cause: error,
      );
    } on TypeError catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.invalidResponse,
        'Dictionary service returned an invalid response',
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
  return switch (response.statusCode) {
    401 || 403 => 'Dictionary service authorization failed',
    413 => 'Selected term is too large',
    422 => 'Dictionary request is invalid',
    429 => 'Dictionary service is temporarily busy',
    >= 500 => 'Dictionary service is unavailable',
    _ => 'Dictionary request failed',
  };
}
