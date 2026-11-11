import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/projects_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/key_avatar.dart';
import 'board_screen.dart';

/// Body-only projects view: a header with a "Show archived" toggle and a
/// responsive grid of project cards (+ a "Create New Project" tile). The outer
/// shell provides navigation; `showCreateDialog()` is called by the shell's
/// primary action.
class ProjectsListView extends StatefulWidget {
  const ProjectsListView({super.key});

  @override
  State<ProjectsListView> createState() => ProjectsListViewState();
}

class ProjectsListViewState extends State<ProjectsListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectsProvider>().load();
    });
  }

  Future<void> showCreateDialog() async {
    final nameController = TextEditingController();
    final keyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New project'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Key (optional)',
                  hintText: 'Auto-derived from name if left blank',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true && mounted) {
      final ok = await context.read<ProjectsProvider>().create(
            name: nameController.text.trim(),
            key: keyController.text.trim().isEmpty ? null : keyController.text.trim(),
          );
      if (!ok && mounted) _showError(context.read<ProjectsProvider>().error);
    }
  }

  Future<void> _confirmDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text('"${project.name}" and all of its tasks will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await context.read<ProjectsProvider>().delete(project.id);
      if (!ok && mounted) _showError(context.read<ProjectsProvider>().error);
    }
  }

  void _showError(String? message) {
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectsProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(provider),
            Expanded(
              child: provider.loading && provider.projects.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      child: _grid(provider),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(ProjectsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Projects',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Manage and track all active initiatives.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          Row(
            children: [
              Switch(value: provider.includeArchived, onChanged: provider.setIncludeArchived),
              const SizedBox(width: 6),
              const Text('Show archived', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: showCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _grid(ProjectsProvider provider) {
    return GridView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 168,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      children: [
        for (final project in provider.projects)
          _ProjectCard(
            project: project,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BoardScreen(project: project)),
            ),
            onArchive: () => context.read<ProjectsProvider>().archive(project.id),
            onUnarchive: () => context.read<ProjectsProvider>().unarchive(project.id),
            onDelete: () => _confirmDelete(project),
          ),
        _CreateProjectCard(onTap: showCreateDialog),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onArchive,
    required this.onUnarchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.forKey(project.key);
    final total = project.totalTasks;
    final done = total - project.openTasks;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KeyAvatar(label: project.key, size: 40, color: tint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (project.archived) ...[
                                const SizedBox(width: 8),
                                _Pill(text: 'Archived'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('KEY: ${project.key}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11.5, letterSpacing: 0.4)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 20, color: AppColors.textMuted),
                      onSelected: (value) {
                        switch (value) {
                          case 'archive':
                            onArchive();
                          case 'unarchive':
                            onUnarchive();
                          case 'delete':
                            onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        if (project.archived)
                          const PopupMenuItem(value: 'unarchive', child: Text('Unarchive'))
                        else
                          const PopupMenuItem(value: 'archive', child: Text('Archive')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text('Progress', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    const Spacer(),
                    Text('${project.openTasks}/${project.totalTasks} open',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHover,
                    valueColor: AlwaysStoppedAnimation(tint),
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

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
    );
  }
}

class _CreateProjectCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateProjectCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: DottedBorderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.surfaceHover, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            const Text('Create New Project',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// A rounded box with a dashed border, painted via [CustomPaint].
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Center(child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
