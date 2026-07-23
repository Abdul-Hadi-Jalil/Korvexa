class AppNotification {
  final int id;
  final String type; // "assigned" | "mention"
  final int? taskId;
  final int? commentId;
  final int? actorId;
  final String message;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.taskId,
    required this.commentId,
    required this.actorId,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      taskId: json['task_id'] as int?,
      commentId: json['comment_id'] as int?,
      actorId: json['actor_id'] as int?,
      message: json['message'] as String,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
