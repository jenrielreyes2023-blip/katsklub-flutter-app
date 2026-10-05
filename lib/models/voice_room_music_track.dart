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

  const VoiceRoomMusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.artworkUrl,
    required this.duration,
    this.durationSeconds = 0,
    required this.streamUrl,
  });

  factory VoiceRoomMusicTrack.fromJson(Map<String, dynamic> json) {
    return VoiceRoomMusicTrack(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown Track').toString(),
      artist: (json['artist'] ?? 'KatsKlub').toString(),
      genre: (json['genre'] ?? 'General').toString(),
      artworkUrl: (json['artworkUrl'] ?? '').toString(),
      duration: (json['duration'] ?? '3:00').toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      streamUrl: (json['streamUrl'] ?? '').toString(),
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
    };
  }
}
