class User {
  const User({
    this.id,
    this.fullName,
    this.username,
    this.email,
    this.avatarUrl,
    this.bio,
    this.createdAt,
    required this.raw,
  });

  final String? id;
  final String? fullName;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String? createdAt;
  final Map<String, dynamic> raw;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _readString(json['id']),
      fullName: _readString(json['fullName'] ?? json['full_name']),
      username: _readString(json['username']),
      email: _readString(json['email']),
      avatarUrl: _readString(json['avatarUrl'] ?? json['avatar_url']),
      bio: _readString(json['bio']),
      createdAt: _readString(json['createdAt'] ?? json['created_at']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  String get displayName {
    if (_hasValue(fullName)) {
      return fullName!.trim();
    }

    if (_hasValue(username)) {
      return username!.trim();
    }

    if (_hasValue(email)) {
      return email!.trim();
    }

    return 'KatsKlub user';
  }

  String? get handle {
    if (!_hasValue(username)) {
      return null;
    }

    return '@${username!.trim()}';
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'K';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(raw);
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = String(value).trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
