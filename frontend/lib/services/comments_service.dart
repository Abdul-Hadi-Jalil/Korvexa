import '../models/comment.dart';
import 'api_client.dart';

class CommentsService {
  final ApiClient _client;

  CommentsService(this._client);

  /// Returns the page's items. The backend also returns `total`, but the
  /// comment UI shows a single scrollable list, so items are enough here.
  Future<List<Comment>> list(int taskId, {int limit = 100, int offset = 0}) async {
    final data = await _client.get(
      '/tasks/$taskId/comments',
      query: {'limit': limit, 'offset': offset},
    ) as Map<String, dynamic>;
    return (data['items'] as List).map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Comment> create(int taskId, String body) async {
    final data = await _client.post('/tasks/$taskId/comments', {'body': body});
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  Future<Comment> update(int commentId, String body) async {
    final data = await _client.patch('/comments/$commentId', {'body': body});
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int commentId) => _client.delete('/comments/$commentId');
}
