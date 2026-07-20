import '../models/task.dart';
import 'api_client.dart';

class TasksService {
  final ApiClient _client;

  TasksService(this._client);

  Future<Map<String, List<Task>>> board(int projectId) async {
    final data = await _client.get('/projects/$projectId/board') as Map<String, dynamic>;
    return data.map(
      (status, tasks) => MapEntry(
        status,
        (tasks as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
  }

  Future<List<Task>> list(int projectId) async {
    final data = await _client.get('/projects/$projectId/tasks') as List;
    return data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Task> get(int taskId) async {
    final data = await _client.get('/tasks/$taskId');
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<Task> create(
    int projectId, {
    required String title,
    String? description,
    String status = TaskStatus.todo,
    String priority = TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    final data = await _client.post('/projects/$projectId/tasks', {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'status': status,
      'priority': priority,
      if (dueDate != null) 'due_date': _dateOnly(dueDate),
    });
    return Task.fromJson(data as Map<String, dynamic>);
  }

  /// `patch` should only contain keys the caller explicitly wants to change
  /// (PATCH semantics) -- e.g. pass `{'due_date': null}` to clear a due date.
  Future<Task> update(int taskId, Map<String, dynamic> patch) async {
    final data = await _client.patch('/tasks/$taskId', patch);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int taskId) => _client.delete('/tasks/$taskId');

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
