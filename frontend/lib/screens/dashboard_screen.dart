import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_stats.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_colors.dart';

/// Body-only workspace overview: KPI stat cards, a status breakdown bar, and a
/// priority breakdown. Data comes from GET /dashboard.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final stats = provider.stats;
        return RefreshIndicator(
          onRefresh: provider.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            children: [
              const Text('Dashboard',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('An overview of your workspace.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              if (provider.loading && stats == null)
                const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
              else if (provider.error != null && stats == null)
                _errorState(provider.error!)
              else if (stats != null) ...[
                _statCards(stats),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _statusPanel(stats)),
                    const SizedBox(width: 16),
                    Expanded(child: _priorityPanel(stats)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _errorState(String message) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(child: Text(message, style: const TextStyle(color: AppColors.danger))),
      );

  Widget _statCards(DashboardStats s) {
    final cards = [
      _Stat('Active Projects', s.projectsActive, Icons.folder_outlined, AppColors.accent),
      _Stat('Open Tasks', s.tasksTotal - s.tasksDone, Icons.checklist_outlined, AppColors.statusInProgress),
      _Stat('Assigned to Me', s.assignedToMeOpen, Icons.person_outline, AppColors.statusDone),
      _Stat('Overdue', s.tasksOverdue, Icons.warning_amber_rounded, AppColors.danger),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 4 : (constraints.maxWidth >= 520 ? 2 : 1);
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final c in cards) SizedBox(width: width, child: _StatCard(stat: c))],
      );
    });
  }

  Widget _statusPanel(DashboardStats s) {
    final total = s.tasksTotal == 0 ? 1 : s.tasksTotal;
    return _Panel(
      title: 'Tasks by status',
      child: Column(
        children: [
          _StatusBar(label: 'To Do', count: s.tasksTodo, total: total, color: AppColors.statusTodo),
          const SizedBox(height: 14),
          _StatusBar(label: 'In Progress', count: s.tasksInProgress, total: total, color: AppColors.statusInProgress),
          const SizedBox(height: 14),
          _StatusBar(label: 'Done', count: s.tasksDone, total: total, color: AppColors.statusDone),
        ],
      ),
    );
  }

  Widget _priorityPanel(DashboardStats s) {
    final total = (s.priorityHigh + s.priorityMedium + s.priorityLow);
    final t = total == 0 ? 1 : total;
    return _Panel(
      title: 'Open tasks by priority',
      child: Column(
        children: [
          _StatusBar(label: 'High', count: s.priorityHigh, total: t, color: AppColors.priorityHigh),
          const SizedBox(height: 14),
          _StatusBar(label: 'Medium', count: s.priorityMedium, total: t, color: AppColors.priorityMedium),
          const SizedBox(height: 14),
          _StatusBar(label: 'Low', count: s.priorityLow, total: t, color: AppColors.priorityLow),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, size: 20, color: stat.color),
          ),
          const SizedBox(height: 14),
          Text('${stat.value}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(stat.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusBar({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const Spacer(),
            Text('$count', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : count / total,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHover,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
