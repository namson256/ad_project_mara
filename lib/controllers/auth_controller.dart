import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// AuthController
/// ----------------
/// Holds the currently-logged-in user and exposes login/logout actions.
///
/// In a real app this would call Firebase Auth / your REST API. For the
/// boilerplate we hardcode one Admin and look up Lecturers from the
/// AdminController via the `lecturerLookup` callback passed to [login].
class AuthController extends ChangeNotifier {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isLecturer => _currentUser?.isLecturer ?? false;

  /// Hardcoded Admin credential (replace with real auth).
  /// There is NO public sign-up — only this seeded admin can bootstrap.
  static const _adminEmail = 'admin@portal.com';
  static const _adminPassword = 'admin123';

  /// Attempts to sign a user in.
  ///
  /// [lecturerLookup] is injected so AuthController doesn't need a hard
  /// reference to AdminController (keeps the controllers decoupled and
  /// testable). It should return a UserModel matching the email + password,
  /// or null if no lecturer matches.
  Future<bool> login({
    required String email,
    required String password,
    required UserModel? Function(String email, String password) lecturerLookup,
  }) async {
    // Simulate network latency so the UI's loading state is exercised.
    await Future.delayed(const Duration(milliseconds: 400));

    final normalizedEmail = email.trim().toLowerCase();

    // 1. Admin check
    if (normalizedEmail == _adminEmail && password == _adminPassword) {
      _currentUser = const UserModel(
        id: 'admin-001',
        name: 'Portal Admin',
        email: _adminEmail,
        role: UserRole.admin,
      );
      notifyListeners();
      return true;
    }

    // 2. Lecturer check (delegated to AdminController's store)
    final lecturer = lecturerLookup(normalizedEmail, password);
    if (lecturer != null) {
      _currentUser = lecturer;
      notifyListeners();
      return true;
    }

    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}