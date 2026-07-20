import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/board_provider.dart';
import '../providers/labels_provider.dart';
import '../services/api_client.dart';
import '../services/tasks_service.dart';
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
    });
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
          decoration: const InputDecoration(labelText: 'Title'),
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
    return Scaffold(
      appBar: AppBar(title: Text('${widget.project.name} (${widget.project.key})')),
      body: Consumer<BoardProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _FilterBar(searchController: _searchController),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(provider.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(
                child: provider.loading && provider.columns.values.every((l) => l.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: TaskStatus.all
                            .map((status) => Expanded(
                                  child: _BoardColumn(
                                    status: status,
                                    title: _columnTitles[status]!,
                                    tasks: provider.columns[status] ?? const [],
                                    onAddTask: () => _promptNewTask(context, status),
                                    onOpenTask: (task) => _openTask(context, task),
                                  ),
                                ))
                            .toList(),
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
    // Always refresh on return: title/labels/status may have changed.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search tasks',
                    border: const OutlineInputBorder(),
                    suffixIcon: board.search == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              board.setSearch(null);
                            },
                          ),
                  ),
                  onSubmitted: (value) => board.setSearch(value),
                ),
              ),
              if (board.hasFilters)
                IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: () {
                    searchController.clear();
                    board.clearFilters();
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _priorityDropdown(board),
                const SizedBox(width: 8),
                _dueDropdown(board),
                const SizedBox(width: 8),
                ..._labelFilterChips(board, labels),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Label'),
                  onPressed: () => _createLabel(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityDropdown(BoardProvider board) {
    return DropdownButton<String?>(
      value: board.priorityFilter,
      hint: const Text('Priority'),
      items: const [
        DropdownMenuItem(value: null, child: Text('Any priority')),
        DropdownMenuItem(value: TaskPriority.high, child: Text('High')),
        DropdownMenuItem(value: TaskPriority.medium, child: Text('Medium')),
        DropdownMenuItem(value: TaskPriority.low, child: Text('Low')),
      ],
      onChanged: board.setPriorityFilter,
    );
  }

  Widget _dueDropdown(BoardProvider board) {
    return DropdownButton<String?>(
      value: board.dueFilter,
      hint: const Text('Due'),
      items: const [
        DropdownMenuItem(value: null, child: Text('Any due')),
        DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
        DropdownMenuItem(value: 'today', child: Text('Due today')),
        DropdownMenuItem(value: 'week', child: Text('Due this week')),
      ],
      onChanged: board.setDueFilter,
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
          decoration: const InputDecoration(labelText: 'Name'),
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

  List<Widget> _labelFilterChips(BoardProvider board, List<Label> labels) {
    return labels.map((label) {
      final selected = board.labelFilter == label.id;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          label: Text(label.name),
          selected: selected,
          onSelected: (value) => board.setLabelFilter(value ? label.id : null),
        ),
      );
    }).toList();
  }
}

class _BoardColumn extends StatelessWidget {
  final String status;
  final String title;
  final List<Task> tasks;
  final VoidCallback onAddTask;
  final void Function(Task) onOpenTask;

  const _BoardColumn({
    required this.status,
    required this.title,
    required this.tasks,
    required this.onAddTask,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      // Column-level target = "move to end of this column" (only meaningful
      // when dropping from a different column).
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) =>
          context.read<BoardProvider>().moveToColumn(details.data, status),
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
                    Flexible(
                      child: Text('$title (${tasks.length})',
                          style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    ),
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
                  itemBuilder: (context, index) => _DraggableCard(
                    task: tasks[index],
                    onOpen: () => onOpenTask(tasks[index]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A card that is both draggable and a drop target. Dropping another card
/// onto it inserts that card immediately before this one (reorder within a
/// column, or move-across-columns-and-position).
class _DraggableCard extends StatelessWidget {
  final Task task;
  final VoidCallback onOpen;

  const _DraggableCard({required this.task, required this.onOpen});

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
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 240, child: TaskCard(task: task)),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: TaskCard(task: task)),
          child: TaskCard(task: task, onTap: onOpen),
        );
        if (candidateData.isEmpty) return card;
        // Show an insertion indicator above the hovered card.
        return Column(
          children: [
            Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: Theme.of(context).colorScheme.primary),
            card,
          ],
        );
      },
    );
  }
}
