import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import 'auth_service.dart';

/// Wraps the playlist + music-library REST endpoints exposed by the server
/// (`/api/playlists/*` and `/api/music-library/search`).
///
/// Uploaded MP3 playback is the primary focus; Apple Music previews are
/// surfaced through the existing `FeedService.searchAppleMusic` and
/// story-music flows and are intentionally **not** duplicated here.
class MusicService {
  MusicService({http.Client? client, AuthService? authService})
      : _client = client ?? http.Client(),
        _authService = authService ?? AuthService();

  final http.Client _client;
  final AuthService _authService;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Fetches a playlist (with all of its tracks) by id.
  /// Returns `null` when the request fails or the user is unauthenticated.
  Future<Playlist?> getPlaylist(int playlistId) async {
    final data = await _authenticatedGet(ApiConfig.playlistPath(playlistId));
    if (data.isEmpty) {
      return null;
    }

    final playlistJson = _extractPlaylistJson(data);
    if (playlistJson.isEmpty) {
      return null;
    }

    return Playlist.fromJson(playlistJson);
  }

  /// Fetches all playlists owned by the given username.
  Future<List<Playlist>> getUserPlaylists(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return const <Playlist>[];
    }

    final raw = await _authenticatedGetRaw(
      ApiConfig.userPlaylistsPath(trimmed),
    );

    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map<String, dynamic> && raw['playlists'] is List) {
      list = raw['playlists'] as List<dynamic>;
    } else {
      return const <Playlist>[];
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .toList(growable: false);
  }

  /// Fetches suggested public playlists.
  Future<List<Playlist>> getSuggestedPlaylists() async {
    try {
      final raw = await _authenticatedGet('/api/playlists/suggestions');
      final playlistsList = raw['playlists'];
      if (playlistsList is List) {
        return playlistsList
            .whereType<Map<String, dynamic>>()
            .map(Playlist.fromJson)
            .toList(growable: false);
      }
      return const <Playlist>[];
    } catch (_) {
      return const <Playlist>[];
    }
  }

  /// Clones a public playlist to the current user's library.
  Future<Playlist?> clonePlaylist(int playlistId) async {
    try {
      final data = await _authenticatedPost('/api/playlists/$playlistId/clone', body: {});
      final playlistJson = _extractPlaylistJson(data);
      if (playlistJson.isEmpty) {
        return null;
      }
      return Playlist.fromJson(playlistJson);
    } catch (_) {
      return null;
    }
  }

  /// Searches the internal music library (uploaded MP3s only).
  Future<List<MusicLibraryResult>> searchMusicLibrary(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const <MusicLibraryResult>[];
    }

    final encoded = Uri.encodeQueryComponent(trimmed);
    final raw = await _authenticatedGetRaw(
      '${ApiConfig.musicLibrarySearchPath}?q=$encoded',
    );

    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map<String, dynamic> && raw['songs'] is List) {
      list = raw['songs'] as List<dynamic>;
    } else if (raw is Map<String, dynamic> && raw['results'] is List) {
      list = raw['results'] as List<dynamic>;
    } else {
      return const <MusicLibraryResult>[];
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(MusicLibraryResult.fromJson)
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Writes — playlists
  // ---------------------------------------------------------------------------

  /// Creates a new playlist owned by the current user.
  Future<Playlist?> createPlaylist({
    required String title,
    String? description,
    String? coverUrl,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
    };
    final data = await _authenticatedPost(ApiConfig.playlistsPath, body: body);
    final playlistJson = _extractPlaylistJson(data);
    if (playlistJson.isEmpty) {
      return null;
    }
    return Playlist.fromJson(playlistJson);
  }

  /// Updates a playlist's metadata.
  Future<Playlist?> updatePlaylist(
    int playlistId, {
    String? title,
    String? description,
    String? coverUrl,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
    };
    if (body.isEmpty) {
      return null;
    }

    final data = await _authenticatedPatch(
      ApiConfig.playlistPath(playlistId),
      body: body,
    );
    final playlistJson = _extractPlaylistJson(data);
    if (playlistJson.isEmpty) {
      return null;
    }
    return Playlist.fromJson(playlistJson);
  }

  /// Deletes the given playlist. Returns `true` on success.
  Future<bool> deletePlaylist(int playlistId) async {
    return _authenticatedDeleteOk(ApiConfig.playlistPath(playlistId));
  }

  // ---------------------------------------------------------------------------
  // Writes — tracks
  // ---------------------------------------------------------------------------

  /// Adds a track to a playlist by referencing an entry in the music library.
  Future<Track?> addTrackFromLibrary({
    required int playlistId,
    required int musicId,
  }) async {
    final data = await _authenticatedPost(
      ApiConfig.playlistTrackFromLibraryPath(playlistId),
      body: {'musicId': musicId},
    );
    final trackJson = _extractTrackJson(data);
    if (trackJson.isEmpty) {
      return null;
    }
    return Track.fromJson(trackJson);
  }

  /// Uploads an audio file (MP3) and adds it to the playlist as a new track.
  /// Returns the created track on success.
  Future<Track?> uploadTrack({
    required int playlistId,
    required File audioFile,
    String? title,
    String? artist,
    String? artworkUrl,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        ApiConfig.uri(ApiConfig.playlistTrackUploadPath(playlistId)),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (title != null && title.trim().isNotEmpty) {
        request.fields['title'] = title.trim();
      }
      if (artist != null && artist.trim().isNotEmpty) {
        request.fields['artist'] = artist.trim();
      }
      if (artworkUrl != null && artworkUrl.trim().isNotEmpty) {
        request.fields['artworkUrl'] = artworkUrl.trim();
      }

      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final trackJson = _extractTrackJson(decoded);
      if (trackJson.isEmpty) {
        return null;
      }
      return Track.fromJson(trackJson);
    } catch (_) {
      return null;
    }
  }

  /// Removes a track from a playlist. Returns `true` on success.
  Future<bool> removeTrack({
    required int playlistId,
    required int trackId,
  }) async {
    return _authenticatedDeleteOk(
      ApiConfig.playlistTrackPath(playlistId, trackId),
    );
  }

  /// Updates a track's metadata (title/artist/artwork).
  Future<Track?> updateTrack({
    required int playlistId,
    required int trackId,
    String? title,
    String? artist,
    String? artworkUrl,
  }) async {
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (artworkUrl != null) 'artworkUrl': artworkUrl,
    };
    if (body.isEmpty) {
      return null;
    }

    final data = await _authenticatedPatch(
      ApiConfig.playlistTrackPath(playlistId, trackId),
      body: body,
    );
    final trackJson = _extractTrackJson(data);
    if (trackJson.isEmpty) {
      return null;
    }
    return Track.fromJson(trackJson);
  }

  /// Reorders tracks within a playlist by submitting the new ordered list of
  /// track ids.
  Future<bool> reorderTracks({
    required int playlistId,
    required List<int> trackIds,
  }) async {
    final data = await _authenticatedPatch(
      ApiConfig.playlistReorderPath(playlistId),
      body: {'trackIds': trackIds},
    );
    return data.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers (mirror FeedService's pattern)
  // ---------------------------------------------------------------------------

  Map<String, String> _authHeaders(
    String token, {
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  Future<Map<String, dynamic>> _authenticatedGet(String path) async {
    final decoded = await _authenticatedGetRaw(path);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Same as [_authenticatedGet] but returns the raw decoded JSON so list
  /// responses (e.g. `/api/users/:username/playlists`) are preserved.
  Future<Object?> _authenticatedGetRaw(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _client.get(
        ApiConfig.uri(path),
        headers: _authHeaders(token),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _authenticatedPost(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.post(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: body != null),
        body: body == null ? null : jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _authenticatedPatch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final response = await _client.patch(
        ApiConfig.uri(path),
        headers: _authHeaders(token, includeJsonContentType: true),
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<bool> _authenticatedDeleteOk(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await _client.delete(
        ApiConfig.uri(path),
        headers: _authHeaders(token),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _extractPlaylistJson(Map<String, dynamic> data) {
    final nested = data['playlist'];
    final source = nested is Map<String, dynamic> ? nested : data;
    final playlistJson = Map<String, dynamic>.from(source);

    final rawTracks = data['tracks'];
    if (rawTracks is List && playlistJson['tracks'] is! List) {
      playlistJson['tracks'] = rawTracks;
    }

    return playlistJson;
  }

  Map<String, dynamic> _extractTrackJson(Map<String, dynamic> data) {
    final nested = data['track'];
    if (nested is Map<String, dynamic>) {
      return Map<String, dynamic>.from(nested);
    }
    return Map<String, dynamic>.from(data);
  }

  /// Releases the underlying [http.Client]. Only call when this service is no
  /// longer needed for the lifetime of the app.
  void dispose() {
    _client.close();
  }
}
