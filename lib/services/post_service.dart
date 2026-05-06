import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
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
      final uploadBytes = request.images.fold<int>(
        0,
        (total, image) => total + image.uploadByteCount,
      );
      _socketLog(
        'creating socket; hasCookie=${cookie.startsWith('katsklub_session=')}; '
        'images=${request.images.length}; uploadBytes=$uploadBytes; '
        'textLength=${text.length}',
      );

      final socketOptions = io.OptionBuilder()
          .setPath('/socket.io/')
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .disableMultiplex()
          .enableReconnection()
          .setReconnectionAttempts(2)
          .setReconnectionDelay(500)
          .setTimeout(20000)
          .setAckTimeout(hasImages ? 120000 : 65000)
          .enableWithCredentials()
          .setExtraHeaders(socketHeaders)
          .setTransportOptions({
            'polling': {'extraHeaders': socketHeaders},
            'websocket': {'extraHeaders': socketHeaders},
          })
          .build();
      socket = io.io(
        ApiConfig.apiBaseUrl,
        socketOptions,
      );

      void finishWithPostEvent(dynamic data, String eventName) {
        if (completer.isCompleted) return;
        final post = _readPostFromSocketEvent(data);
        if (post == null || !_looksLikeCreatedPost(post, text, request.images.length)) {
          return;
        }

        _socketLog('$eventName received before ACK; treating matching created post as success');
        request.onProgress?.call(
          const CreatePostProgress(
            message: 'Post created.',
            progress: 1,
          ),
        );
        completer.complete(CreatePostResult(ok: true, post: post));
      }

      timeout = Timer(Duration(seconds: hasImages ? 120 : 65), () {
        if (!completer.isCompleted) {
          _socketLog(
            'timeout waiting for post:create ACK; connected=${socket?.connected == true}; '
            'images=${request.images.length}; uploadBytes=$uploadBytes',
          );
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
        _socketLog(
          'connected before emit; connected=${socket?.connected == true}; id=${socket?.id ?? 'unknown'}',
        );
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
            _socketLog(
              'post:create ACK received; ok=${response is Map ? response['ok'] == true : false}; '
              'type=${response.runtimeType}',
            );
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
        _socketLog('post:create emitted; waiting for ACK');
      });

      socket.onDisconnect((reason) {
        _socketLog('disconnect; reason=$reason');
      });

      socket.on('post:new', (data) => finishWithPostEvent(data, 'post:new'));
      socket.on('new_post', (data) => finishWithPostEvent(data, 'new_post'));

      socket.onConnectError((error) {
        _socketLog('connect_error; error=$error');
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
        _socketLog('socket error event; error=$error');
        if (!completer.isCompleted) {
          completer.complete(
            CreatePostResult(
              ok: false,
              error: error?.toString() ?? 'Failed to create post.',
            ),
          );
        }
      });

      socket.on('reconnect', (attempt) {
        _socketLog('reconnect; attempt=$attempt');
      });

      socket.on('reconnect_attempt', (attempt) {
        _socketLog('reconnect_attempt; attempt=$attempt');
      });

      _socketLog('connecting socket');
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

    String? sessionCookie;
    for (final part in cookie.split(RegExp(r';\s*'))) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('katsklub_session=')) {
        sessionCookie = trimmed;
        break;
      }
    }

    if (sessionCookie != null && sessionCookie.length > 'katsklub_session='.length) {
      return sessionCookie;
    }

    return null;
  }

  String _normalizeVisibility(String visibility) {
    return const {'public', 'friends', 'only_me'}.contains(visibility)
        ? visibility
        : 'public';
  }

  Post? _readPostFromSocketEvent(dynamic data) {
    if (data is Map) {
      return Post.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  bool _looksLikeCreatedPost(Post post, String text, int imageCount) {
    if (post.text.trim() != text.trim()) {
      return false;
    }
    if (imageCount > 0 && post.imageUrls.length != imageCount) {
      return false;
    }
    return true;
  }

  void _socketLog(String message) {
    developer.log(message, name: 'KatsKlubCreatePost');
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
