import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
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
    required this.mimeType,
    required this.originalByteCount,
    required this.uploadByteCount,
    required this.optimized,
  });

  final String id;
  final XFile file;
  final String dataUrl;
  final Uint8List previewBytes;
  final String mimeType;
  final int originalByteCount;
  final int uploadByteCount;
  final bool optimized;
}

class CreatePostProgress {
  const CreatePostProgress({
    required this.message,
    this.progress,
  });

  final String message;
  final double? progress;
}

typedef CreatePostProgressCallback = void Function(CreatePostProgress progress);

class CreatePostRequest {
  const CreatePostRequest({
    required this.text,
    required this.visibility,
    required this.images,
    this.onProgress,
  });

  final String text;
  final String visibility;
  final List<SelectedPostImage> images;
  final CreatePostProgressCallback? onProgress;
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
  static const int _maxImageDimension = 1600;
  static const int _maxServerImageBytes = 6 * 1024 * 1024;
  static const int _targetImageBytes = 5 * 1024 * 1024;

  Future<List<SelectedPostImage>> pickImages({
    CreatePostProgressCallback? onProgress,
  }) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    final selected = <SelectedPostImage>[];
    var index = 0;
    final batchId = DateTime.now().microsecondsSinceEpoch;
    final limitedImages = images.take(10).toList();
    for (final image in limitedImages) {
      onProgress?.call(
        CreatePostProgress(
          message: 'Preparing image ${index + 1} of ${limitedImages.length}...',
          progress: limitedImages.isEmpty ? null : index / limitedImages.length,
        ),
      );
      selected.add(await _prepareSelectedImage(image, batchId, index));
      index++;
    }

    onProgress?.call(const CreatePostProgress(message: 'Images ready.', progress: 1));
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
      request.onProgress?.call(
        CreatePostProgress(
          message: hasImages
              ? 'Connecting to upload ${request.images.length} image${request.images.length == 1 ? '' : 's'}...'
              : 'Connecting to KatsKlub...',
          progress: hasImages ? 0.05 : null,
        ),
      );

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

      timeout = Timer(Duration(seconds: hasImages ? 120 : 65), () {
        if (!completer.isCompleted) {
          completer.complete(
            CreatePostResult(
              ok: false,
              error: hasImages
                  ? 'Image upload timed out. Try fewer or smaller images.'
                  : 'Post creation timeout. Please try again.',
            ),
          );
        }
        socket?.dispose();
      });

      socket.onConnect((_) {
        request.onProgress?.call(
          CreatePostProgress(
            message: hasImages
                ? 'Uploading ${request.images.length} prepared image${request.images.length == 1 ? '' : 's'}...'
                : 'Posting...',
            progress: hasImages ? 0.35 : null,
          ),
        );

        socket?.emitWithAck(
          'post:create',
          payload,
          ack: (response) {
            if (completer.isCompleted) return;

            if (response is Map && response['ok'] == true) {
              final rawPost = response['post'];
              if (rawPost is Map) {
                request.onProgress?.call(
                  const CreatePostProgress(
                    message: 'Post created.',
                    progress: 1,
                  ),
                );
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

  Future<SelectedPostImage> _prepareSelectedImage(
    XFile file,
    int batchId,
    int index,
  ) async {
    final originalBytes = await file.readAsBytes();
    final originalMime = _inferImageMime(file);
    final upload = _optimizeImageForPost(originalBytes, originalMime);

    return SelectedPostImage(
      id: '$batchId-$index-${file.name}',
      file: file,
      dataUrl: 'data:${upload.mimeType};base64,${base64Encode(upload.bytes)}',
      previewBytes: originalBytes,
      mimeType: upload.mimeType,
      originalByteCount: originalBytes.length,
      uploadByteCount: upload.bytes.length,
      optimized: upload.optimized,
    );
  }

  _PreparedImage _optimizeImageForPost(Uint8List originalBytes, String originalMime) {
    if (originalBytes.length <= _targetImageBytes && originalMime == 'image/gif') {
      return _PreparedImage(
        bytes: originalBytes,
        mimeType: originalMime,
        optimized: false,
      );
    }

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      if (originalBytes.length <= _maxServerImageBytes) {
        return _PreparedImage(
          bytes: originalBytes,
          mimeType: originalMime,
          optimized: false,
        );
      }

      throw StateError(
        'One selected image is too large and could not be optimized. Try a smaller image.',
      );
    }

    final candidates = <Uint8List>[];
    for (final maxDimension in const [_maxImageDimension, 1280, 1024]) {
      final resized = _resizeImage(decoded, maxDimension);
      for (final quality in const [85, 76, 68, 60]) {
        candidates.add(Uint8List.fromList(img.encodeJpg(resized, quality: quality)));
      }
    }

    final serverSafeCandidate = _bestCandidateUnder(candidates, _targetImageBytes);
    final fallbackCandidate = _bestCandidateUnder(candidates, _maxServerImageBytes);
    final smallestCandidate = _smallestCandidate(candidates);

    Uint8List chosenBytes;
    var optimized = false;
    var mimeType = originalMime;

    if (originalBytes.length <= _maxServerImageBytes &&
        fallbackCandidate != null &&
        fallbackCandidate.length >= originalBytes.length * 0.95) {
      chosenBytes = originalBytes;
    } else {
      chosenBytes = serverSafeCandidate ?? fallbackCandidate ?? smallestCandidate ?? originalBytes;
      optimized = !identical(chosenBytes, originalBytes);
      mimeType = optimized ? 'image/jpeg' : originalMime;
    }

    if (chosenBytes.length > _maxServerImageBytes) {
      throw StateError(
        'One selected image is still larger than 6 MB after optimization. Try a smaller image.',
      );
    }

    return _PreparedImage(
      bytes: chosenBytes,
      mimeType: mimeType,
      optimized: optimized,
    );
  }

  img.Image _resizeImage(img.Image source, int maxDimension) {
    if (source.width <= maxDimension && source.height <= maxDimension) {
      return source;
    }

    if (source.width >= source.height) {
      return img.copyResize(source, width: maxDimension);
    }

    return img.copyResize(source, height: maxDimension);
  }

  Uint8List? _bestCandidateUnder(List<Uint8List> candidates, int maxBytes) {
    Uint8List? best;
    for (final candidate in candidates) {
      if (candidate.length > maxBytes) {
        continue;
      }
      if (best == null || candidate.length > best.length) {
        best = candidate;
      }
    }
    return best;
  }

  Uint8List? _smallestCandidate(List<Uint8List> candidates) {
    Uint8List? smallest;
    for (final candidate in candidates) {
      if (smallest == null || candidate.length < smallest.length) {
        smallest = candidate;
      }
    }
    return smallest;
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

class _PreparedImage {
  const _PreparedImage({
    required this.bytes,
    required this.mimeType,
    required this.optimized,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool optimized;
}
