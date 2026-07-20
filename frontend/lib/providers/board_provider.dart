import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../services/tasks_service.dart';

/// Kanban state for a single project's board. Scoped per-screen (created
/// fresh each time BoardScreen opens) rather than app-wide.
class BoardProvider extends ChangeNotifier {
  final TasksService _service;
  final int projectId;

  BoardProvider(this._service, this.projectId);

  Map<String, List<Task>> _columns = {
    TaskStatus.todo: [],
    TaskStatus.inProgress: [],
    TaskStatus.done: [],
  };
  bool _loading = false;
  String? _error;

  Map<String, List<Task>> get columns => _columns;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _columns = await _service.board(projectId);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createTask(String title, {String status = TaskStatus.todo}) async {
    try {
      await _service.create(projectId, title: title, status: status);
      await load(); // server assigns number/key/position; simplest is to refetch.
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Drag-and-drop between columns: PATCH status only, no explicit position,
  /// so the backend appends it to the end of the target column.
  Future<void> moveTask(Task task, String newStatus) async {
    if (task.status == newStatus) return;

    // Optimistic UI update so the drop feels instant.
    final previousColumns = _columns;
    _columns = {
      for (final entry in _columns.entries)
        entry.key: entry.key == task.status
            ? entry.value.where((t) => t.id != task.id).toList()
            : entry.value,
    };
    notifyListeners();

    try {
      await _service.update(task.id, {'status': newStatus});
      await load();
    } on ApiException catch (e) {
      _columns = previousColumns; // roll back on failure
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> deleteTask(Task task) async {
    try {
      await _service.delete(task.id);
      await load();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
