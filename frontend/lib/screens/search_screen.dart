import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../services/search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/key_avatar.dart';
import 'task_detail_screen.dart';

/// Full-page workspace-wide task search (GET /search/tasks). Live, debounced.
class SearchScreen extends StatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SearchService _service;
  late final TextEditingController _controller;
  Timer? _debounce;
  List<Task> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _service = SearchService(context.read<ApiClient>());
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().isNotEmpty) _run(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _service.tasks(q);
      if (mounted) setState(() => _results = results);
    } on ApiException {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _searched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontSize: 15),
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Search tasks across the workspace...',
          ),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _run('');
              },
            ),
        ],
      ),
      body: _loading && _results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const _Hint()
              : _results.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ResultRow(task: _results[index]),
                    ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Task task;
  const _ResultRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final key = task.projectKey ?? '';
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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                KeyAvatar(label: key.isEmpty ? task.key : key, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text('${task.projectName ?? ''} · ${task.key}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: task.status == TaskStatus.done
                        ? AppColors.statusDone
                        : AppColors.priority(task.priority),
                    shape: BoxShape.circle,
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

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('Search tasks by title or description',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('No matching tasks.', style: TextStyle(color: AppColors.textSecondary)),
      );
}
