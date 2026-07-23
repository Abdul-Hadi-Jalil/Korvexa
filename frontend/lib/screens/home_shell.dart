import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace.dart';
import '../providers/labels_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/projects_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../services/workspaces_service.dart';
import 'members_screen.dart';
import 'my_tasks_screen.dart';
import 'notifications_screen.dart';
import 'projects_list_screen.dart';

/// Authenticated app shell: owns the AppBar (workspace switcher, notification
/// bell, account menu) and bottom navigation. The two tabs are body-only
/// views.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _projectsKey = GlobalKey<ProjectsListViewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().refreshUnreadCount();
    });
  }

  /// When the active workspace changes, every workspace-scoped provider must
  /// reload so we don't show the previous tenant's data.
  Future<void> _switchWorkspace(int workspaceId) async {
    final session = context.read<SessionController>();
    if (session.currentWorkspaceId == workspaceId) return;
    // Capture all workspace-scoped providers up front so we don't touch
    // context across the awaits below.
    final projects = context.read<ProjectsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final labels = context.read<LabelsProvider>();
    final notifications = context.read<NotificationsProvider>();

    await session.switchWorkspace(workspaceId);
    await projects.load();
    await upcoming.load();
    await labels.load(force: true);
    await notifications.refreshUnreadCount();
  }

  Future<void> _createWorkspace() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New workspace'),
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
    if (name == null || name.trim().isEmpty) return;
    if (!mounted) return;
    final session = context.read<SessionController>();
    final service = WorkspacesService(context.read<ApiClient>());
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ws = await service.create(name.trim());
      await session.refreshWorkspaces();
      await _switchWorkspace(ws.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      appBar: AppBar(
        title: _WorkspaceSwitcher(
          workspaces: session.workspaces,
          current: session.currentWorkspace,
          onSelect: _switchWorkspace,
          onCreate: _createWorkspace,
        ),
        actions: [
          const _NotificationBell(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              switch (value) {
                case 'members':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MembersScreen()),
                  );
                case 'logout':
                  context.read<SessionController>().logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(session.currentUser?.email ?? ''),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'members', child: Text('Members')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          ProjectsListView(key: _projectsKey),
          const MyTasksView(),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () => _projectsKey.currentState?.showCreateDialog(),
              tooltip: 'New project',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'My Tasks'),
        ],
      ),
    );
  }
}

class _WorkspaceSwitcher extends StatelessWidget {
  final List<Workspace> workspaces;
  final Workspace? current;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  const _WorkspaceSwitcher({
    required this.workspaces,
    required this.current,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: (value) => value == -1 ? onCreate() : onSelect(value),
      itemBuilder: (_) => [
        ...workspaces.map((ws) => PopupMenuItem(
              value: ws.id,
              child: Row(
                children: [
                  if (ws.id == current?.id) const Icon(Icons.check, size: 16) else const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(ws.name),
                ],
              ),
            )),
        const PopupMenuDivider(),
        const PopupMenuItem(value: -1, child: Text('+ New workspace')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(current?.name ?? 'Korvexa', overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsProvider>().unread;
    return IconButton(
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        if (context.mounted) {
          await context.read<NotificationsProvider>().refreshUnreadCount();
        }
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
