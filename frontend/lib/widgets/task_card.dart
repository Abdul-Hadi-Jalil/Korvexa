import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme/app_colors.dart';

/// A board card: a muted key row with a priority dot, the title, tinted label
/// chips, and a footer with the due date (red when overdue) and the assignee.
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final String? assigneeName;
  final bool dragging;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.assigneeName,
    this.dragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final dueFmt = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dragging ? AppColors.accent : AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.key,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    if (done)
                      const Icon(Icons.check_circle, size: 13, color: AppColors.statusDone)
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.priority(task.priority),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: done ? AppColors.textSecondary : AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.3,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
                if (task.labels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final label in task.labels.take(3))
                        _MiniLabel(name: label.name, color: _labelColor(label.color)),
                    ],
                  ),
                ],
                if (task.dueDate != null || assigneeName != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (task.dueDate != null) ...[
                        Icon(Icons.calendar_today_outlined,
                            size: 12,
                            color: task.isOverdue ? AppColors.danger : AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          dueFmt.format(task.dueDate!),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: task.isOverdue ? AppColors.danger : AppColors.textMuted,
                            fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (assigneeName != null)
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.accentSubtle,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            assigneeName!.isEmpty ? '?' : assigneeName!.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _labelColor(String? hex) {
    if (hex == null) return AppColors.accent;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? AppColors.accent : Color(v);
  }
}

class _MiniLabel extends StatelessWidget {
  final String name;
  final Color color;

  const _MiniLabel({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 10.5, color: Color.lerp(color, Colors.white, 0.35)),
      ),
    );
  }
}
