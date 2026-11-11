import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../services/workspaces_service.dart';
import '../theme/app_colors.dart';

/// Workspace members list with invite (owner-only actions guarded by the
/// backend; the UI also hides them for non-owners).
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late final WorkspacesService _service;
  List<Member> _members = [];
  bool _loading = true;
  String? _error;

  int get _workspaceId => context.read<SessionController>().currentWorkspaceId!;

  @override
  void initState() {
    super.initState();
    _service = WorkspacesService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await _service.members(_workspaceId);
      setState(() {
        _members = members;
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite by email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await _service.invite(_workspaceId, email: email.trim());
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changeRole(Member member, String role) async {
    try {
      await _service.updateRole(_workspaceId, member.userId, role);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(Member member) async {
    try {
      await _service.removeMember(_workspaceId, member.userId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isOwner = session.currentWorkspace?.isOwner ?? false;
    final myUserId = session.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: _invite,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite'),
              backgroundColor: AppColors.lavender,
              foregroundColor: AppColors.onLavender)
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.accentSubtle, shape: BoxShape.circle),
                        child: Text(member.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(member.name),
                      subtitle: Text(member.email, style: const TextStyle(color: AppColors.textMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoleBadge(role: member.role),
                          if (isOwner && member.userId != myUserId)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'make_owner':
                                    _changeRole(member, 'owner');
                                  case 'make_member':
                                    _changeRole(member, 'member');
                                  case 'remove':
                                    _remove(member);
                                }
                              },
                              itemBuilder: (_) => [
                                if (member.role != 'owner')
                                  const PopupMenuItem(value: 'make_owner', child: Text('Make owner'))
                                else
                                  const PopupMenuItem(value: 'make_member', child: Text('Make member')),
                                const PopupMenuItem(value: 'remove', child: Text('Remove')),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final owner = role == 'owner';
    final color = owner ? AppColors.accent : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        owner ? 'Owner' : 'Member',
        style: TextStyle(color: Color.lerp(color, Colors.white, 0.2), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
