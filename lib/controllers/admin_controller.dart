import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// AdminController
/// ----------------
/// In-memory store of all Lecturer accounts created by the Admin.
/// Replace the internal list with API calls when you wire a backend.
class AdminController extends ChangeNotifier {
  /// Lecturer accounts. Password is stored alongside in a parallel map so the
  /// UserModel stays clean (passwords don't belong on the user object).
  final List<UserModel> _lecturers = [];
  final Map<String, String> _passwords = {}; // email -> password

  AdminController() {
    _seedDemoLecturer();
  }

  /// Read-only view for the UI.
  List<UserModel> get lecturers => List.unmodifiable(_lecturers);

  /// Admin creates a new Lecturer account.
  /// Returns false if a lecturer with the same email already exists.
  bool addLecturer({
    required String name,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();

    final alreadyExists = _lecturers.any(
      (l) => l.email.toLowerCase() == normalizedEmail,
    );
    if (alreadyExists) return false;

    final newLecturer = UserModel(
      id: 'lect-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: normalizedEmail,
      role: UserRole.lecturer,
    );

    _lecturers.add(newLecturer);
    _passwords[normalizedEmail] = password;
    notifyListeners();
    return true;
  }

  /// Admin removes a lecturer.
  void removeLecturer(String id) {
    final lecturer = _lecturers.firstWhere(
      (l) => l.id == id,
      orElse: () => const UserModel(
        id: '',
        name: '',
        email: '',
        role: UserRole.lecturer,
      ),
    );
    if (lecturer.id.isEmpty) return;

    _lecturers.removeWhere((l) => l.id == id);
    _passwords.remove(lecturer.email);
    notifyListeners();
  }

  /// Used by AuthController.login to validate lecturer credentials without
  /// creating a circular import.
  UserModel? findByCredentials(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    if (_passwords[normalizedEmail] != password) return null;

    try {
      return _lecturers.firstWhere(
        (l) => l.email.toLowerCase() == normalizedEmail,
      );
    } catch (_) {
      return null;
    }
  }

  void _seedDemoLecturer() {
    const demoEmail = 'lecturer@portal.com';
    if (_passwords.containsKey(demoEmail)) return;

    _lecturers.add(
      const UserModel(
        id: 'lect-demo-001',
        name: 'Pensyarah Demo',
        email: demoEmail,
        role: UserRole.lecturer,
      ),
    );
    _passwords[demoEmail] = 'lecturer123';
  }
}
