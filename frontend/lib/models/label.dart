class Label {
  final int id;
  final int workspaceId;
  final String name;
  final String? color;

  const Label({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.color,
  });

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] as int,
      workspaceId: json['workspace_id'] as int,
      name: json['name'] as String,
      color: json['color'] as String?,
    );
  }
}
