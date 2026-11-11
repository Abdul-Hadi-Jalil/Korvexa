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
import '../theme/app_colors.dart';
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
          titleSpacing: 8,
          title: _task == null
              ? const Text('Task')
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_task!.key,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
          actions: [
            IconButton(
              tooltip: 'Delete task',
              icon: const Icon(Icons.delete_outline),
              onPressed: _loading ? null : _delete,
            ),
            const SizedBox(width: 4),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (_error != null) ...[
            _errorBanner(_error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _titleController,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Task title',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, height: 1.4),
            decoration: const InputDecoration(hintText: 'Add a description...'),
          ),
          const SizedBox(height: 20),
          _fieldsPanel(),
          const SizedBox(height: 24),
          _sectionLabel('LABELS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final l in _labels) LabelChip(label: l),
              _addLabelButton(),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save changes'),
          ),
          const SizedBox(height: 8),
          const Divider(height: 32),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          CommentsSection(
            taskId: widget.taskId,
            service: CommentsService(context.read<ApiClient>()),
          ),
        ],
      ),
    );
  }

  Widget _fieldsPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statusField()),
              const SizedBox(width: 16),
              Expanded(child: _priorityField()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _assigneeField()),
              const SizedBox(width: 16),
              Expanded(child: _dueField()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(IconData icon, String label, Widget control) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(child: Align(alignment: Alignment.centerRight, child: control)),
      ],
    );
  }

  Widget _statusField() => _fieldRow(
        Icons.radio_button_unchecked,
        'Status',
        _compactDropdown<String>(
          value: _status,
          items: {for (final s in TaskStatus.all) s: TaskStatus.label(s)},
          leadingColor: (v) => AppColors.status(v),
          onChanged: (v) => setState(() => _status = v!),
        ),
      );

  Widget _priorityField() => _fieldRow(
        Icons.flag_outlined,
        'Priority',
        _compactDropdown<String>(
          value: _priority,
          items: {for (final p in TaskPriority.all) p: TaskPriority.label(p)},
          leadingColor: (v) => AppColors.priority(v),
          onChanged: (v) => setState(() => _priority = v!),
        ),
      );

  Widget _assigneeField() => _fieldRow(
        Icons.person_outline,
        'Assignee',
        _compactDropdown<int?>(
          value: _assigneeId,
          items: {null: 'Unassigned', for (final m in _members) m.userId: m.name},
          onChanged: (v) => setState(() => _assigneeId = v),
        ),
      );

  Widget _dueField() => _fieldRow(
        Icons.calendar_today_outlined,
        'Due Date',
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _pickDueDate,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: _dueDate == null ? AppColors.textMuted : AppColors.textPrimary,
              ),
              child: Text(_dueDate == null ? 'None' : _dateFormat.format(_dueDate!)),
            ),
            if (_dueDate != null)
              InkWell(
                onTap: () => setState(() => _dueDate = null),
                child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
              ),
          ],
        ),
      );

  Widget _compactDropdown<T>({
    required T value,
    required Map<T, String> items,
    Color Function(T)? leadingColor,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        alignment: Alignment.centerRight,
        icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
        dropdownColor: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: leadingColor(entry.key), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: Text(entry.value, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );

  Widget _addLabelButton() => InkWell(
        onTap: _editLabels,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.add, size: 15, color: AppColors.textSecondary),
        ),
      );

  Widget _errorBanner(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
      );
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
