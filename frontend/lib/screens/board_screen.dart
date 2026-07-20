import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/board_provider.dart';
import '../services/api_client.dart';
import '../services/tasks_service.dart';
import '../widgets/task_card.dart';
import 'task_edit_screen.dart';

class BoardScreen extends StatelessWidget {
  final Project project;

  const BoardScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BoardProvider(TasksService(context.read<ApiClient>()), project.id)..load(),
      child: _BoardView(project: project),
    );
  }
}

class _BoardView extends StatelessWidget {
  final Project project;

  const _BoardView({required this.project});

  static const _columnTitles = {
    TaskStatus.todo: 'To Do',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.done: 'Done',
  };

  Future<void> _promptNewTask(BuildContext context, String status) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('New task · ${_columnTitles[status]}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty && context.mounted) {
      await context.read<BoardProvider>().createTask(title.trim(), status: status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${project.name} (${project.key})')),
      body: Consumer<BoardProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.columns.values.every((l) => l.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: TaskStatus.all
                .map((status) => Expanded(child: _BoardColumn(
                      status: status,
                      title: _columnTitles[status]!,
                      tasks: provider.columns[status] ?? const [],
                      onAddTask: () => _promptNewTask(context, status),
                    )))
                .toList(),
          );
        },
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final String status;
  final String title;
  final List<Task> tasks;
  final VoidCallback onAddTask;

  const _BoardColumn({
    required this.status,
    required this.title,
    required this.tasks,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        context.read<BoardProvider>().moveTask(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return Container(
          color: highlighted ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06) : null,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$title (${tasks.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'Add task',
                      onPressed: onAddTask,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 220, child: TaskCard(task: task)),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: TaskCard(task: task)),
                      child: TaskCard(
                        task: task,
                        onTap: () async {
                          final boardProvider = context.read<BoardProvider>();
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => TaskEditScreen(taskId: task.id)),
                          );
                          if (changed == true) {
                            await boardProvider.load();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
