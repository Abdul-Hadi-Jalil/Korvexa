import 'label.dart';

export 'label.dart';

/// Task status values, matching the backend's `TaskStatus` enum.
class TaskStatus {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const done = 'done';

  static const all = [todo, inProgress, done];

  static String label(String status) => switch (status) {
        todo => 'To Do',
        inProgress => 'In Progress',
        done => 'Done',
        _ => status,
      };
}

/// Task priority values, matching the backend's `TaskPriority` enum.
class TaskPriority {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';

  static const all = [low, medium, high];

  static String label(String priority) => switch (priority) {
        low => 'Low',
        medium => 'Medium',
        high => 'High',
        _ => priority,
      };
}

class Task {
  final int id;
  final int projectId;
  final int number;
  final String key;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final int? assigneeId;
  final DateTime? dueDate;
  final double position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Label> labels;
  // Only present on endpoints that join across projects (e.g. /me/upcoming).
  final String? projectName;
  final String? projectKey;

  const Task({
    required this.id,
    required this.projectId,
    required this.number,
    required this.key,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assigneeId,
    required this.dueDate,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.labels = const [],
    this.projectName,
    this.projectKey,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      number: json['number'] as int,
      key: json['key'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      assigneeId: json['assignee_id'] as int?,
      dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
      position: (json['position'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      labels: ((json['labels'] as List?) ?? const [])
          .map((e) => Label.fromJson(e as Map<String, dynamic>))
          .toList(),
      projectName: json['project_name'] as String?,
      projectKey: json['project_key'] as String?,
    );
  }

  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.done) return false;
    final today = DateTime.now();
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.isBefore(todayDay);
  }
}
