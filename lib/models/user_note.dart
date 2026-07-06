class UserNote {
  const UserNote({
    required this.userId,
    required this.text,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.createdAt,
    required this.expiresAt,
  });

  final String userId;
  final String text;
  final String username;
  final String fullName;
  final String avatarUrl;
  final String createdAt;
  final String expiresAt;

  factory UserNote.fromJson(Map<String, dynamic> json) {
    return UserNote(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? json['expires_at']?.toString() ?? '',
    );
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return username.isNotEmpty ? username[0].toUpperCase() : 'K';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}
