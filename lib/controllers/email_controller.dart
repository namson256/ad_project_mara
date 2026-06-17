import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/email_history_model.dart';

class EmailHistoryController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'email_history';

  List<EmailHistoryRecord> _items = [];
  bool _isLoading = false;
  String? _error;

  EmailHistoryController() {
    loadAll();
  }

  List<EmailHistoryRecord> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    try {
      final snap = await _db.collection(_collection).orderBy('createdAt', descending: true).get();
      _items = snap.docs.map((d) => EmailHistoryRecord.fromFirestore(d)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateStatus(String id, String status) async {
    try {
      await _db.collection(_collection).doc(id).set({'status': status}, SetOptions(merge: true));
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _items[idx] = _items[idx].copyWith(status: status);
        notifyListeners();
      } else {
        await loadAll();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
