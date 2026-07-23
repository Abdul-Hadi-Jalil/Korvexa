import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../services/api_client.dart';
import '../services/notifications_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationsService _service;

  NotificationsProvider(this._service);

  List<AppNotification> _notifications = [];
  int _unread = 0;
  bool _loading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  int get unread => _unread;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _notifications = await _service.list();
      _unread = _notifications.where((n) => !n.read).length;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unread = await _service.unreadCount();
      notifyListeners();
    } on ApiException {
      // Non-fatal: a badge that's briefly stale is fine.
    }
  }

  Future<void> markRead(int id) async {
    await _service.markRead(id);
    await load();
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    await load();
  }

  /// Called when the active workspace changes -- notifications are per-workspace.
  void reset() {
    _notifications = [];
    _unread = 0;
    notifyListeners();
  }
}
