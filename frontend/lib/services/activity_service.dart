import '../models/activity.dart';
import 'api_client.dart';

class ActivityService {
  final ApiClient _client;

  ActivityService(this._client);

  Future<List<Activity>> list(int taskId) async {
    final data = await _client.get('/tasks/$taskId/activity') as List;
    return data.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
  }
}
