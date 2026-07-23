import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import 'task_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _dateFormat = DateFormat('MMM d, HH:mm');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationsProvider>().markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.notifications.isEmpty) {
            return const Center(child: Text('No notifications.'));
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView.separated(
              itemCount: provider.notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = provider.notifications[index];
                return ListTile(
                  leading: Icon(
                    n.type == 'assigned' ? Icons.assignment_ind : Icons.alternate_email,
                    color: n.read ? Colors.grey : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    n.message,
                    style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Text(_dateFormat.format(n.createdAt.toLocal())),
                  onTap: () async {
                    await context.read<NotificationsProvider>().markRead(n.id);
                    if (n.taskId != null && context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: n.taskId!)),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
