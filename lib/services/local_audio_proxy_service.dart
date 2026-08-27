import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

/// Local in-app HTTP proxy server running on loopback (127.0.0.1).
/// Bridges YouTube audio streams directly to Android ExoPlayer (just_audio),
/// permanently resolving:
/// 1. PlatformException(0, Source error) caused by Google CDN headers/IP binding.
/// 2. WebView auto-pausing/stalling on screen minimize or navigation.
/// 3. ExoPlayer format detection failures by serving explicit `Content-Type: audio/mp4`.
class LocalAudioProxyService {
  static final LocalAudioProxyService instance = LocalAudioProxyService._internal();
  factory LocalAudioProxyService() => instance;
  LocalAudioProxyService._internal();

  HttpServer? _server;
  yte.YoutubeExplode? _yt;
  Completer<void>? _initCompleter;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  /// Ensures the local loopback server is active and ready to serve audio.
  Future<void> ensureStarted() async {
    if (_server != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      _yt = yte.YoutubeExplode();
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('[LocalAudioProxy] Listening on http://127.0.0.1:$port');
      _server!.listen(_handleRequest, onError: (err) {
        debugPrint('[LocalAudioProxy] Server error: $err');
      });
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('[LocalAudioProxy] Failed to start: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  /// Returns the localhost URL for [videoId] suitable for `just_audio`.
  Future<String> getAudioUrl(String videoId) async {
    await ensureStarted();
    return 'http://127.0.0.1:$port/audio.mp4?id=${Uri.encodeComponent(videoId.trim())}';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final videoId = request.uri.queryParameters['id']?.trim() ?? '';
    if (videoId.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheFile = File('${tempDir.path}/yt_proxy_$videoId.m4a');

      // 1. If already fully cached on disk, serve from cache with full Range support
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 50000) {
        await _serveLocalFile(request, cacheFile);
        return;
      }

      // 2. Stream dynamically from YouTubeExplode
      final yt = _yt ?? yte.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(videoId);

      // Prefer AAC/MP4 audio stream (itag 140 or 139)
      final mp4Streams = manifest.audioOnly
          .where((a) => a.container.name == 'mp4' || a.audioCodec.contains('mp4a'))
          .toList();
      final streamInfo = mp4Streams.isNotEmpty
          ? mp4Streams.first
          : manifest.audioOnly.withHighestBitrate();

      request.response.headers.contentType = ContentType('audio', 'mp4');
      request.response.headers.set('Accept-Ranges', 'bytes');
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.contentLength = streamInfo.size.totalBytes;

      final tempSink = cacheFile.openWrite();
      final audioStream = yt.videos.streamsClient.get(streamInfo);

      try {
        await for (final chunk in audioStream) {
          try {
            request.response.add(chunk);
          } catch (_) {
            break; // Client skipped or disconnected socket
          }
          tempSink.add(chunk);
        }
      } finally {
        await tempSink.close();
        try {
          await request.response.close();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LocalAudioProxy] Streaming error for $videoId: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Audio streaming failed: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveLocalFile(HttpRequest request, File file) async {
    final fileSize = file.lengthSync();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

    request.response.headers.contentType = ContentType('audio', 'mp4');
    request.response.headers.set('Accept-Ranges', 'bytes');
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final parts = rangeHeader.substring(6).split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty)
          ? (int.tryParse(parts[1]) ?? fileSize - 1)
          : fileSize - 1;

      final safeEnd = end.clamp(start, fileSize - 1);
      final contentLength = (safeEnd - start) + 1;

      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$safeEnd/$fileSize',
      );
      request.response.contentLength = contentLength;

      await request.response.addStream(file.openRead(start, safeEnd + 1));
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = fileSize;
      await request.response.addStream(file.openRead());
      await request.response.close();
    }
  }

  void dispose() {
    _server?.close(force: true);
    _server = null;
    _yt?.close();
    _yt = null;
    _initCompleter = null;
  }
}

final localAudioProxy = LocalAudioProxyService.instance;
