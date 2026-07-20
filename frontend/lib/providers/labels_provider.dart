import 'package:flutter/foundation.dart';

import '../models/label.dart';
import '../services/api_client.dart';
import '../services/labels_service.dart';

/// Workspace-scoped labels, shared app-wide (used by the board filter bar and
/// the task detail label picker).
class LabelsProvider extends ChangeNotifier {
  final LabelsService _service;

  LabelsProvider(this._service);

  List<Label> _labels = [];
  bool _loaded = false;
  String? _error;

  List<Label> get labels => _labels;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      _labels = await _service.list();
      _loaded = true;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  Future<Label?> create(String name, {String? color}) async {
    try {
      final label = await _service.create(name: name, color: color);
      _labels = [..._labels, label]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return label;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _service.delete(id);
      _labels = _labels.where((l) => l.id != id).toList();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }
}
