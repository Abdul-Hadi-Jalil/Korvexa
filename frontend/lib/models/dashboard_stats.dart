class DashboardStats {
  final int projectsActive;
  final int projectsArchived;
  final int tasksTotal;
  final int tasksTodo;
  final int tasksInProgress;
  final int tasksDone;
  final int tasksOverdue;
  final int assignedToMeOpen;
  final int assignedToMeOverdue;
  final int priorityHigh;
  final int priorityMedium;
  final int priorityLow;

  const DashboardStats({
    required this.projectsActive,
    required this.projectsArchived,
    required this.tasksTotal,
    required this.tasksTodo,
    required this.tasksInProgress,
    required this.tasksDone,
    required this.tasksOverdue,
    required this.assignedToMeOpen,
    required this.assignedToMeOverdue,
    required this.priorityHigh,
    required this.priorityMedium,
    required this.priorityLow,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;
    return DashboardStats(
      projectsActive: v('projects_active'),
      projectsArchived: v('projects_archived'),
      tasksTotal: v('tasks_total'),
      tasksTodo: v('tasks_todo'),
      tasksInProgress: v('tasks_in_progress'),
      tasksDone: v('tasks_done'),
      tasksOverdue: v('tasks_overdue'),
      assignedToMeOpen: v('assigned_to_me_open'),
      assignedToMeOverdue: v('assigned_to_me_overdue'),
      priorityHigh: v('priority_high'),
      priorityMedium: v('priority_medium'),
      priorityLow: v('priority_low'),
    );
  }
}
