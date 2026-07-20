import '../models/label.dart';
import 'api_client.dart';

class LabelsService {
  final ApiClient _client;

  LabelsService(this._client);

  Future<List<Label>> list() async {
    final data = await _client.get('/labels') as List;
    return data.map((e) => Label.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Label> create({required String name, String? color}) async {
    final data = await _client.post('/labels', {
      'name': name,
      if (color != null && color.isNotEmpty) 'color': color,
    });
    return Label.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _client.delete('/labels/$id');
}
