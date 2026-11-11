import 'package:flutter/foundation.dart';

import '../models/dashboard_stats.dart';
import '../services/api_client.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;

  DashboardProvider(this._service);

  DashboardStats? _stats;
  bool _loading = false;
  String? _error;

  DashboardStats? get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _stats = await _service.stats();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
