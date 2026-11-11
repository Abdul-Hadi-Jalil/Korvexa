import '../models/task.dart';
import 'api_client.dart';

/// Values accepted by `GET /me/upcoming?window=`.
class UpcomingWindow {
  static const today = 'today';
  static const week = 'week';
  static const all = 'all';
}

class MeService {
  final ApiClient _client;

  MeService(this._client);

  Future<List<Task>> upcoming(String window, {bool mine = false}) async {
    final data = await _client.get(
      '/me/upcoming',
      query: {'window': window, 'mine': mine},
    ) as List;
    return data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Tasks in the active projects with a due date in [start, end] (inclusive).
  Future<List<Task>> calendar(DateTime start, DateTime end) async {
    final data = await _client.get('/me/calendar', query: {
      'start': _date(start),
      'end': _date(end),
    }) as List;
    return data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
