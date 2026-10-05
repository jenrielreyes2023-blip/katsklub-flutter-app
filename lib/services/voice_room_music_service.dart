import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/voice_room_music_track.dart';

class VoiceRoomMusicResult {
  final List<String> genres;
  final List<VoiceRoomMusicTrack> tracks;

  const VoiceRoomMusicResult({
    required this.genres,
    required this.tracks,
  });
}

class VoiceRoomMusicService {
  factory VoiceRoomMusicService() => _instance;
  VoiceRoomMusicService._internal();
  static final VoiceRoomMusicService _instance = VoiceRoomMusicService._internal();

  List<VoiceRoomMusicTrack>? _cachedTracks;
  List<String>? _cachedGenres;

  Future<VoiceRoomMusicResult> getTracks({
    String? query,
    String? genre,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedTracks != null && (query == null || query.isEmpty) && (genre == null || genre == 'All')) {
      return VoiceRoomMusicResult(
        genres: _cachedGenres ?? ['All'],
        tracks: _cachedTracks!,
      );
    }

    try {
      final queryParams = <String, String>{};
      if (query != null && query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }
      if (genre != null && genre != 'All') {
        queryParams['genre'] = genre;
      }
      if (forceRefresh) {
        queryParams['refresh'] = 'true';
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.voiceRoomMusicTracksPath}').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final rawGenres = data['genres'];
          final genres = rawGenres is List ? rawGenres.map((g) => g.toString()).toList() : <String>['All'];

          final rawTracks = data['tracks'];
          final tracks = rawTracks is List
              ? rawTracks
                  .whereType<Map<String, dynamic>>()
                  .map(VoiceRoomMusicTrack.fromJson)
                  .toList()
              : <VoiceRoomMusicTrack>[];

          if (query == null || query.isEmpty) {
            _cachedTracks = tracks;
            _cachedGenres = genres;
          }

          return VoiceRoomMusicResult(genres: genres, tracks: tracks);
        }
      }
    } catch (e) {
      debugPrint('[VoiceRoomMusicService] getTracks error: $e');
    }

    return VoiceRoomMusicResult(
      genres: _cachedGenres ?? ['All'],
      tracks: _cachedTracks ?? [],
    );
  }
}
