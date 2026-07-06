import '../config/api_config.dart';
import 'track.dart';

/// Represents a playlist returned by `GET /api/playlists/:id`
/// (and used in lighter form by `GET /api/users/:username/playlists`).
class Playlist {
  const Playlist({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.ownerUsername,
    required this.ownedByMe,
    required this.tracks,
    this.trackCountOverride,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final String title;
  final String description;
  final String coverUrl;
  final String ownerUsername;
  final bool ownedByMe;
  final List<Track> tracks;
  final int? trackCountOverride;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get trackCount => trackCountOverride ?? tracks.length;

  /// Resolved (potentially proxied) cover URL.
  String get resolvedCoverUrl =>
      coverUrl.isEmpty ? '' : ApiConfig.assetUrl(coverUrl);

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final tracks = <Track>[];
    if (rawTracks is List) {
      for (final entry in rawTracks) {
        if (entry is Map<String, dynamic>) {
          tracks.add(Track.fromJson(entry));
        }
      }
    }

    final parsedTrackCount = _readNullableInt(
      json['trackCount'] ?? json['track_count'],
    );

    return Playlist(
      id: _readInt(json['id']),
      userId: _readInt(json['userId'] ?? json['user_id']),
      title: _readString(json['title']) ?? '',
      description: _readString(json['description']) ?? '',
      coverUrl: _readString(json['coverUrl'] ?? json['cover_url']) ?? '',
      ownerUsername:
          _readString(json['ownerUsername'] ?? json['owner_username']) ?? '',
      ownedByMe: json['ownedByMe'] == true || json['owned_by_me'] == true,
      tracks: List<Track>.unmodifiable(tracks),
      trackCountOverride:
          parsedTrackCount != null && parsedTrackCount >= tracks.length
              ? parsedTrackCount
              : (tracks.isNotEmpty ? tracks.length : parsedTrackCount),
      createdAt: DateTime.tryParse(_readString(json['createdAt']) ?? ''),
      updatedAt: DateTime.tryParse(_readString(json['updatedAt']) ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'ownerUsername': ownerUsername,
      'ownedByMe': ownedByMe,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'trackCount': trackCount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Playlist copyWith({
    String? title,
    String? description,
    String? coverUrl,
    List<Track>? tracks,
    int? trackCountOverride,
  }) {
    final nextTracks =
        tracks == null ? this.tracks : List<Track>.unmodifiable(tracks);

    return Playlist(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      ownerUsername: ownerUsername,
      ownedByMe: ownedByMe,
      tracks: nextTracks,
      trackCountOverride: trackCountOverride ??
          (tracks != null ? nextTracks.length : this.trackCountOverride),
      createdAt: createdAt,
      updatedAt: updatedAt,
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

  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}

/// Represents a single result from `GET /api/music-library/search`.
class MusicLibraryResult {
  const MusicLibraryResult({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.audioUrl,
    required this.audioMime,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String audioUrl;
  final String audioMime;

  factory MusicLibraryResult.fromJson(Map<String, dynamic> json) {
    return MusicLibraryResult(
      id: _readMusicInt(json['id']),
      title: _readMusicString(json['title']) ?? '',
      artist: _readMusicString(json['artist']) ?? '',
      album: _readMusicString(json['album']) ?? '',
      artworkUrl:
          _readMusicString(json['artworkUrl'] ?? json['artwork_url']) ?? '',
      audioUrl: _readMusicString(json['audioUrl'] ?? json['audio_url']) ?? '',
      audioMime:
          _readMusicString(json['audioMime'] ?? json['audio_mime']) ?? '',
    );
  }

  String get resolvedArtworkUrl =>
      artworkUrl.isEmpty ? '' : ApiConfig.assetUrl(artworkUrl);

  String get resolvedAudioUrl =>
      audioUrl.isEmpty ? '' : ApiConfig.assetUrl(audioUrl);
}

String? _readMusicString(Object? value) {
  if (value == null) {
    return null;
  }

  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? null : stringValue;
}

int _readMusicInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
