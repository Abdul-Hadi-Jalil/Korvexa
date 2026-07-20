import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../services/me_service.dart';

class UpcomingProvider extends ChangeNotifier {
  final MeService _service;

  UpcomingProvider(this._service);

  String _window = UpcomingWindow.today;
  List<Task> _tasks = [];
  bool _loading = false;
  String? _error;

  String get window => _window;
  List<Task> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> setWindow(String window) async {
    if (_window == window) return;
    _window = window;
    await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = await _service.upcoming(_window);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
