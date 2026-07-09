import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class NotificationController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  List<NotificationRecord> _items = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _sub;

  NotificationController() {
    _startListener();
  }

  List<NotificationRecord> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<NotificationRecord> visibleForUser(String userId, UserRole role) {
    if (role == UserRole.staff) {
      return items;
    }

    if (userId.isEmpty) return [];

    return items.where((n) => n.recipientIds.contains(userId)).toList();
  }

  void _startListener() {
    _isLoading = true;
    _error = null;
    _sub = _db.collection(_collection).orderBy('createdAt', descending: true).snapshots().listen((snap) {
      _items = snap.docs.map((d) => NotificationRecord.fromFirestore(d)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Legacy manual load; kept for compatibility.
  Future<void> loadNotifications() async {
    try {
      final snap = await _db.collection(_collection).orderBy('createdAt', descending: true).get();
      _items = snap.docs.map((d) => NotificationRecord.fromFirestore(d)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<String?> markRead(String id, String userId) async {
    try {
      final docRef = _db.collection(_collection).doc(id);
      await docRef.update({
        'readBy': FieldValue.arrayUnion([userId])
      });
      final idx = _items.indexWhere((n) => n.id == id);
      if (idx != -1) {
        final updated = _items[idx].copyWith(
          readBy: List.from(_items[idx].readBy)..add(userId),
        );
        _items[idx] = updated;
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteNotification(String id) async {
    try {
      await _db.collection(_collection).doc(id).delete();
      _items.removeWhere((n) => n.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
