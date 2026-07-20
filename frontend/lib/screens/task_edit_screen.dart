import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../services/tasks_service.dart';

class TaskEditScreen extends StatefulWidget {
  final int taskId;

  const TaskEditScreen({super.key, required this.taskId});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final TasksService _service;
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

  @override
  void initState() {
    super.initState();
    _service = TasksService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task = await _service.get(widget.taskId);
      setState(() {
        _task = task;
        _titleController.text = task.title;
        _descriptionController.text = task.description ?? '';
        _status = task.status;
        _priority = task.priority;
        _dueDate = task.dueDate;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.update(widget.taskId, {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'status': _status,
        'priority': _priority,
        'due_date': _dueDate == null ? null : _dateFormat.format(_dueDate!),
      });
      if (mounted) Navigator.of(context).pop(true);
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
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
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
      await _service.delete(widget.taskId);
      if (mounted) Navigator.of(context).pop(true);
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_task == null ? 'Task' : _task!.key),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _loading ? null : _delete),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? Center(child: Text(_error ?? 'Task not found'))
              : Form(
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
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: TaskStatus.all
                            .map((s) => DropdownMenuItem(value: s, child: Text(TaskStatus.label(s))))
                            .toList(),
                        onChanged: (value) => setState(() => _status = value!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: TaskPriority.all
                            .map((p) => DropdownMenuItem(value: p, child: Text(TaskPriority.label(p))))
                            .toList(),
                        onChanged: (value) => setState(() => _priority = value!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dueDate == null ? 'No due date' : 'Due ${_dateFormat.format(_dueDate!)}',
                            ),
                          ),
                          TextButton(onPressed: _pickDueDate, child: const Text('Pick date')),
                          if (_dueDate != null)
                            TextButton(
                              onPressed: () => setState(() => _dueDate = null),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
