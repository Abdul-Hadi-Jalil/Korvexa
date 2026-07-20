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

  // Active filters (applied server-side on the board endpoint).
  String? _search;
  String? _priorityFilter;
  int? _labelFilter;
  String? _dueFilter;

  Map<String, List<Task>> get columns => _columns;
  bool get loading => _loading;
  String? get error => _error;
  String? get search => _search;
  String? get priorityFilter => _priorityFilter;
  int? get labelFilter => _labelFilter;
  String? get dueFilter => _dueFilter;

  bool get hasFilters =>
      (_search != null && _search!.isNotEmpty) ||
      _priorityFilter != null ||
      _labelFilter != null ||
      _dueFilter != null;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _columns = await _service.board(
        projectId,
        q: _search,
        priority: _priorityFilter,
        labelId: _labelFilter,
        due: _dueFilter,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setSearch(String? value) async {
    _search = (value == null || value.isEmpty) ? null : value;
    await load();
  }

  Future<void> setPriorityFilter(String? value) async {
    _priorityFilter = value;
    await load();
  }

  Future<void> setLabelFilter(int? value) async {
    _labelFilter = value;
    await load();
  }

  Future<void> setDueFilter(String? value) async {
    _dueFilter = value;
    await load();
  }

  Future<void> clearFilters() async {
    _search = null;
    _priorityFilter = null;
    _labelFilter = null;
    _dueFilter = null;
    await load();
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

  /// Drop a card onto a column (not onto a specific card): PATCH status with
  /// no position so the backend appends it to the end of the target column.
  Future<void> moveToColumn(Task task, String newStatus) async {
    if (task.status == newStatus) return;
    await _mutate(() => _service.update(task.id, {'status': newStatus}));
  }

  /// Drop a card onto another card. Within the same column this is a pure
  /// reorder (one-row write). Across columns it changes status first, then
  /// positions the card immediately before the target.
  Future<void> reorderBefore(Task task, Task target) async {
    if (task.id == target.id) return;
    await _mutate(() async {
      if (task.status != target.status) {
        await _service.update(task.id, {'status': target.status});
      }
      await _service.reorder(task.id, beforeId: target.id);
    });
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

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } on ApiException catch (e) {
      _error = e.message;
      await load(); // resync UI to the server's actual state
    }
  }
}
