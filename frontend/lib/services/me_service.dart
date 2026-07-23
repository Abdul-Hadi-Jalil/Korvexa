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
}
