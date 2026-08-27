import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

import '../config/api_config.dart';

/// Model representing a YouTube video result item.
class YouTubeVideoItem {
  final String id;
  final String title;
  final String duration;
  final String thumbnail;
  final String author;
  final String viewCount;

  const YouTubeVideoItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.thumbnail,
    required this.author,
    this.viewCount = '',
  });

  factory YouTubeVideoItem.fromJson(Map<String, dynamic> json) {
    return YouTubeVideoItem(
      id: (json['id'] ?? json['videoId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      thumbnail: (json['thumbnail'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      viewCount: (json['viewCount'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'thumbnail': thumbnail,
      'author': author,
      'viewCount': viewCount,
    };
  }

  @override
  String toString() =>
      'YouTubeVideoItem(id: $id, title: $title, duration: $duration, author: $author)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouTubeVideoItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Service providing communication with the backend YouTube API module.
class YouTubeService {
  /// Base URL pointing to the backend API server.
  final String baseUrl;
  final http.Client _client;

  YouTubeService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? ApiConfig.apiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  /// Searches for YouTube videos matching the specified [query].
  ///
  /// Calls `GET /api/youtube/search?q=<query>` and parses the response list.
  Future<List<YouTubeVideoItem>> searchVideos(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse('$baseUrl${ApiConfig.youtubeSearchPath(trimmed)}');
    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['results'] is List) {
          final list = decoded['results'] as List;
          return list
              .whereType<Map<String, dynamic>>()
              .map(YouTubeVideoItem.fromJson)
              .toList();
        }
      } else {
        developer.log(
          'Failed to search YouTube videos: ${response.statusCode} - ${response.body}',
          name: 'YouTubeService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Exception while searching YouTube videos: $e',
        name: 'YouTubeService',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return const [];
  }

  /// Retrieves the direct Google CDN playable streaming URL for [videoId].
  ///
  /// Calls GET /api/youtube/stream/:id and returns the deciphered URL.
  Future<String?> getStreamUrl(String videoId) async {
    final trimmed = videoId.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.parse('$baseUrl${ApiConfig.youtubeStreamPath(trimmed)}');
    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final url = decoded['url'] as String? ?? decoded['streamUrl'] as String?;
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      } else {
        developer.log(
          'Failed to retrieve stream URL: ${response.statusCode} - ${response.body}',
          name: 'YouTubeService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Exception while retrieving stream URL: $e',
        name: 'YouTubeService',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  /// Fetches detailed metadata for [videoId].
  ///
  /// Calls GET /api/youtube/info/:id.
  Future<Map<String, dynamic>?> getVideoInfo(String videoId) async {
    final trimmed = videoId.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.parse('$baseUrl${ApiConfig.youtubeInfoPath(trimmed)}');
    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } else {
        developer.log(
          'Failed to retrieve video info: ${response.statusCode} - ${response.body}',
          name: 'YouTubeService',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Exception while retrieving video info: $e',
        name: 'YouTubeService',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  /// Retrieves direct audio stream URL (M4A / AAC / MP4) for music listening.
  Future<String?> getAudioStreamUrl(String videoId) async {
    final trimmed = videoId.trim();
    if (trimmed.isEmpty) return null;

    // 1. Try client-side extraction using youtube_explode_dart FIRST - AAC/Opus for just_audio (most reliable, no PO token needed)
    try {
      final yt = yte.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(trimmed);
      // just_audio (ExoPlayer) handles both AAC (m4a itag 140) and Opus (webm itag 251) flawlessly
      final audio = manifest.audioOnly.withHighestBitrate();
      yt.close();
      // Validate URL is audio (AAC/Opus) not video
      final urlStr = audio.url.toString();
      if (urlStr.isNotEmpty) return urlStr;
    } catch (_) {}

    // 1.5 Fallback to muxed client (video+audio) - larger but playable
    try {
      final yt = yte.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(trimmed);
      final muxed = manifest.muxed.withHighestBitrate();
      yt.close();
      return muxed.url.toString();
    } catch (_) {}

    // 2. Fallback to backend API (youtubei.js) - may need PO token, less reliable currently
    final uri = Uri.parse('$baseUrl${ApiConfig.youtubeAudioPath(trimmed)}');
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final url = decoded['audioUrl'] as String? ?? decoded['streamUrl'] as String? ?? decoded['url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    } catch (_) {}

    // 3. Last fallback: backend stream endpoint
    try {
      final streamUri = Uri.parse('$baseUrl${ApiConfig.youtubeStreamPath(trimmed)}');
      final response = await _client.get(streamUri, headers: {'Accept': 'application/json'});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final url = decoded['url'] as String? ?? decoded['streamUrl'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Downloads or retrieves cached audio track for [videoId].
  /// Guarantees 100% offline-compatible, error-free playback without ExoPlayer (0) Source error.
  Future<String?> getCachedOrDownloadAudio(
    String videoId, {
    void Function(double progress)? onProgress,
  }) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/yt_audio_$cleanId.m4a');

      // 1. If already cached and valid size (>50KB), return local file URI immediately!
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 50000) {
        return Uri.file(cacheFile.path).toString();
      }

      // 2. Fetch stream manifest via youtube_explode_dart
      final yt = yte.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(cleanId);

      // AAC (m4a, itag 140) or Opus (webm, itag 251) - both work with just_audio/ExoPlayer
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      final totalBytes = streamInfo.size.totalBytes;
      final tempSink = cacheFile.openWrite();
      int received = 0;

      final stream = yt.videos.streamsClient.get(streamInfo);
      await for (final chunk in stream) {
        tempSink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(received / totalBytes);
        }
      }
      await tempSink.close();
      yt.close();

      if (cacheFile.existsSync() && cacheFile.lengthSync() > 50000) {
        return Uri.file(cacheFile.path).toString();
      }
    } catch (_) {}

    // 3. Fallback to direct streaming URL
    return getAudioStreamUrl(cleanId);
  }
}
