import '../models/workspace.dart';
import 'api_client.dart';

class WorkspacesService {
  final ApiClient _client;

  WorkspacesService(this._client);

  Future<List<Workspace>> list() async {
    final data = await _client.get('/workspaces') as List;
    return data.map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Workspace> create(String name) async {
    final data = await _client.post('/workspaces', {'name': name});
    return Workspace.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Member>> members(int workspaceId) async {
    final data = await _client.get('/workspaces/$workspaceId/members') as List;
    return data.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Member> invite(int workspaceId, {required String email, String role = 'member'}) async {
    final data = await _client.post('/workspaces/$workspaceId/invite', {'email': email, 'role': role});
    return Member.fromJson(data as Map<String, dynamic>);
  }

  Future<Member> updateRole(int workspaceId, int userId, String role) async {
    final data = await _client.patch('/workspaces/$workspaceId/members/$userId', {'role': role});
    return Member.fromJson(data as Map<String, dynamic>);
  }

  Future<void> removeMember(int workspaceId, int userId) =>
      _client.delete('/workspaces/$workspaceId/members/$userId');
}
