import 'dart:async';
import 'dart:convert';

import 'package:bounded_http/bounded_http.dart';
import 'package:http/http.dart' as http;

import 'dictionary_errors.dart';
import 'dictionary_lookup_cache.dart';
import 'dictionary_models.dart';
import 'dictionary_service.dart';

class RemoteDictionaryLookupService implements DictionaryLookupService {
  RemoteDictionaryLookupService({
    required Uri baseUri,
    http.Client? httpClient,
    DictionaryLookupCache? cache,
    String? apiKey,
    Duration timeout = const Duration(seconds: 40),
    int maxResponseBytes = defaultMaxResponseBytes,
  }) : _baseUri = baseUri,
       _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _cache = cache ?? MemoryDictionaryLookupCache(),
       _apiKey = apiKey,
       _timeout = timeout,
       _maxResponseBytes = maxResponseBytes;

  static const defaultMaxResponseBytes = 1024 * 1024;

  final Uri _baseUri;
  final http.Client _httpClient;
  final bool _ownsClient;
  final DictionaryLookupCache _cache;
  final String? _apiKey;
  final Duration _timeout;
  final int _maxResponseBytes;

  @override
  Future<DictionaryLookupResult> lookup(
    DictionaryLookupRequest request, {
    Future<void>? abortTrigger,
  }) async {
    final cached = _cache.read(request);
    if (cached != null) return _resultForRequest(cached, request.requestId);

    final uri = _baseUri.resolve('/v1/dictionary/lookup');
    try {
      final response = await postBoundedResponse(
        client: _httpClient,
        uri: uri,
        headers: _headers(_apiKey),
        body: jsonEncode(request.toJson()),
        maxResponseBytes: _maxResponseBytes,
        timeout: _timeout,
        abortTrigger: abortTrigger,
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
      if (_isCacheable(result)) _cache.write(request, result);
      return result;
    } on DictionaryLookupException {
      rethrow;
    } on HttpResponseTooLargeException catch (error) {
      throw DictionaryLookupException(
        DictionaryLookupFailureReason.invalidResponse,
        'Dictionary response is too large',
        cause: error,
      );
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

// A found term without entries is a degenerate answer; asking again may help.
bool _isCacheable(DictionaryLookupResult result) {
  return result.status != DictionaryLookupStatus.found ||
      result.entries.isNotEmpty;
}

DictionaryLookupResult _resultForRequest(
  DictionaryLookupResult result,
  String requestId,
) {
  if (result.requestId == requestId) return result;
  return DictionaryLookupResult(
    requestId: requestId,
    status: result.status,
    term: result.term,
    language: result.language,
    entries: result.entries,
  );
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
