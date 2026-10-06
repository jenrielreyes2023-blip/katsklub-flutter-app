import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  static const String _favKey = 'voice_room_fav_tracks_v1';

  List<VoiceRoomMusicTrack>? _cachedTracks;
  List<String>? _cachedGenres;

  bool get hasCachedTracks => _cachedTracks != null && _cachedTracks!.isNotEmpty;
  VoiceRoomMusicResult? get cachedResult => _cachedTracks != null
      ? VoiceRoomMusicResult(
          genres: _cachedGenres ?? ['All'],
          tracks: _cachedTracks!,
        )
      : null;

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

  /// Get list of saved favorite tracks from local storage
  Future<List<VoiceRoomMusicTrack>> getFavoriteTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favKey) ?? [];
      return list.map((item) {
        try {
          return VoiceRoomMusicTrack.fromJson(jsonDecode(item));
        } catch (_) {
          return null;
        }
      }).whereType<VoiceRoomMusicTrack>().toList();
    } catch (e) {
      debugPrint('[VoiceRoomMusicService] getFavoriteTracks error: $e');
      return [];
    }
  }

  /// Get set of favorite track IDs for fast O(1) lookup
  Future<Set<String>> getFavoriteTrackIds() async {
    try {
      final tracks = await getFavoriteTracks();
      return tracks.map((t) => t.id).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Toggle favorite status of a track. Returns true if now favorited, false if removed.
  Future<bool> toggleFavorite(VoiceRoomMusicTrack track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favKey) ?? [];

      final existingIndex = list.indexWhere((item) {
        try {
          final map = jsonDecode(item);
          return map['id'].toString() == track.id;
        } catch (_) {
          return false;
        }
      });

      bool isNowFav;
      if (existingIndex >= 0) {
        list.removeAt(existingIndex);
        isNowFav = false;
      } else {
        list.insert(0, jsonEncode(track.toJson()));
        isNowFav = true;
      }

      await prefs.setStringList(_favKey, list);
      return isNowFav;
    } catch (e) {
      debugPrint('[VoiceRoomMusicService] toggleFavorite error: $e');
      return false;
    }
  }
}
