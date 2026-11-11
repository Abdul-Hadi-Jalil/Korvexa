import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../services/me_service.dart';
import '../services/session.dart';
import '../theme/app_colors.dart';
import 'task_detail_screen.dart';

/// Body-only month calendar of task due dates (GET /me/calendar). Tapping a day
/// lists that day's tasks; tapping a task opens its detail.
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final MeService _service;
  late DateTime _month; // first day of the visible month
  DateTime _selected = _dateOnly(DateTime.now());
  Map<String, List<Task>> _byDay = {};
  bool _loading = false;
  int? _workspaceId;

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    _service = MeService(context.read<ApiClient>());
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  DateTime get _gridStart {
    final offset = _month.weekday % 7; // Sun=0, Mon=1, ... Sat=6
    return _month.subtract(Duration(days: offset));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = _gridStart;
      final end = start.add(const Duration(days: 41));
      final tasks = await _service.calendar(start, end);
      final map = <String, List<Task>>{};
      for (final t in tasks) {
        if (t.dueDate == null) continue;
        map.putIfAbsent(_key(t.dueDate!), () => []).add(t);
      }
      if (mounted) setState(() => _byDay = map);
    } on ApiException {
      // Non-fatal; the grid just shows no markers.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Reload when the active workspace changes (IndexedStack keeps us alive).
    final wsId = context.watch<SessionController>().currentWorkspaceId;
    if (_workspaceId != null && _workspaceId != wsId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    _workspaceId = wsId;

    final selectedTasks = _byDay[_key(_selected)] ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      children: [
        _header(),
        const SizedBox(height: 20),
        _weekdayRow(),
        const SizedBox(height: 6),
        _grid(),
        const SizedBox(height: 24),
        Text(
          DateFormat('EEEE, MMMM d').format(_selected),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (selectedTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tasks due on this day.', style: TextStyle(color: AppColors.textMuted)),
          )
        else
          ...selectedTasks.map(_taskRow),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Text('Calendar',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_loading)
          const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
        SizedBox(
          width: 150,
          child: Text(
            DateFormat('MMMM yyyy').format(_month),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            setState(() {
              final now = DateTime.now();
              _month = DateTime(now.year, now.month, 1);
              _selected = _dateOnly(now);
            });
            _load();
          },
          child: const Text('Today'),
        ),
      ],
    );
  }

  Widget _weekdayRow() {
    return Row(
      children: [
        for (final d in _weekdays)
          Expanded(
            child: Center(
              child: Text(d, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _grid() {
    final start = _gridStart;
    final today = _dateOnly(DateTime.now());
    return Column(
      children: [
        for (int week = 0; week < 6; week++)
          Row(
            children: [
              for (int day = 0; day < 7; day++)
                Expanded(child: _dayCell(start.add(Duration(days: week * 7 + day)), today)),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(DateTime date, DateTime today) {
    final inMonth = date.month == _month.month;
    final isToday = date == today;
    final isSelected = date == _selected;
    final tasks = _byDay[_key(date)] ?? const [];

    return GestureDetector(
      onTap: () => setState(() => _selected = date),
      child: Container(
        height: 68,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSubtle : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : (isToday ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: inMonth ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.5),
                fontSize: 12.5,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (tasks.isNotEmpty)
              Row(
                children: [
                  for (final t in tasks.take(4))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: t.status == TaskStatus.done
                            ? AppColors.statusDone
                            : AppColors.priority(t.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (tasks.length > 4)
                    Text('+${tasks.length - 4}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _taskRow(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
            );
            await _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            decoration:
                                task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                          )),
                      const SizedBox(height: 2),
                      Text('${task.projectName ?? ''} · ${task.key}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
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
