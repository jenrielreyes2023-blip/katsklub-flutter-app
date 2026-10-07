/// Model representing a curated or Bunny CDN track available for Voice Room streaming.
class VoiceRoomMusicTrack {
  final String id;
  final String title;
  final String artist;
  final String genre;
  final String artworkUrl;
  final String duration;
  final int durationSeconds;
  final String streamUrl;
  final int? addedByUserId;
  final String? addedByUsername;

  const VoiceRoomMusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.artworkUrl,
    required this.duration,
    this.durationSeconds = 0,
    required this.streamUrl,
    this.addedByUserId,
    this.addedByUsername,
  });

  factory VoiceRoomMusicTrack.fromJson(Map<String, dynamic> json) {
    int? parsedUserId;
    final rawUserId = json['addedByUserId'];
    if (rawUserId is num) {
      parsedUserId = rawUserId.toInt();
    } else if (rawUserId is String) {
      parsedUserId = int.tryParse(rawUserId);
    }

    int parsedDurationSeconds = 0;
    final rawDurationSeconds = json['durationSeconds'];
    if (rawDurationSeconds is num) {
      parsedDurationSeconds = rawDurationSeconds.toInt();
    } else if (rawDurationSeconds is String) {
      parsedDurationSeconds = int.tryParse(rawDurationSeconds) ?? 0;
    }

    return VoiceRoomMusicTrack(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown Track').toString(),
      artist: (json['artist'] ?? 'KatsKlub').toString(),
      genre: (json['genre'] ?? 'General').toString(),
      artworkUrl: (json['artworkUrl'] ?? '').toString(),
      duration: (json['duration'] ?? '3:00').toString(),
      durationSeconds: parsedDurationSeconds,
      streamUrl: (json['streamUrl'] ?? '').toString(),
      addedByUserId: parsedUserId,
      addedByUsername: json['addedByUsername']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'genre': genre,
      'artworkUrl': artworkUrl,
      'duration': duration,
      'durationSeconds': durationSeconds,
      'streamUrl': streamUrl,
      if (addedByUserId != null) 'addedByUserId': addedByUserId,
      if (addedByUsername != null) 'addedByUsername': addedByUsername,
    };
  }
}
