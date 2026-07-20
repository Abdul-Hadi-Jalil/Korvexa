import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../services/api_client.dart';
import '../services/projects_service.dart';

class ProjectsProvider extends ChangeNotifier {
  final ProjectsService _service;

  ProjectsProvider(this._service);

  List<Project> _projects = [];
  bool _loading = false;
  String? _error;

  List<Project> get projects => _projects;
  bool get loading => _loading;
  String? get error => _error;

  bool _includeArchived = false;
  bool get includeArchived => _includeArchived;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _projects = await _service.list(includeArchived: _includeArchived);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setIncludeArchived(bool value) async {
    _includeArchived = value;
    await load();
  }

  Future<bool> archive(int id) async {
    try {
      await _service.archive(id);
      await load();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> unarchive(int id) async {
    try {
      await _service.unarchive(id);
      await load();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> create({required String name, String? key}) async {
    try {
      final project = await _service.create(name: name, key: key);
      _projects = [..._projects, project];
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _service.delete(id);
      _projects = _projects.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
