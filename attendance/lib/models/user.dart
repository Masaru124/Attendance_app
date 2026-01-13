enum UserRole { student, teacher, admin }

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isStudent => role == UserRole.student;
  bool get isTeacher => role == UserRole.teacher;
  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) {
    String roleStr = json['role'] ?? 'student';
    UserRole role;
    switch (roleStr.toUpperCase()) {
      case 'TEACHER':
        role = UserRole.teacher;
        break;
      case 'ADMIN':
        role = UserRole.admin;
        break;
      default:
        role = UserRole.student;
    }

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role.toString().split('.').last.toUpperCase(),
  };
}
