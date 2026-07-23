import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/workspace.dart';
import 'token_storage.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

/// Single source of truth for auth + tenancy state, watched app-wide by the
/// AuthGate. Holds tokens, the current user, the list of workspaces the user
/// belongs to, and which one is active. Persists tokens + the active
/// workspace to secure storage so a restart stays logged in.
///
/// Constructed before ApiClient; `attach()` wires the client in afterwards so
/// the session can fetch /auth/me and /workspaces during bootstrap without a
/// construction cycle.
class SessionController extends ChangeNotifier {
  final TokenStorage _storage;

  SessionController(this._storage);

  // Set once, right after construction, before any use.
  late final dynamic _api; // ApiClient; typed loosely to avoid an import cycle.

  SessionStatus _status = SessionStatus.unknown;
  String? _accessToken;
  String? _refreshToken;
  int? _currentWorkspaceId;
  AppUser? _currentUser;
  List<Workspace> _workspaces = [];

  SessionStatus get status => _status;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get currentWorkspaceId => _currentWorkspaceId;
  AppUser? get currentUser => _currentUser;
  List<Workspace> get workspaces => _workspaces;

  Workspace? get currentWorkspace {
    for (final ws in _workspaces) {
      if (ws.id == _currentWorkspaceId) return ws;
    }
    return _workspaces.isEmpty ? null : _workspaces.first;
  }

  void attach(dynamic apiClient) => _api = apiClient;

  /// Called on app start: restore tokens from storage and validate them.
  Future<void> bootstrap() async {
    try {
      _accessToken = await _storage.readAccess();
      _refreshToken = await _storage.readRefresh();
      _currentWorkspaceId = await _storage.readWorkspaceId();
    } catch (_) {
      // Secure storage unavailable (e.g. an unconfigured platform) -> treat
      // as a fresh, logged-out start rather than crashing on boot.
      _accessToken = null;
    }

    if (_accessToken == null) {
      _status = SessionStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      await _loadUserAndWorkspaces();
      _status = SessionStatus.authenticated;
    } catch (_) {
      // Tokens invalid / refresh failed -> force a fresh login.
      await _clear();
      _status = SessionStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Called after a successful register/login.
  Future<void> completeLogin(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.saveTokens(access, refresh);
    await _loadUserAndWorkspaces();
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  /// Called by ApiClient after a transparent token refresh.
  Future<void> updateTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.saveTokens(access, refresh);
  }

  Future<void> switchWorkspace(int workspaceId) async {
    _currentWorkspaceId = workspaceId;
    await _storage.saveWorkspaceId(workspaceId);
    notifyListeners();
  }

  Future<void> refreshWorkspaces() async {
    final data = await _api.get('/workspaces') as List;
    _workspaces = data.map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList();
    _ensureValidWorkspace();
    notifyListeners();
  }

  Future<void> logout() async {
    await _clear();
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> _loadUserAndWorkspaces() async {
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AppUser.fromJson(me);
    final data = await _api.get('/workspaces') as List;
    _workspaces = data.map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList();
    _ensureValidWorkspace();
  }

  void _ensureValidWorkspace() {
    final ids = _workspaces.map((w) => w.id).toSet();
    if (_currentWorkspaceId == null || !ids.contains(_currentWorkspaceId)) {
      _currentWorkspaceId = _workspaces.isEmpty ? null : _workspaces.first.id;
      if (_currentWorkspaceId != null) {
        _storage.saveWorkspaceId(_currentWorkspaceId!);
      }
    }
  }

  Future<void> _clear() async {
    _accessToken = null;
    _refreshToken = null;
    _currentWorkspaceId = null;
    _currentUser = null;
    _workspaces = [];
    await _storage.clear();
  }
}
