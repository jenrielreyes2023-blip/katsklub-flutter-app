import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../models/post.dart';
import 'auth_service.dart';

enum SelectedPostImageStatus {
  preparing,
  ready,
  failed,
}

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
    required this.status,
    this.errorMessage,
  });

  final String id;
  final XFile file;
  final String dataUrl;
  final Uint8List previewBytes;
  final String mimeType;
  final int originalByteCount;
  final int uploadByteCount;
  final bool optimized;
  final SelectedPostImageStatus status;
  final String? errorMessage;

  bool get isReady => status == SelectedPostImageStatus.ready;
  bool get isPreparing => status == SelectedPostImageStatus.preparing;
  bool get isFailed => status == SelectedPostImageStatus.failed;

  SelectedPostImage copyWith({
    String? dataUrl,
    String? mimeType,
    int? uploadByteCount,
    bool? optimized,
    SelectedPostImageStatus? status,
    String? errorMessage,
  }) {
    return SelectedPostImage(
      id: id,
      file: file,
      dataUrl: dataUrl ?? this.dataUrl,
      previewBytes: previewBytes,
      mimeType: mimeType ?? this.mimeType,
      originalByteCount: originalByteCount,
      uploadByteCount: uploadByteCount ?? this.uploadByteCount,
      optimized: optimized ?? this.optimized,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
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
typedef SelectedPostImageCallback = void Function(SelectedPostImage image);

class CreatePostRequest {
  const CreatePostRequest({
    required this.text,
    required this.images,
    this.visibility = 'public',
    this.onProgress,
    this.albumTitle,
    this.isDiscussion = false,
    this.discussionTitle,
    this.discussionCoverDataUrl,
    this.isReel = false,
    this.reelImage,
    this.videoDataUrl,
    this.videoTitle,
  });

  final String text;
  final String visibility;
  final List<SelectedPostImage> images;
  final CreatePostProgressCallback? onProgress;
  final String? albumTitle;
  final bool isDiscussion;
  final String? discussionTitle;
  final String? discussionCoverDataUrl;
  final bool isReel;
  final SelectedPostImage? reelImage;
  final String? videoDataUrl;
  final String? videoTitle;
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
  static const int _webpQuality = 85;

  Future<List<SelectedPostImage>> pickImages({
    CreatePostProgressCallback? onProgress,
    SelectedPostImageCallback? onImageSelected,
    SelectedPostImageCallback? onImageUpdated,
  }) async {
    final pickWatch = Stopwatch()..start();
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: _webpQuality,
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
    );
    pickWatch.stop();
    _imageLog('image picker duration=${pickWatch.elapsedMilliseconds}ms; count=${images.length}');

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
      final originalBytes = await image.readAsBytes();
      final originalMime = _inferImageMime(image);
      final placeholder = SelectedPostImage(
        id: '$batchId-$index-${image.name}',
        file: image,
        dataUrl: '',
        previewBytes: originalBytes,
        mimeType: originalMime,
        originalByteCount: originalBytes.length,
        uploadByteCount: 0,
        optimized: false,
        status: SelectedPostImageStatus.preparing,
      );
      onImageSelected?.call(placeholder);

      final prepared = await _prepareSelectedImage(placeholder, originalBytes, originalMime);
      selected.add(prepared);
      onImageUpdated?.call(prepared);
      index++;
    }

    onProgress?.call(const CreatePostProgress(message: 'Images ready.', progress: 1));
    return selected;
  }

  Future<CreatePostResult> createPost(CreatePostRequest request) async {
    final text = request.text.trim();
    final readyImages = request.images.where((image) => image.isReady).toList();
    final hasImages = readyImages.isNotEmpty;
    final albumTitle = request.albumTitle?.trim() ?? '';
    final discussionTitle = request.discussionTitle?.trim() ?? '';
    final hasVideo = request.videoDataUrl?.trim().isNotEmpty == true;
    final hasReelImage = request.reelImage?.isReady == true;
    final hasDiscussionCover = request.discussionCoverDataUrl?.trim().isNotEmpty == true;
    final normalizedVisibility = _normalizeVisibility(request.visibility);
    final uploadImageCount =
        readyImages.length + (hasReelImage ? 1 : 0) + (hasDiscussionCover ? 1 : 0);
    final hasMediaUpload = uploadImageCount > 0 || hasVideo;
    final mode = request.isDiscussion
        ? 'discussion'
        : request.isReel
            ? 'reel'
            : albumTitle.isNotEmpty
                ? 'album'
                : 'post';
    final uploadTargetLabel = hasVideo
        ? uploadImageCount > 0
            ? '$uploadImageCount image${uploadImageCount == 1 ? '' : 's'} and video'
            : 'video'
        : '$uploadImageCount image${uploadImageCount == 1 ? '' : 's'}';

    if (request.images.any((image) => !image.isReady)) {
      return const CreatePostResult(
        ok: false,
        error: 'Please wait until all selected images are ready.',
      );
    }

    if (request.isDiscussion && (discussionTitle.isEmpty || text.isEmpty)) {
      return const CreatePostResult(
        ok: false,
        error: 'Discussion title and body are required.',
      );
    }

    if (request.isReel && text.isEmpty && !hasReelImage && !hasVideo) {
      return const CreatePostResult(
        ok: false,
        error: 'Add a caption, image, or video before posting a reel.',
      );
    }

    if (albumTitle.isNotEmpty && readyImages.isEmpty && !hasVideo) {
      return const CreatePostResult(
        ok: false,
        error: 'Add photos before posting an album.',
      );
    }

    if (text.isEmpty &&
        readyImages.isEmpty &&
        albumTitle.isEmpty &&
        !request.isDiscussion &&
        !request.isReel &&
        !hasVideo) {
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

    final payload = <String, dynamic>{
      'text': text,
      if (!request.isDiscussion && !request.isReel) 'visibility': normalizedVisibility,
      if (hasImages)
        'imageDataUrls': readyImages.map((image) => image.dataUrl).toList(),
      if (albumTitle.isNotEmpty) 'albumTitle': albumTitle,
      if (request.isDiscussion) 'isDiscussion': true,
      if (request.isDiscussion && discussionTitle.isNotEmpty)
        'discussionTitle': discussionTitle,
      if (request.discussionCoverDataUrl?.trim().isNotEmpty == true)
        'discussionCoverDataUrl': request.discussionCoverDataUrl!.trim(),
      if (request.isReel) 'isReel': true,
      if (request.isReel && hasReelImage) 'imageDataUrl': request.reelImage!.dataUrl,
      if (hasVideo) 'videoDataUrl': request.videoDataUrl!.trim(),
      if (!request.isReel && request.videoTitle?.trim().isNotEmpty == true)
        'videoTitle': request.videoTitle!.trim(),
    };

    io.Socket? socket;
    final completer = Completer<CreatePostResult>();
    Timer? timeout;

    try {
      request.onProgress?.call(
        CreatePostProgress(
          message: hasMediaUpload
              ? 'Connecting to upload $uploadTargetLabel...'
              : 'Connecting to KatsKlub...',
          progress: hasMediaUpload ? 0.05 : null,
        ),
      );

      final socketHeaders = <String, String>{
        'Cookie': cookie,
      };
      final totalPostWatch = Stopwatch()..start();
      final uploadBytes = readyImages.fold<int>(
        0,
        (total, image) => total + image.uploadByteCount,
      ) +
          (request.reelImage?.uploadByteCount ?? 0) +
          ((request.discussionCoverDataUrl?.length ?? 0) * 0.75).round() +
          ((request.videoDataUrl?.length ?? 0) * 0.75).round();
      _socketLog(
        'creating socket; hasCookie=${cookie.startsWith('katsklub_session=')}; '
        'mode=$mode; images=${readyImages.length}; uploadBytes=$uploadBytes; '
        'textLength=${text.length}',
      );
      _socketLog(
        'emit payload summary; '
        'mode=$mode; '
        'keys=${payload.keys.toList()}; '
        'textLength=${text.length}; '
        'imageCount=${hasImages ? readyImages.length : (hasReelImage ? 1 : 0)}; '
        'hasVideo=$hasVideo; '
        'videoMime=${request.videoDataUrl != null ? _extractDataUrlMime(request.videoDataUrl!) : ''}; '
        'videoSize=${((request.videoDataUrl?.length ?? 0) * 0.75).round()}; '
        'hasAlbumTitle=${albumTitle.isNotEmpty}; '
        'hasDiscussionTitle=${discussionTitle.isNotEmpty}; '
        'hasDiscussionCover=$hasDiscussionCover; '
        'visibility=${payload['visibility'] ?? 'n/a'}',
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
          .setAckTimeout(hasMediaUpload ? 120000 : 65000)
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
        if (post == null || !_looksLikeCreatedPost(post, text, readyImages.length)) {
          return;
        }

        _socketLog('$eventName received before ACK; treating matching created post as success');
        totalPostWatch.stop();
        _socketLog('total post duration=${totalPostWatch.elapsedMilliseconds}ms via $eventName');
        request.onProgress?.call(
          const CreatePostProgress(
            message: 'Post created.',
            progress: 1,
          ),
        );
        completer.complete(CreatePostResult(ok: true, post: post));
      }

      timeout = Timer(Duration(seconds: hasMediaUpload ? 120 : 65), () {
        if (!completer.isCompleted) {
          _socketLog(
            'timeout waiting for post:create ACK; connected=${socket?.connected == true}; '
            'images=$uploadImageCount; video=$hasVideo; uploadBytes=$uploadBytes',
          );
          completer.complete(
            CreatePostResult(
              ok: false,
              error: hasMediaUpload
                  ? 'Media upload timed out. Please try again.'
                  : 'Post creation timeout. Please try again.',
            ),
          );
        }
        socket?.dispose();
      });

      final connectWatch = Stopwatch();

      socket.onConnect((_) {
        connectWatch.stop();
        _socketLog('socket connect duration=${connectWatch.elapsedMilliseconds}ms');
        final ackWatch = Stopwatch()..start();
        _socketLog(
          'connected before emit; connected=${socket?.connected == true}; id=${socket?.id ?? 'unknown'}',
        );
        request.onProgress?.call(
          CreatePostProgress(
            message: hasMediaUpload
                ? 'Uploading prepared media...'
                : 'Posting...',
            progress: hasMediaUpload ? 0.35 : null,
          ),
        );

        socket?.emitWithAck(
          'post:create',
          payload,
          ack: (response) {
            ackWatch.stop();
            _socketLog('ACK wait duration=${ackWatch.elapsedMilliseconds}ms');
            _socketLog(
              'post:create ACK received; ok=${response is Map ? response['ok'] == true : false}; '
              'type=${response.runtimeType}',
            );
            if (completer.isCompleted) return;

            if (response is Map && response['ok'] == true) {
              final rawPost = response['post'];
              if (rawPost is Map) {
                totalPostWatch.stop();
                _socketLog('total post duration=${totalPostWatch.elapsedMilliseconds}ms via ACK');
                _socketLog('ACK success; payloadKeys=${payload.keys.toList()}');
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
            _socketLog('ACK error; error=$error; payloadKeys=${payload.keys.toList()}');
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
      connectWatch.start();
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

  Future<SelectedPostImage?> pickSinglePreparedImage({
    CreatePostProgressCallback? onProgress,
    SelectedPostImageCallback? onImageSelected,
    SelectedPostImageCallback? onImageUpdated,
  }) async {
    final images = await pickImages(
      onProgress: onProgress,
      onImageSelected: onImageSelected,
      onImageUpdated: onImageUpdated,
    );
    return images.isEmpty ? null : images.first;
  }

  Future<PreparedVideo?> pickVideo({
    int maxBytes = 250 * 1024 * 1024,
    CreatePostProgressCallback? onProgress,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) {
      return null;
    }

    onProgress?.call(const CreatePostProgress(message: 'Preparing video...', progress: null));
    final bytes = await picked.readAsBytes();
    if (bytes.length > maxBytes) {
      throw StateError('Video file is too large. Maximum is 250MB.');
    }

    final mime = _inferVideoMime(picked);
    final watch = Stopwatch()..start();
    final encoded = await Isolate.run(() => base64Encode(bytes));
    watch.stop();
    _imageLog(
      'video base64/dataUrl duration=${watch.elapsedMilliseconds}ms; bytes=${bytes.length}; mime=$mime',
    );

    return PreparedVideo(
      name: picked.name,
      dataUrl: 'data:$mime;base64,$encoded',
      byteCount: bytes.length,
      mimeType: mime,
    );
  }

  Future<SelectedPostImage> _prepareSelectedImage(
    SelectedPostImage image,
    Uint8List originalBytes,
    String originalMime,
  ) async {
    try {
      final upload = await _optimizeImageForPost(originalBytes, originalMime);
      if (upload.bytes.length > _maxServerImageBytes) {
        return image.copyWith(
          status: SelectedPostImageStatus.failed,
          errorMessage: 'Image is larger than 6 MB after preparation.',
        );
      }

      final base64Watch = Stopwatch()..start();
      final encoded = await Isolate.run(() => base64Encode(upload.bytes));
      base64Watch.stop();
      _imageLog(
        'base64/dataUrl duration=${base64Watch.elapsedMilliseconds}ms; bytes=${upload.bytes.length}; mime=${upload.mimeType}',
      );

      return image.copyWith(
        dataUrl: 'data:${upload.mimeType};base64,$encoded',
        mimeType: upload.mimeType,
        uploadByteCount: upload.bytes.length,
        optimized: upload.optimized,
        status: SelectedPostImageStatus.ready,
      );
    } catch (error) {
      _imageLog('image preparation failed; error=$error');
      return image.copyWith(
        status: SelectedPostImageStatus.failed,
        errorMessage: 'Image preparation failed.',
      );
    }
  }

  Future<_PreparedImage> _optimizeImageForPost(
    Uint8List originalBytes,
    String originalMime,
  ) async {
    if (originalMime == 'image/gif') {
      _imageLog('GIF selected; preserving original bytes=${originalBytes.length}');
      return _PreparedImage(
        bytes: originalBytes,
        mimeType: originalMime,
        optimized: false,
      );
    }

    final convertWatch = Stopwatch()..start();
    final webpBytes = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: _maxImageDimension,
      minHeight: _maxImageDimension,
      quality: _webpQuality,
      format: CompressFormat.webp,
      keepExif: false,
    );
    convertWatch.stop();
    _imageLog(
      'WebP conversion duration=${convertWatch.elapsedMilliseconds}ms; '
      'originalBytes=${originalBytes.length}; webpBytes=${webpBytes.length}; quality=$_webpQuality',
    );

    if (webpBytes.isNotEmpty && webpBytes.length < originalBytes.length * 0.95) {
      return _PreparedImage(
        bytes: webpBytes,
        mimeType: 'image/webp',
        optimized: true,
      );
    }

    return _PreparedImage(
      bytes: originalBytes,
      mimeType: originalMime,
      optimized: false,
    );
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

  String _inferVideoMime(XFile file) {
    final mimeType = file.mimeType?.trim();
    if (mimeType != null && mimeType.startsWith('video/')) {
      return mimeType;
    }

    final name = file.name.toLowerCase();
    if (name.endsWith('.webm')) return 'video/webm';
    if (name.endsWith('.mov')) return 'video/quicktime';
    return 'video/mp4';
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

  String _extractDataUrlMime(String dataUrl) {
    final match = RegExp(r'^data:([^;]+);base64,', caseSensitive: false).firstMatch(dataUrl);
    return match?.group(1) ?? '';
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

  void _imageLog(String message) {
    developer.log(message, name: 'KatsKlubImagePrepare');
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

class PreparedVideo {
  const PreparedVideo({
    required this.name,
    required this.dataUrl,
    required this.byteCount,
    required this.mimeType,
  });

  final String name;
  final String dataUrl;
  final int byteCount;
  final String mimeType;
}
