class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final bool isActive;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}
