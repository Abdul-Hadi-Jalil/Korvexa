import '../models/dashboard_stats.dart';
import 'api_client.dart';

class DashboardService {
  final ApiClient _client;

  DashboardService(this._client);

  Future<DashboardStats> stats() async {
    final data = await _client.get('/dashboard');
    return DashboardStats.fromJson(data as Map<String, dynamic>);
  }
}
