import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/upcoming_provider.dart';
import '../services/me_service.dart';
import '../theme/app_colors.dart';
import 'task_detail_screen.dart';

/// Body-only "My Tasks" view (Scaffold/AppBar owned by HomeShell).
class MyTasksView extends StatefulWidget {
  const MyTasksView({super.key});

  @override
  State<MyTasksView> createState() => _MyTasksViewState();
}

class _MyTasksViewState extends State<MyTasksView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UpcomingProvider>().load();
    });
  }

  static const _windowLabels = {
    UpcomingWindow.today: 'Today',
    UpcomingWindow.week: 'This Week',
    UpcomingWindow.all: 'All Open',
  };

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');

    return Consumer<UpcomingProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Tasks',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Your open work across every project.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: _windowLabels.entries
                            .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                            .toList(),
                        selected: {provider.window},
                        onSelectionChanged: (selection) => provider.setWindow(selection.first),
                      ),
                      const Spacer(),
                      const Text('Assigned to me',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(width: 8),
                      Switch(value: provider.mineOnly, onChanged: provider.setMineOnly),
                    ],
                  ),
                ],
              ),
            ),
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                child: Text(provider.error!, style: const TextStyle(color: AppColors.danger)),
              ),
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.tasks.isEmpty
                      ? const _EmptyMyTasks()
                      : RefreshIndicator(
                          onRefresh: provider.load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                            itemCount: provider.tasks.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _TaskRow(task: provider.tasks[index], dateFormat: dateFormat, onReturn: provider.load),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final DateFormat dateFormat;
  final Future<void> Function() onReturn;

  const _TaskRow({required this.task, required this.dateFormat, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
            );
            await onReturn();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: AppColors.priority(task.priority), shape: BoxShape.circle),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                      const SizedBox(height: 3),
                      Text('${task.projectName ?? ''} · ${task.key}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (task.dueDate != null)
                  Text(
                    dateFormat.format(task.dueDate!),
                    style: TextStyle(
                      color: task.isOverdue ? AppColors.danger : AppColors.textSecondary,
                      fontWeight: task.isOverdue ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMyTasks extends StatelessWidget {
  const _EmptyMyTasks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Nothing here. Nice work!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
