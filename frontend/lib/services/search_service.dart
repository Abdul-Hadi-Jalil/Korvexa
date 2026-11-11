import '../models/task.dart';
import 'api_client.dart';

class SearchService {
  final ApiClient _client;

  SearchService(this._client);

  /// Workspace-wide task search. Each result carries its project name/key.
  Future<List<Task>> tasks(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final data = await _client.get('/search/tasks', query: {'q': q, 'limit': limit}) as List;
    return data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }
}
