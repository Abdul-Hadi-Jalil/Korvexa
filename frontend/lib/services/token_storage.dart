import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage for the auth tokens and the
/// last-selected workspace id. On web this is backed by an encrypted
/// IndexedDB store; on native by the platform keychain/keystore.
class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _workspaceKey = 'workspace_id';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> saveWorkspaceId(int id) => _storage.write(key: _workspaceKey, value: '$id');

  Future<int?> readWorkspaceId() async {
    final raw = await _storage.read(key: _workspaceKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _workspaceKey);
  }
}
