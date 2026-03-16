class User {
  final String id;
  final String username;
  final String email;
  final bool hasVault;
  final bool isAdmin;
  final String createdAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.hasVault,
    required this.isAdmin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
        hasVault: (j['has_vault'] as bool?) ?? false,
        isAdmin: (j['is_admin'] as bool?) ?? false,
        createdAt: j['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'has_vault': hasVault,
        'is_admin': isAdmin,
        'created_at': createdAt,
      };
}
