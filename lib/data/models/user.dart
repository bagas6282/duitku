import 'package:equatable/equatable.dart';

/// Represents an authenticated user profile in Duitku.
class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  /// First letter initials for default avatar display.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        if (id > 0) 'id': id,
        'name': name,
        'email': email.trim().toLowerCase(),
        'avatar_url': avatarUrl,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int,
        name: map['name'] as String,
        email: map['email'] as String,
        avatarUrl: map['avatar_url'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, email, avatarUrl, createdAt];
}
