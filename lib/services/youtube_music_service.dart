import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

import '../config/api_config.dart';

/// Representation of a YouTube Music track/song.
class YouTubeMusicSong {
  const YouTubeMusicSong({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.duration = '',
    this.thumbnail = '',
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String duration;
  final String thumbnail;

  factory YouTubeMusicSong.fromJson(Map<String, dynamic> json) {
    return YouTubeMusicSong(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration,
        'thumbnail': thumbnail,
      };
}

/// Representation of a YouTube Music chart or trending item.
class YouTubeMusicChart {
  const YouTubeMusicChart({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnail = '',
  });

  final String id;
  final String title;
  final String artist;
  final String thumbnail;

  factory YouTubeMusicChart.fromJson(Map<String, dynamic> json) {
    return YouTubeMusicChart(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnail': thumbnail,
      };
}

/// Combined charts and new releases from YouTube Music.
class YouTubeMusicChartsResult {
  const YouTubeMusicChartsResult({
    this.charts = const [],
    this.newReleases = const [],
  });

  final List<YouTubeMusicChart> charts;
  final List<YouTubeMusicChart> newReleases;
}

/// Dedicated YouTube Music service interfacing with backend `/api/music/*`
/// and offering client-side fallback via [youtube_explode_dart].
class YouTubeMusicService {
  YouTubeMusicService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Search specifically for songs/tracks on YouTube Music.
  /// `GET /api/music/search?q=<query>&type=song`
  Future<List<YouTubeMusicSong>> searchSongs(
    String query, {
    String type = 'song',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final uri = Uri.parse(
        '$_baseUrl${ApiConfig.musicSearchPath(trimmed, type: type)}',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['songs'] as List<dynamic>? ?? [];
        return list
            .map((e) => YouTubeMusicSong.fromJson(e as Map<String, dynamic>))
            .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('YouTubeMusicService.searchSongs backend error: $e');
    }

    // Client-side fallback via youtube_explode_dart
    try {
      final yt = yte.YoutubeExplode();
      final results = await yt.search.search(trimmed);
      yt.close();

      return results.map((v) {
        return YouTubeMusicSong(
          id: v.id.value,
          title: v.title,
          artist: v.author,
          duration: v.duration != null
              ? '${v.duration!.inMinutes}:${(v.duration!.inSeconds % 60).toString().padLeft(2, '0')}'
              : '',
          thumbnail: v.thumbnails.highResUrl,
        );
      }).toList();
    } catch (fallbackErr) {
      debugPrint('YouTubeMusicService client fallback error: $fallbackErr');
      return const [];
    }
  }

  /// Fetches top tracks and trending music charts from YouTube Music.
  /// GET /api/music/charts
  Future<YouTubeMusicChartsResult> getCharts() async {
    try {
      final uri = Uri.parse('$_baseUrl${ApiConfig.musicChartsPath}');
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawCharts = data['charts'] as List<dynamic>? ?? [];
        final rawReleases = data['newReleases'] as List<dynamic>? ?? [];

        final charts = rawCharts
            .map((e) => YouTubeMusicChart.fromJson(e as Map<String, dynamic>))
            .where((c) => c.id.isNotEmpty && c.title.isNotEmpty)
            .toList();

        final newReleases = rawReleases
            .map((e) => YouTubeMusicChart.fromJson(e as Map<String, dynamic>))
            .where((c) => c.id.isNotEmpty && c.title.isNotEmpty)
            .toList();

        return YouTubeMusicChartsResult(
          charts: charts,
          newReleases: newReleases,
        );
      }
    } catch (e) {
      debugPrint('YouTubeMusicService.getCharts error: $e');
    }

    return const YouTubeMusicChartsResult();
  }

  /// Extracts the best audio-only stream URL for background playback.
  /// GET /api/music/stream/:id
  Future<String?> getStreamUrl(String videoId) async {
    final trimmed = videoId.trim();
    if (trimmed.isEmpty) return null;

    // Attempt 1: Backend extraction
    try {
      final uri = Uri.parse('$_baseUrl${ApiConfig.musicStreamPath(trimmed)}');
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final streamUrl = data['streamUrl'] as String? ?? data['audioUrl'] as String?;
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return streamUrl;
        }
      }
    } catch (e) {
      debugPrint('YouTubeMusicService.getStreamUrl backend error: $e');
    }

    // Attempt 2: Direct client-side stream extraction (bulletproof on mobile IPs)
    try {
      final yt = yte.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(trimmed);

      final mp4Streams = manifest.audioOnly
          .where((a) => a.container.name == 'mp4' || a.audioCodec.contains('mp4a'))
          .toList();
      final streamInfo = mp4Streams.isNotEmpty
          ? mp4Streams.first
          : manifest.audioOnly.withHighestBitrate();
      final url = streamInfo.url.toString();
      yt.close();
      return url;
    } catch (e) {
      debugPrint('YouTubeMusicService.getStreamUrl client extraction error: $e');
      return null;
    }
  }

  /// Retrieves song lyrics if available.
  /// GET /api/music/lyrics/:id
  Future<String?> getLyrics(String videoId) async {
    final trimmed = videoId.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse('$_baseUrl${ApiConfig.musicLyricsPath(trimmed)}');
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['hasLyrics'] == true && data['lyrics'] != null) {
          return data['lyrics'] as String;
        }
      }
    } catch (e) {
      debugPrint('YouTubeMusicService.getLyrics error: $e');
    }

    return null;
  }
}
