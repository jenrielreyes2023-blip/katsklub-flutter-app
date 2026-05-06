class Story {
  const Story({
    required this.id,
    required this.authorFullName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.ownedByMe,
  });

  final String id;
  final String authorFullName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool ownedByMe;

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: _readString(json['id']) ?? '',
      authorFullName: _readString(json['authorFullName']) ??
          _readString(json['fullName']) ??
          _readString(json['author']) ??
          'KatsKlub user',
      authorUsername: _readString(json['authorUsername']) ??
          _readString(json['username']) ??
          '',
      authorAvatarUrl: _readString(json['authorAvatarUrl']) ??
          _readString(json['avatarUrl']) ??
          '',
      ownedByMe: json['ownedByMe'] == true,
    );
  }

  String get initials {
    final parts = authorFullName
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

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}
