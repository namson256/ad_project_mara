import 'package:cloud_firestore/cloud_firestore.dart';

/// Three roles in the portal:
/// - pensyarah  → Lecturer (can mark attendance)
/// - staff      → Admin/Staff (manages lecturers & system)
/// - ketuaProgram → Ketua Program / Head of Programme
enum UserRole { pensyarah, staff, ketuaProgram }

/// Immutable user representation shared between controllers and views.
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
  bool get isPensyarah => role == UserRole.pensyarah;
  bool get isStaff => role == UserRole.staff;
  bool get isKetuaProgram => role == UserRole.ketuaProgram;

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

  /// JSON serialization.
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
        role: _parseRole(json['role'] as String),
      );

  /// Create a UserModel from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: _parseRole(data['role'] as String? ?? 'pensyarah'),
    );
  }

  /// Parses a role string (handles both camelCase and snake_case from Firestore).
  static UserRole _parseRole(String roleStr) {
    switch (roleStr) {
      case 'pensyarah':
        return UserRole.pensyarah;
      case 'staff':
        return UserRole.staff;
      case 'ketuaProgram':
      case 'ketua_program':
        return UserRole.ketuaProgram;
      default:
        return UserRole.pensyarah;
    }
  }

  /// Display-friendly role name in Malay.
  String get roleDisplayName {
    switch (role) {
      case UserRole.pensyarah:
        return 'Pensyarah';
      case UserRole.staff:
        return 'Staff';
      case UserRole.ketuaProgram:
        return 'Ketua Program';
    }
  }
}