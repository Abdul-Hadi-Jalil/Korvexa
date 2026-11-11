import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace.dart';
import '../providers/dashboard_provider.dart';
import '../providers/labels_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/projects_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../services/workspaces_service.dart';
import '../theme/app_colors.dart';
import '../widgets/key_avatar.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'members_screen.dart';
import 'my_tasks_screen.dart';
import 'notifications_screen.dart';
import 'projects_list_screen.dart';
import 'search_screen.dart';

/// Authenticated app shell. On wide screens it renders a persistent left
/// sidebar (workspace, nav, user) + a top bar with global search; on narrow
/// screens it falls back to a top app bar + bottom navigation. Dashboard,
/// Projects, My Tasks and Calendar are hosted in an [IndexedStack]; Team and
/// Notifications are pushed routes.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _projectsKey = GlobalKey<ProjectsListViewState>();

  static const _wideBreakpoint = 960.0;
  static const _titles = ['Dashboard', 'Projects', 'My Tasks', 'Calendar'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().refreshUnreadCount();
      context.read<DashboardProvider>().load();
    });
  }

  Future<void> _switchWorkspace(int workspaceId) async {
    final session = context.read<SessionController>();
    if (session.currentWorkspaceId == workspaceId) return;
    final projects = context.read<ProjectsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final labels = context.read<LabelsProvider>();
    final notifications = context.read<NotificationsProvider>();
    final dashboard = context.read<DashboardProvider>();

    await session.switchWorkspace(workspaceId);
    await projects.load();
    await upcoming.load();
    await labels.load(force: true);
    await notifications.refreshUnreadCount();
    await dashboard.load();
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

  void _openMembers() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MembersScreen()),
      );

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) await context.read<NotificationsProvider>().refreshUnreadCount();
  }

  void _openSearch([String query = '']) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query)),
      );

  void _newProject() {
    setState(() => _index = 1);
    _projectsKey.currentState?.showCreateDialog();
  }

  Widget get _body => IndexedStack(
        index: _index,
        children: [
          const DashboardView(),
          ProjectsListView(key: _projectsKey),
          const MyTasksView(),
          const CalendarView(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    return wide ? _buildWide(context) : _buildNarrow(context);
  }

  // ---- Wide layout: sidebar + top bar ----
  Widget _buildWide(BuildContext context) {
    final session = context.watch<SessionController>();
    final unread = context.watch<NotificationsProvider>().unread;
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _index,
            workspaces: session.workspaces,
            current: session.currentWorkspace,
            userEmail: session.currentUser?.email ?? '',
            userName: session.currentUser?.name ?? '',
            unread: unread,
            onSelectIndex: (i) => setState(() => _index = i),
            onNewProject: _newProject,
            onTeam: _openMembers,
            onNotifications: _openNotifications,
            onSwitchWorkspace: _switchWorkspace,
            onCreateWorkspace: _createWorkspace,
            onLogout: () => context.read<SessionController>().logout(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: _titles[_index],
                  onSearch: _openSearch,
                  onNotifications: _openNotifications,
                  onMembers: _openMembers,
                  onLogout: () => context.read<SessionController>().logout(),
                  email: session.currentUser?.email ?? '',
                ),
                const Divider(height: 1),
                Expanded(child: _body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Narrow layout: app bar + bottom nav ----
  Widget _buildNarrow(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: _WorkspaceSwitcher(
          workspaces: session.workspaces,
          current: session.currentWorkspace,
          onSelect: _switchWorkspace,
          onCreate: _createWorkspace,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _openSearch(),
          ),
          _NotificationBell(onOpen: _openNotifications),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'members') _openMembers();
              if (value == 'logout') context.read<SessionController>().logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(session.currentUser?.email ?? '')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'members', child: Text('Members')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: _body,
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: _newProject,
              icon: const Icon(Icons.add),
              label: const Text('New project'),
              backgroundColor: AppColors.lavender,
              foregroundColor: AppColors.onLavender,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.sidebar,
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Calendar'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<Workspace> workspaces;
  final Workspace? current;
  final String userEmail;
  final String userName;
  final int unread;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onNewProject;
  final VoidCallback onTeam;
  final VoidCallback onNotifications;
  final ValueChanged<int> onSwitchWorkspace;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selectedIndex,
    required this.workspaces,
    required this.current,
    required this.userEmail,
    required this.userName,
    required this.unread,
    required this.onSelectIndex,
    required this.onNewProject,
    required this.onTeam,
    required this.onNotifications,
    required this.onSwitchWorkspace,
    required this.onCreateWorkspace,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final wsName = current?.name ?? 'Korvexa';
    return Container(
      width: 248,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workspace header (tap to switch / create).
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 12, 12),
            child: PopupMenuButton<int>(
              tooltip: 'Switch workspace',
              onSelected: (v) => v == -1 ? onCreateWorkspace() : onSwitchWorkspace(v),
              itemBuilder: (_) => [
                ...workspaces.map((ws) => PopupMenuItem(
                      value: ws.id,
                      child: Row(
                        children: [
                          Icon(
                            ws.id == current?.id ? Icons.check : Icons.circle_outlined,
                            size: 15,
                            color: ws.id == current?.id ? AppColors.accent : AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(ws.name, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    )),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: -1,
                  child: Row(children: [
                    Icon(Icons.add, size: 15, color: AppColors.accent),
                    SizedBox(width: 10),
                    Text('New workspace'),
                  ]),
                ),
              ],
              child: Row(
                children: [
                  KeyAvatar(label: wsName, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wsName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          current?.isOwner == true ? 'Owner' : 'Workspace',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          // Primary action.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNewProject,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Project'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Nav.
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: selectedIndex == 0,
            onTap: () => onSelectIndex(0),
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Projects',
            selected: selectedIndex == 1,
            onTap: () => onSelectIndex(1),
          ),
          _NavItem(
            icon: Icons.check_circle_outline,
            label: 'My Tasks',
            selected: selectedIndex == 2,
            onTap: () => onSelectIndex(2),
          ),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            label: 'Calendar',
            selected: selectedIndex == 3,
            onTap: () => onSelectIndex(3),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Divider(height: 1),
          ),
          _NavItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            selected: false,
            badge: unread,
            onTap: onNotifications,
          ),
          _NavItem(
            icon: Icons.group_outlined,
            label: 'Team',
            selected: false,
            onTap: onTeam,
          ),
          const Spacer(),
          const Divider(height: 1),
          // User footer.
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.accentSubtle, shape: BoxShape.circle),
                  child: Text(
                    (userName.isNotEmpty ? userName : userEmail).characters.first.toUpperCase(),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Log out',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? AppColors.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar (wide layout)
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final String title;
  final String email;
  final ValueChanged<String> onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMembers;
  final VoidCallback onLogout;

  const _TopBar({
    required this.title,
    required this.email,
    required this.onSearch,
    required this.onNotifications,
    required this.onMembers,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _SearchField(onSubmit: onSearch),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _NotificationBell(onOpen: onNotifications),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
            onSelected: (value) {
              if (value == 'members') onMembers();
              if (value == 'logout') onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(email)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'members', child: Text('Members')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onSubmit;
  const _SearchField({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        readOnly: true,
        onTap: () => onSubmit(''),
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 18),
          hintText: 'Search tasks...',
        ),
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
                  if (ws.id == current?.id)
                    const Icon(Icons.check, size: 16, color: AppColors.accent)
                  else
                    const SizedBox(width: 16),
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
  final VoidCallback onOpen;
  const _NotificationBell({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsProvider>().unread;
    return IconButton(
      onPressed: onOpen,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
      ),
    );
  }
}
