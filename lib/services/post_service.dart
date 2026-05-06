import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../models/post.dart';
import 'auth_service.dart';

class SelectedPostImage {
  const SelectedPostImage({
    required this.file,
    required this.dataUrl,
  });

  final XFile file;
  final String dataUrl;
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
    for (final image in images.take(10)) {
      final dataUrl = await _toImageDataUrl(image);
      selected.add(SelectedPostImage(file: image, dataUrl: dataUrl));
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
    if (cookie == null || cookie.isEmpty) {
      return const CreatePostResult(
        ok: false,
        error: 'Not authenticated. Please log in again.',
      );
    }

    final payload = {
      'text': text,
      'visibility': _normalizeVisibility(request.visibility),
      if (hasImages) 'imageDataUrls': request.images.map((image) => image.dataUrl).toList(),
    };

    io.Socket? socket;
    final completer = Completer<CreatePostResult>();
    Timer? timeout;

    try {
      socket = io.io(
        ApiConfig.apiBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders({'Cookie': cookie})
            .disableAutoConnect()
            .build(),
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
    return prefs.getString(AuthService.sessionCookieKey);
  }

  Future<String> _toImageDataUrl(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime = _inferImageMime(file);
    return 'data:$mime;base64,${base64Encode(bytes)}';
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

  String _normalizeVisibility(String visibility) {
    return const {'public', 'friends', 'only_me'}.contains(visibility)
        ? visibility
        : 'public';
  }
}
