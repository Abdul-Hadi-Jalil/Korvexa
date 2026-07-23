import '../models/notification.dart';
import 'api_client.dart';

class NotificationsService {
  final ApiClient _client;

  NotificationsService(this._client);

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final data = await _client.get('/notifications', query: {'unread_only': unreadOnly}) as List;
    return data.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final data = await _client.get('/notifications/unread_count') as Map<String, dynamic>;
    return data['unread'] as int;
  }

  Future<void> markRead(int id) => _client.post('/notifications/$id/read', {});

  Future<void> markAllRead() => _client.post('/notifications/read_all', {});
}
