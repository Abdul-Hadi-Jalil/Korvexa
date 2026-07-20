import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment.dart';
import '../services/api_client.dart';
import '../services/comments_service.dart';

/// Self-contained comments panel for a task: lists comments, adds new ones,
/// and edits/deletes existing ones. Takes a CommentsService so it can be
/// dropped into any screen (and tested with a fake client).
class CommentsSection extends StatefulWidget {
  final int taskId;
  final CommentsService service;

  const CommentsSection({super.key, required this.taskId, required this.service});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _controller = TextEditingController();
  final _dateFormat = DateFormat('MMM d, HH:mm');
  List<Comment> _comments = [];
  bool _loading = true;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comments = await widget.service.list(widget.taskId);
      setState(() {
        _comments = comments;
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      final comment = await widget.service.create(widget.taskId, body);
      setState(() {
        _comments = [..._comments, comment];
        _controller.clear();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _edit(Comment comment) async {
    final controller = TextEditingController(text: comment.body);
    final newBody = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(controller: controller, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newBody == null || newBody.trim().isEmpty) return;
    try {
      final updated = await widget.service.update(comment.id, newBody.trim());
      setState(() {
        _comments = _comments.map((c) => c.id == updated.id ? updated : c).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _delete(Comment comment) async {
    try {
      await widget.service.delete(comment.id);
      setState(() => _comments = _comments.where((c) => c.id != comment.id).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_loading)
          const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
        else if (_comments.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No comments yet.'))
        else
          ..._comments.map(_commentTile),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Add a comment',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _posting ? null : _add,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _commentTile(Comment comment) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(comment.body),
      subtitle: Text('${comment.authorName ?? 'Someone'} · ${_dateFormat.format(comment.createdAt.toLocal())}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? _edit(comment) : _delete(comment),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
