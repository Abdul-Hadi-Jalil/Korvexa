import 'package:flutter/material.dart';

import '../models/task.dart';
import 'label_chip.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final String? assigneeName;

  const TaskCard({super.key, required this.task, this.onTap, this.assigneeName});

  Color _priorityColor(BuildContext context) => switch (task.priority) {
        TaskPriority.high => Colors.red.shade400,
        TaskPriority.medium => Colors.orange.shade400,
        _ => Colors.blueGrey.shade300,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: _priorityColor(context), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(task.key, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(task.title, style: Theme.of(context).textTheme.bodyMedium),
              if (task.labels.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final label in task.labels)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: labelColor(label).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(label.name, style: const TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ],
              if (task.dueDate != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event,
                        size: 14, color: task.isOverdue ? Colors.red : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isOverdue ? Colors.red : Colors.grey.shade600,
                        fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
              if (assigneeName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      child: Text(
                        assigneeName!.isEmpty ? '?' : assigneeName!.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(assigneeName!, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
