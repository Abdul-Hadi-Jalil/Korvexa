import '../models/project.dart';
import 'api_client.dart';

class ProjectsService {
  final ApiClient _client;

  ProjectsService(this._client);

  Future<List<Project>> list({bool includeArchived = false}) async {
    final data = await _client.get('/projects', query: {'include_archived': includeArchived});
    return (data as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Project> get(int id) async {
    final data = await _client.get('/projects/$id');
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<Project> create({required String name, String? key, String? description}) async {
    final data = await _client.post('/projects', {
      'name': name,
      if (key != null && key.isNotEmpty) 'key': key,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<Project> update(int id, Map<String, dynamic> patch) async {
    final data = await _client.patch('/projects/$id', patch);
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<Project> archive(int id) async {
    final data = await _client.post('/projects/$id/archive', {});
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<Project> unarchive(int id) async {
    final data = await _client.post('/projects/$id/unarchive', {});
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _client.delete('/projects/$id');
}
