import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/upcoming_provider.dart';
import '../services/me_service.dart';
import 'task_detail_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
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

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: Consumer<UpcomingProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SegmentedButton<String>(
                  segments: _windowLabels.entries
                      .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                      .toList(),
                  selected: {provider.window},
                  onSelectionChanged: (selection) => provider.setWindow(selection.first),
                ),
              ),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(
                child: provider.loading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.tasks.isEmpty
                        ? const Center(child: Text('Nothing here. Nice work!'))
                        : RefreshIndicator(
                            onRefresh: provider.load,
                            child: ListView.separated(
                              itemCount: provider.tasks.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final task = provider.tasks[index];
                                return ListTile(
                                  title: Text(task.title),
                                  subtitle: Text('${task.projectName ?? ''} · ${task.key}'),
                                  trailing: task.dueDate == null
                                      ? null
                                      : Text(
                                          dateFormat.format(task.dueDate!),
                                          style: TextStyle(
                                            color: task.isOverdue
                                                ? Theme.of(context).colorScheme.error
                                                : null,
                                            fontWeight: task.isOverdue ? FontWeight.bold : null,
                                          ),
                                        ),
                                  leading: _PriorityDot(priority: task.priority),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(taskId: task.id),
                                      ),
                                    );
                                    await provider.load();
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final String priority;

  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.high => Colors.red.shade400,
      TaskPriority.medium => Colors.orange.shade400,
      _ => Colors.blueGrey.shade300,
    };
    return CircleAvatar(radius: 6, backgroundColor: color);
  }
}
