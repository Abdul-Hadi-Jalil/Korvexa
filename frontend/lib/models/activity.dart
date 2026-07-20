class Activity {
  final int id;
  final int taskId;
  final int? actorId;
  final String action;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;

  const Activity({
    required this.id,
    required this.taskId,
    required this.actorId,
    required this.action,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      actorId: json['actor_id'] as int?,
      action: json['action'] as String,
      field: json['field'] as String?,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Human-readable one-liner for the activity timeline.
  String describe() {
    switch (action) {
      case 'created':
        return 'created this task';
      case 'status_changed':
        return 'changed status from ${oldValue ?? '?'} to ${newValue ?? '?'}';
      case 'updated':
        return 'changed ${field ?? 'a field'} to "${newValue ?? ''}"';
      default:
        return action;
    }
  }
}
