import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'session.dart';

/// Thrown for any non-2xx response; carries the backend's `detail` message
/// (falling back to a generic one) so screens can show something useful.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// JSON/HTTP wrapper around the Korvexa API.
///
/// Injects the bearer access token and `X-Workspace-Id` from the
/// [SessionController] on every request. On a 401 it transparently tries to
/// refresh the access token once and replays the request; if refresh fails
/// it logs the session out.
class ApiClient {
  final String baseUrl;
  final http.Client _http;
  final SessionController session;

  ApiClient({required this.session, String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizedQuery = query?.map((key, value) => MapEntry(key, value.toString()));
    return Uri.parse('$baseUrl$path').replace(queryParameters: normalizedQuery);
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = session.accessToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final workspaceId = session.currentWorkspaceId;
    if (workspaceId != null) headers['X-Workspace-Id'] = '$workspaceId';
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, Object body) => _send(
      () => _http.post(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  Future<dynamic> patch(String path, Object body) => _send(
      () => _http.patch(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  Future<dynamic> put(String path, Object body) => _send(
      () => _http.put(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  Future<void> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers()));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    var response = await request();
    if (response.statusCode == 401 && session.accessToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await request(); // replay once with the new token
      } else {
        await session.logout();
      }
    }
    return _decode(response);
  }

  /// Raw refresh call (no auth header). Returns true and updates the session
  /// on success. Kept here rather than in AuthService to avoid a dependency
  /// cycle and so any request can trigger it.
  Future<bool> _tryRefresh() async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _http.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await session.updateTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
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
