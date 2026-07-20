import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Thrown for any non-2xx response; carries the backend's `detail` message
/// (falling back to a generic one) so screens can show something useful.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin JSON/HTTP wrapper around the Korvexa API. Resource-specific logic
/// (Projects, Tasks, Me) lives in their own service classes that take this
/// as a dependency, keeping each file small and independently testable.
class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _http = httpClient ?? http.Client();

  static const _headers = {'Content-Type': 'application/json'};

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedQuery = query?.map((key, value) => MapEntry(key, value.toString()));
    return Uri.parse('$baseUrl$path').replace(queryParameters: normalizedQuery);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _http.get(_uri(path, query));
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _http.post(_uri(path), headers: _headers, body: jsonEncode(body));
    return _decode(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await _http.patch(_uri(path), headers: _headers, body: jsonEncode(body));
    return _decode(response);
  }

  /// `body` may be any JSON-encodable value (e.g. a bare list for
  /// `PUT /tasks/{id}/labels`), not just a map.
  Future<dynamic> put(String path, Object body) async {
    final response = await _http.put(_uri(path), headers: _headers, body: jsonEncode(body));
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await _http.delete(_uri(path));
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    var message = 'Request failed (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        message = detail is String ? detail : detail.toString();
      }
    } catch (_) {
      // Body wasn't JSON; keep the generic message.
    }
    throw ApiException(response.statusCode, message);
  }
}
