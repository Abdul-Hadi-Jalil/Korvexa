import 'api_client.dart';

/// Access + refresh tokens returned by register/login.
class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens(this.accessToken, this.refreshToken);

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      AuthTokens(json['access_token'] as String, json['refresh_token'] as String);
}

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<AuthTokens> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final data = await _client.post('/auth/register', {
      'email': email,
      'name': name,
      'password': password,
    });
    return AuthTokens.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthTokens> login({required String email, required String password}) async {
    final data = await _client.post('/auth/login', {'email': email, 'password': password});
    return AuthTokens.fromJson(data as Map<String, dynamic>);
  }
}
