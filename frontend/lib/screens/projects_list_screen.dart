import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../providers/projects_provider.dart';
import 'board_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectsProvider>().load();
    });
  }

  Future<void> _showCreateDialog() async {
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
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
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
      if (!ok && mounted) {
        _showError(context.read<ProjectsProvider>().error);
      }
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<ProjectsProvider>().delete(project.id);
      if (!ok && mounted) {
        _showError(context.read<ProjectsProvider>().error);
      }
    }
  }

  void _showError(String? message) {
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Consumer<ProjectsProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.projects.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No projects yet.'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first project'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            child: ListView.builder(
              itemCount: provider.projects.length,
              itemBuilder: (context, index) {
                final project = provider.projects[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(project.key.substring(0, 1))),
                  title: Text(project.name),
                  subtitle: Text('${project.key} · ${project.openTasks}/${project.totalTasks} open'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(project),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BoardScreen(project: project)),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: 'New project',
        child: const Icon(Icons.add),
      ),
    );
  }
}
