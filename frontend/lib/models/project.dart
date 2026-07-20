class Project {
  final int id;
  final int workspaceId;
  final String name;
  final String key;
  final String? description;
  final String? color;
  final bool archived;
  final DateTime createdAt;
  final int openTasks;
  final int totalTasks;

  const Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.key,
    required this.description,
    required this.color,
    required this.archived,
    required this.createdAt,
    required this.openTasks,
    required this.totalTasks,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      workspaceId: json['workspace_id'] as int,
      name: json['name'] as String,
      key: json['key'] as String,
      description: json['description'] as String?,
      color: json['color'] as String?,
      archived: json['archived'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      openTasks: json['open_tasks'] as int,
      totalTasks: json['total_tasks'] as int,
    );
  }
}
