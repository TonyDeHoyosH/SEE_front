class User {
  final String id;
  final String email;
  final String nombrePreferido;
  final String token;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.nombrePreferido,
    required this.token,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nombrePreferido: json['nombrePreferido'] as String,
      token: json['token'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nombrePreferido': nombrePreferido,
      'token': token,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? nombrePreferido,
    String? token,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nombrePreferido: nombrePreferido ?? this.nombrePreferido,
      token: token ?? this.token,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}
