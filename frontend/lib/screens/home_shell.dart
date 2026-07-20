import 'package:flutter/material.dart';

import 'my_tasks_screen.dart';
import 'projects_list_screen.dart';

/// Root navigation: switches between the Projects list and My Tasks.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [ProjectsListScreen(), MyTasksScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
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
