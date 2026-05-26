/// Defines the two roles available in the portal.
/// Admins manage lecturer accounts; Lecturers only see their own dashboard.
enum UserRole { admin, lecturer }

/// Immutable user representation shared between controllers and views.
/// Keeping this as a plain data class (no Firebase / backend coupling) makes
/// it easy to swap in a real auth provider later.
class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  /// Convenience helpers for guards & UI.
  bool get isAdmin => role == UserRole.admin;
  bool get isLecturer => role == UserRole.lecturer;

  /// Useful when you need a tweaked copy (e.g. after editing a profile).
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  /// JSON serialization — handy once you wire this to a real backend.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.lecturer,
        ),
      );
}