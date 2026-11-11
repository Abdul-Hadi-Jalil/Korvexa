import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/board_provider.dart';
import '../providers/labels_provider.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../services/tasks_service.dart';
import '../services/workspaces_service.dart';
import '../theme/app_colors.dart';
import '../widgets/key_avatar.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

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

class _BoardView extends StatefulWidget {
  final Project project;

  const _BoardView({required this.project});

  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> {
  final _searchController = TextEditingController();
  Map<int, String> _assigneeNames = {};

  static const _columnTitles = {
    TaskStatus.todo: 'To Do',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.done: 'Done',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LabelsProvider>().load();
      _loadMembers();
    });
  }

  Future<void> _loadMembers() async {
    final workspaceId = context.read<SessionController>().currentWorkspaceId;
    if (workspaceId == null) return;
    try {
      final members = await WorkspacesService(context.read<ApiClient>()).members(workspaceId);
      if (mounted) {
        setState(() => _assigneeNames = {for (final m in members) m.userId: m.name});
      }
    } on ApiException {
      // Non-fatal: cards just won't show an assignee name.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _promptNewTask(BuildContext context, String status) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('New task · ${_columnTitles[status]}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task title'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
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
    final tint = AppColors.forKey(widget.project.key);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            KeyAvatar(label: widget.project.key, size: 30, color: tint),
            const SizedBox(width: 10),
            Flexible(
              child: Text(widget.project.name, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(widget.project.key,
                  style: TextStyle(
                      color: Color.lerp(tint, Colors.white, 0.3),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      body: Consumer<BoardProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _FilterBar(searchController: _searchController),
              const Divider(height: 1),
              if (provider.error != null)
                Container(
                  width: double.infinity,
                  color: AppColors.danger.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(10),
                  child: Text(provider.error!, style: const TextStyle(color: AppColors.danger)),
                ),
              Expanded(
                child: provider.loading && provider.columns.values.every((l) => l.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final status in TaskStatus.all) ...[
                            Expanded(
                              child: _BoardColumn(
                                status: status,
                                title: _columnTitles[status]!,
                                tasks: provider.columns[status] ?? const [],
                                assigneeNames: _assigneeNames,
                                onAddTask: () => _promptNewTask(context, status),
                                onOpenTask: (task) => _openTask(context, task),
                              ),
                            ),
                            if (status != TaskStatus.done) const VerticalDivider(width: 1),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openTask(BuildContext context, Task task) async {
    final boardProvider = context.read<BoardProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
    );
    await boardProvider.load();
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;

  const _FilterBar({required this.searchController});

  @override
  Widget build(BuildContext context) {
    final board = context.watch<BoardProvider>();
    final labels = context.watch<LabelsProvider>().labels;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.filter_list, size: 18),
                hintText: 'Filter tasks...',
                suffixIcon: board.search == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          searchController.clear();
                          board.setSearch(null);
                        },
                      ),
              ),
              onSubmitted: (value) => board.setSearch(value),
            ),
          ),
          const SizedBox(width: 10),
          _FilterDropdown<String?>(
            hint: 'Priority',
            value: board.priorityFilter,
            items: const {
              null: 'Any priority',
              TaskPriority.high: 'High',
              TaskPriority.medium: 'Medium',
              TaskPriority.low: 'Low',
            },
            onChanged: board.setPriorityFilter,
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            hint: 'Due Date',
            value: board.dueFilter,
            items: const {
              null: 'Any due',
              'overdue': 'Overdue',
              'today': 'Due today',
              'week': 'Due this week',
            },
            onChanged: board.setDueFilter,
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 22, color: AppColors.border),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final label in labels)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _LabelFilterChip(
                        label: label,
                        selected: board.labelFilter == label.id,
                        onTap: () => board.setLabelFilter(
                            board.labelFilter == label.id ? null : label.id),
                      ),
                    ),
                  _GhostChip(icon: Icons.add, text: 'Label', onTap: () => _createLabel(context)),
                ],
              ),
            ),
          ),
          if (board.hasFilters)
            TextButton.icon(
              onPressed: () {
                searchController.clear();
                board.clearFilters();
              },
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Future<void> _createLabel(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Label name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      await context.read<LabelsProvider>().create(name.trim());
    }
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String hint;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.accent : AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          dropdownColor: AppColors.surface,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            for (final entry in items.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _LabelFilterChip extends StatelessWidget {
  final Label label;
  final bool selected;
  final VoidCallback onTap;

  const _LabelFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _hex(label.color);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: selected ? 0.7 : 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label.name,
                style: TextStyle(fontSize: 12.5, color: Color.lerp(color, Colors.white, 0.35))),
          ],
        ),
      ),
    );
  }

  Color _hex(String? hex) {
    if (hex == null) return AppColors.accent;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF6366F1);
  }
}

class _GhostChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _GhostChip({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final String status;
  final String title;
  final List<Task> tasks;
  final Map<int, String> assigneeNames;
  final VoidCallback onAddTask;
  final void Function(Task) onOpenTask;

  const _BoardColumn({
    required this.status,
    required this.title,
    required this.tasks,
    required this.assigneeNames,
    required this.onAddTask,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.status(status);
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) =>
          context.read<BoardProvider>().moveToColumn(details.data, status),
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return Container(
          color: highlighted ? AppColors.accent.withValues(alpha: 0.05) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${tasks.length}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'Add task',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAddTask,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? _EmptyColumn(onAddTask: onAddTask)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: tasks.length + 1,
                        itemBuilder: (context, index) {
                          if (index == tasks.length) {
                            return _AddTaskButton(onAddTask: onAddTask);
                          }
                          return _DraggableCard(
                            task: tasks[index],
                            assigneeName: assigneeNames[tasks[index].assigneeId],
                            onOpen: () => onOpenTask(tasks[index]),
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

class _EmptyColumn extends StatelessWidget {
  final VoidCallback onAddTask;
  const _EmptyColumn({required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_horiz, color: AppColors.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 6),
                  const Text('Nothing here yet', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _AddTaskButton(onAddTask: onAddTask),
        ],
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  final VoidCallback onAddTask;
  const _AddTaskButton({required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onAddTask,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 15, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text('Add Task', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// A card that is both draggable and a drop target. Dropping another card onto
/// it inserts that card immediately before this one.
class _DraggableCard extends StatelessWidget {
  final Task task;
  final String? assigneeName;
  final VoidCallback onOpen;

  const _DraggableCard({required this.task, required this.assigneeName, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.id != task.id,
      onAcceptWithDetails: (details) =>
          context.read<BoardProvider>().reorderBefore(details.data, task),
      builder: (context, candidateData, rejectedData) {
        final card = Draggable<Task>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 260,
              child: TaskCard(task: task, assigneeName: assigneeName, dragging: true),
            ),
          ),
          childWhenDragging:
              Opacity(opacity: 0.3, child: TaskCard(task: task, assigneeName: assigneeName)),
          child: TaskCard(task: task, assigneeName: assigneeName, onTap: onOpen),
        );
        if (candidateData.isEmpty) return card;
        return Column(
          children: [
            Container(
              height: 2.5,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            card,
          ],
        );
      },
    );
  }
}
