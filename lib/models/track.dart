import '../config/api_config.dart';

/// Represents a single playlist track returned by the
/// `GET /api/playlists/:id` endpoint (`mapPlaylistTrackRow` on the server).
class Track {
  const Track({
    required this.id,
    required this.playlistId,
    required this.sortOrder,
    required this.trackType,
    required this.title,
    required this.artist,
    required this.artworkUrl,
    required this.previewUrl,
    required this.audioUrl,
    required this.audioMime,
    required this.source,
    this.createdAt,
  });

  final int id;
  final int playlistId;
  final int sortOrder;

  /// Usually `'uploaded_audio'` for playlist tracks backed by real audio files.
  final String trackType;

  final String title;
  final String artist;
  final String artworkUrl;

  /// Legacy preview URL field. Current playlists are expected to play from `audioUrl`.
  final String previewUrl;

  /// Full audio URL for the playlist track.
  final String audioUrl;

  final String audioMime;
  final String source;

  final DateTime? createdAt;

  bool get hasAudio => audioUrl.trim().isNotEmpty;
  bool get isUploaded =>
      hasAudio || trackType == 'uploaded' || trackType == 'uploaded_audio';
  bool get isApplePreview =>
      !hasAudio && (trackType == 'apple_music' || previewUrl.trim().isNotEmpty);

  /// The URL that should be played, regardless of track type.
  String get playableUrl {
    final raw = hasAudio ? audioUrl : previewUrl;
    return raw.isEmpty ? '' : ApiConfig.assetUrl(raw);
  }

  /// Resolved (potentially proxied) artwork URL.
  String get resolvedArtworkUrl =>
      artworkUrl.isEmpty ? '' : ApiConfig.assetUrl(artworkUrl);

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: _readInt(json['id']),
      playlistId: _readInt(json['playlistId'] ?? json['playlist_id']),
      sortOrder: _readInt(json['sortOrder'] ?? json['sort_order']),
      trackType: _readString(json['trackType'] ?? json['track_type']) ??
          'uploaded_audio',
      title: _readString(json['title']) ?? '',
      artist: _readString(json['artist']) ?? '',
      artworkUrl: _readString(json['artworkUrl'] ?? json['artwork_url']) ?? '',
      previewUrl: _readString(json['previewUrl'] ?? json['preview_url']) ?? '',
      audioUrl: _readString(json['audioUrl'] ?? json['audio_url']) ?? '',
      audioMime: _readString(json['audioMime'] ?? json['audio_mime']) ?? '',
      source: _readString(json['source']) ?? '',
      createdAt: DateTime.tryParse(_readString(json['createdAt']) ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playlistId': playlistId,
      'sortOrder': sortOrder,
      'trackType': trackType,
      'title': title,
      'artist': artist,
      'artworkUrl': artworkUrl,
      'previewUrl': previewUrl,
      'audioUrl': audioUrl,
      'audioMime': audioMime,
      'source': source,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Track copyWith({
    int? sortOrder,
    String? title,
    String? artist,
    String? artworkUrl,
    String? previewUrl,
    String? audioUrl,
  }) {
    return Track(
      id: id,
      playlistId: playlistId,
      sortOrder: sortOrder ?? this.sortOrder,
      trackType: trackType,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      audioMime: audioMime,
      source: source,
      createdAt: createdAt,
    );
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }

    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
