import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../models/post.dart';
import 'auth_service.dart';

class SelectedPostImage {
  const SelectedPostImage({
    required this.id,
    required this.file,
    required this.dataUrl,
    required this.previewBytes,
  });

  final String id;
  final XFile file;
  final String dataUrl;
  final Uint8List previewBytes;
}

class CreatePostRequest {
  const CreatePostRequest({
    required this.text,
    required this.visibility,
    required this.images,
  });

  final String text;
  final String visibility;
  final List<SelectedPostImage> images;
}

class CreatePostResult {
  const CreatePostResult({
    required this.ok,
    this.post,
    this.error,
  });

  final bool ok;
  final Post? post;
  final String? error;
}

class PostService {
  Future<List<SelectedPostImage>> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    final selected = <SelectedPostImage>[];
    var index = 0;
    final batchId = DateTime.now().microsecondsSinceEpoch;
    for (final image in images.take(10)) {
      final bytes = await image.readAsBytes();
      final mime = _inferImageMime(image);
      selected.add(
        SelectedPostImage(
          id: '$batchId-${index++}-${image.name}',
          file: image,
          dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
          previewBytes: bytes,
        ),
      );
    }

    return selected;
  }

  Future<CreatePostResult> createPost(CreatePostRequest request) async {
    final text = request.text.trim();
    final hasImages = request.images.isNotEmpty;

    if (text.isEmpty && !hasImages) {
      return const CreatePostResult(
        ok: false,
        error: 'Write something or attach an image before posting.',
      );
    }

    final cookie = await _readSessionCookie();
    if (cookie == null) {
      return const CreatePostResult(
        ok: false,
        error: 'Not authenticated. Please log in again.',
      );
    }

    final payload = {
      'text': text,
      'visibility': _normalizeVisibility(request.visibility),
      if (hasImages)
        'imageDataUrls': request.images.map((image) => image.dataUrl).toList(),
    };

    io.Socket? socket;
    final completer = Completer<CreatePostResult>();
    Timer? timeout;

    try {
      final socketHeaders = <String, String>{
        'Cookie': cookie,
      };

      socket = io.io(
        ApiConfig.apiBaseUrl,
        <String, dynamic>{
          'autoConnect': false,
          'forceNew': true,
          'reconnection': true,
          'reconnectionAttempts': 2,
          'reconnectionDelay': 500,
          'transports': ['polling', 'websocket'],
          'withCredentials': true,
          'extraHeaders': socketHeaders,
          'transportOptions': {
            'polling': {'extraHeaders': socketHeaders},
            'websocket': {'extraHeaders': socketHeaders},
          },
          'auth': {
            'cookie': cookie,
          },
        },
      );

      timeout = Timer(const Duration(seconds: 65), () {
        if (!completer.isCompleted) {
          completer.complete(
            const CreatePostResult(
              ok: false,
              error: 'Post creation timeout. Please try again.',
            ),
          );
        }
        socket?.dispose();
      });

      socket.onConnect((_) {
        socket?.emitWithAck(
          'post:create',
          payload,
          ack: (response) {
            if (completer.isCompleted) return;

            if (response is Map && response['ok'] == true) {
              final rawPost = response['post'];
              if (rawPost is Map) {
                completer.complete(
                  CreatePostResult(
                    ok: true,
                    post: Post.fromJson(Map<String, dynamic>.from(rawPost)),
                  ),
                );
                return;
              }
            }

            final error = response is Map
                ? response['error']?.toString()
                : 'Failed to create post.';
            completer.complete(
              CreatePostResult(
                ok: false,
                error: error?.isNotEmpty == true ? error : 'Failed to create post.',
              ),
            );
          },
        );
      });

      socket.onConnectError((error) {
        if (!completer.isCompleted) {
          completer.complete(
            CreatePostResult(
              ok: false,
              error: 'Unable to connect to KatsKlub: $error',
            ),
          );
        }
      });

      socket.onError((error) {
        if (!completer.isCompleted) {
          completer.complete(
            CreatePostResult(
              ok: false,
              error: error?.toString() ?? 'Failed to create post.',
            ),
          );
        }
      });

      socket.connect();
      return await completer.future;
    } catch (error) {
      return CreatePostResult(
        ok: false,
        error: error.toString(),
      );
    } finally {
      timeout?.cancel();
      socket?.dispose();
    }
  }

  Future<String?> _readSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCookieHeader(prefs.getString(AuthService.sessionCookieKey));
  }

  String _inferImageMime(XFile file) {
    final mimeType = file.mimeType?.trim();
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String? _normalizeCookieHeader(String? savedCookie) {
    final cookie = savedCookie?.trim();
    if (cookie == null || cookie.isEmpty) {
      return null;
    }

    if (!cookie.contains('=')) {
      return 'katsklub_session=${Uri.encodeComponent(cookie)}';
    }

    const ignoredCookieAttributes = {
      'domain',
      'expires',
      'httponly',
      'max-age',
      'path',
      'samesite',
      'secure',
    };

    final validCookies = cookie
        .split(RegExp(r';\s*'))
        .map((part) => part.trim())
        .where((part) {
          if (part.isEmpty || !part.contains('=')) {
            return false;
          }

          final name = part.split('=').first.trim().toLowerCase();
          return !ignoredCookieAttributes.contains(name);
        })
        .toList();

    if (validCookies.isEmpty) {
      return null;
    }

    return validCookies.join('; ');
  }

  String _normalizeVisibility(String visibility) {
    return const {'public', 'friends', 'only_me'}.contains(visibility)
        ? visibility
        : 'public';
  }
}
