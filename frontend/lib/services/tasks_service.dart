import '../models/task.dart';
import 'api_client.dart';

class TasksService {
  final ApiClient _client;

  TasksService(this._client);

  /// The board endpoint groups tasks by status. Optional filters narrow the
  /// result server-side (search text, priority, label, due window).
  Future<Map<String, List<Task>>> board(
    int projectId, {
    String? q,
    String? priority,
    int? labelId,
    String? due,
  }) async {
    final query = <String, dynamic>{};
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (priority != null) query['priority'] = priority;
    if (labelId != null) query['label_id'] = labelId;
    if (due != null) query['due'] = due;

    final data = await _client.get('/projects/$projectId/board', query: query) as Map<String, dynamic>;
    return data.map(
      (status, tasks) => MapEntry(
        status,
        (tasks as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
  }

  /// Paginated task list with search/filter (used by the search view).
  Future<List<Task>> list(
    int projectId, {
    String? q,
    String? status,
    String? priority,
    int? labelId,
    String? due,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (status != null) query['status'] = status;
    if (priority != null) query['priority'] = priority;
    if (labelId != null) query['label_id'] = labelId;
    if (due != null) query['due'] = due;

    final data = await _client.get('/projects/$projectId/tasks', query: query) as Map<String, dynamic>;
    return (data['items'] as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
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
    List<int>? labelIds,
  }) async {
    final body = <String, dynamic>{'title': title, 'status': status, 'priority': priority};
    if (description != null && description.isNotEmpty) body['description'] = description;
    if (dueDate != null) body['due_date'] = _dateOnly(dueDate);
    if (labelIds != null) body['label_ids'] = labelIds;

    final data = await _client.post('/projects/$projectId/tasks', body);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  /// `patch` should only contain keys the caller explicitly wants to change
  /// (PATCH semantics) -- e.g. pass `{'due_date': null}` to clear a due date.
  Future<Task> update(int taskId, Map<String, dynamic> patch) async {
    final data = await _client.patch('/tasks/$taskId', patch);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  /// Reorder within a column. Provide `beforeId` (place immediately before
  /// that task) and/or `afterId` (immediately after), or an explicit
  /// `position`. Only the moved task's row changes server-side.
  Future<Task> reorder(int taskId, {int? beforeId, int? afterId, double? position}) async {
    final body = <String, dynamic>{};
    if (position != null) body['position'] = position;
    if (beforeId != null) body['before_id'] = beforeId;
    if (afterId != null) body['after_id'] = afterId;

    final data = await _client.post('/tasks/$taskId/reorder', body);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<Task> setLabels(int taskId, List<int> labelIds) async {
    final data = await _client.put('/tasks/$taskId/labels', labelIds);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int taskId) => _client.delete('/tasks/$taskId');

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
