import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../models/workspace.dart';
import '../providers/labels_provider.dart';
import '../services/activity_service.dart';
import '../services/api_client.dart';
import '../services/comments_service.dart';
import '../services/session.dart';
import '../services/tasks_service.dart';
import '../services/workspaces_service.dart';
import '../widgets/activity_timeline.dart';
import '../widgets/comments_section.dart';
import '../widgets/label_chip.dart';

/// Full task view: editable fields + labels + comments on the Details tab,
/// and the mutation history on the Activity tab.
class TaskDetailScreen extends StatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TasksService _tasks;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Task? _task;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _status = TaskStatus.todo;
  String _priority = TaskPriority.medium;
  DateTime? _dueDate;
  List<Label> _labels = [];
  int? _assigneeId;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _tasks = TasksService(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<LabelsProvider>().load());
    _loadMembers();
    _load();
  }

  Future<void> _loadMembers() async {
    final workspaceId = context.read<SessionController>().currentWorkspaceId;
    if (workspaceId == null) return;
    try {
      final members = await WorkspacesService(context.read<ApiClient>()).members(workspaceId);
      if (mounted) setState(() => _members = members);
    } on ApiException {
      // Non-fatal: the assignee dropdown just won't have options.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final task = await _tasks.get(widget.taskId);
      setState(() {
        _task = task;
        _titleController.text = task.title;
        _descriptionController.text = task.description ?? '';
        _status = task.status;
        _priority = task.priority;
        _dueDate = task.dueDate;
        _labels = task.labels;
        _assigneeId = task.assigneeId;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _tasks.update(widget.taskId, {
        'title': _titleController.text.trim(),
        'description':
            _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'status': _status,
        'priority': _priority,
        'due_date': _dueDate == null ? null : _dateFormat.format(_dueDate!),
        'assignee_id': _assigneeId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _tasks.delete(widget.taskId);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _editLabels() async {
    final all = context.read<LabelsProvider>().labels;
    final selected = {..._labels.map((l) => l.id)};
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => _LabelPickerDialog(all: all, selected: selected),
    );
    if (result == null) return;
    try {
      final updated = await _tasks.setLabels(widget.taskId, result.toList());
      setState(() => _labels = updated.labels);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_task?.key ?? 'Task'),
          actions: [
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _loading ? null : _delete),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Details'), Tab(text: 'Activity')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _task == null
                ? Center(child: Text(_error ?? 'Task not found'))
                : TabBarView(
                    children: [
                      _detailsTab(),
                      ActivityTimeline(
                        taskId: widget.taskId,
                        service: ActivityService(context.read<ApiClient>()),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _detailsTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: TaskStatus.all
                .map((s) => DropdownMenuItem(value: s, child: Text(TaskStatus.label(s))))
                .toList(),
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: TaskPriority.all
                .map((p) => DropdownMenuItem(value: p, child: Text(TaskPriority.label(p))))
                .toList(),
            onChanged: (v) => setState(() => _priority = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _assigneeId,
            decoration: const InputDecoration(labelText: 'Assignee'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
              ..._members.map(
                (m) => DropdownMenuItem<int?>(value: m.userId, child: Text(m.name)),
              ),
            ],
            onChanged: (value) => setState(() => _assigneeId = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(_dueDate == null ? 'No due date' : 'Due ${_dateFormat.format(_dueDate!)}'),
              ),
              TextButton(onPressed: _pickDueDate, child: const Text('Pick date')),
              if (_dueDate != null)
                TextButton(onPressed: () => setState(() => _dueDate = null), child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Labels', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(onPressed: _editLabels, icon: const Icon(Icons.edit, size: 16), label: const Text('Edit')),
            ],
          ),
          if (_labels.isEmpty)
            const Text('No labels')
          else
            Wrap(spacing: 6, children: [for (final l in _labels) LabelChip(label: l)]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
          const Divider(height: 32),
          CommentsSection(
            taskId: widget.taskId,
            service: CommentsService(context.read<ApiClient>()),
          ),
        ],
      ),
    );
  }
}

class _LabelPickerDialog extends StatefulWidget {
  final List<Label> all;
  final Set<int> selected;

  const _LabelPickerDialog({required this.all, required this.selected});

  @override
  State<_LabelPickerDialog> createState() => _LabelPickerDialogState();
}

class _LabelPickerDialogState extends State<_LabelPickerDialog> {
  late final Set<int> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Labels'),
      content: widget.all.isEmpty
          ? const Text('No labels in this workspace yet. Create some from the board filter bar.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: widget.all
                    .map((label) => CheckboxListTile(
                          title: Text(label.name),
                          value: _selected.contains(label.id),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(label.id);
                            } else {
                              _selected.remove(label.id);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_selected), child: const Text('Apply')),
      ],
    );
  }
}
