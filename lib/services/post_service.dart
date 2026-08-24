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
import 'feed_service.dart';

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
    this.reelImages = const <SelectedPostImage>[],
    this.videoDataUrl,
    this.videoTitle,
    this.videoVolume = 1.0,
    this.musicTitle,
    this.musicArtist,
    this.musicArtworkUrl,
    this.musicPreviewUrl,
    this.musicSource,
    this.isPoll = false,
    this.pollQuestion,
    this.pollOptions = const <String>[],
    this.pollDurationHours = 24,
    this.withUserIds = const <String>[],
    this.isSensitive = false,
    this.isGhost = false,
    this.location,
    this.feeling,
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
  final List<SelectedPostImage> reelImages;
  final String? videoDataUrl;
  final String? videoTitle;
  final double videoVolume;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicArtworkUrl;
  final String? musicPreviewUrl;
  final String? musicSource;
  final bool isPoll;
  final String? pollQuestion;
  final List<String> pollOptions;
  final int pollDurationHours;
  final List<String> withUserIds;
  final bool isSensitive;
  final bool isGhost;
  final String? location;
  final String? feeling;
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
    _imageLog(
        'image picker duration=${pickWatch.elapsedMilliseconds}ms; count=${images.length}');

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

      final prepared =
          await _prepareSelectedImage(placeholder, originalBytes, originalMime);
      selected.add(prepared);
      onImageUpdated?.call(prepared);
      index++;
    }

    onProgress
        ?.call(const CreatePostProgress(message: 'Images ready.', progress: 1));
    return selected;
  }

  Future<SelectedPostImage?> addImageFromBytes({
    required Uint8List bytes,
    required String mimeType,
    String? suggestedName,
    SelectedPostImageCallback? onImageSelected,
    SelectedPostImageCallback? onImageUpdated,
  }) async {
    if (bytes.isEmpty) return null;

    final normalizedMime =
        mimeType.startsWith('image/') ? mimeType : 'image/png';
    final ext = _extensionForMime(normalizedMime);
    final batchId = DateTime.now().microsecondsSinceEpoch;
    final name = (suggestedName?.trim().isNotEmpty == true)
        ? suggestedName!.trim()
        : 'pasted-$batchId$ext';

    final xfile = XFile.fromData(
      bytes,
      name: name,
      mimeType: normalizedMime,
      length: bytes.length,
    );

    final placeholder = SelectedPostImage(
      id: '$batchId-pasted-$name',
      file: xfile,
      dataUrl: '',
      previewBytes: bytes,
      mimeType: normalizedMime,
      originalByteCount: bytes.length,
      uploadByteCount: 0,
      optimized: false,
      status: SelectedPostImageStatus.preparing,
    );
    onImageSelected?.call(placeholder);

    final prepared =
        await _prepareSelectedImage(placeholder, bytes, normalizedMime);
    onImageUpdated?.call(prepared);
    return prepared;
  }

  String _extensionForMime(String mime) {
    switch (mime) {
      case 'image/png':
        return '.png';
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      default:
        return '.png';
    }
  }

  Future<CreatePostResult> createPost(CreatePostRequest request) async {
    final text = request.text.trim();
    final readyImages = request.images.where((image) => image.isReady).toList();
    final hasImages = readyImages.isNotEmpty;
    final albumTitle = request.albumTitle?.trim() ?? '';
    final discussionTitle = request.discussionTitle?.trim() ?? '';
    final hasVideo = request.videoDataUrl?.trim().isNotEmpty == true;
    final musicTitle = request.musicTitle?.trim() ?? '';
    final musicArtist = request.musicArtist?.trim() ?? '';
    final musicArtworkUrl = request.musicArtworkUrl?.trim() ?? '';
    final musicPreviewUrl = request.musicPreviewUrl?.trim() ?? '';
    final musicSource = request.musicSource?.trim() ?? '';
    final hasMusicPreview = musicPreviewUrl.isNotEmpty;
    final hasReelImage = request.reelImage?.isReady == true;
    final readyReelImages =
        request.reelImages.where((image) => image.isReady).toList();
    final hasReelImages = readyReelImages.isNotEmpty;
    final pollQuestion = request.pollQuestion?.trim() ?? '';
    final pollOptions = request.pollOptions
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    final hasDiscussionCover =
        request.discussionCoverDataUrl?.trim().isNotEmpty == true;
    final normalizedVisibility = _normalizeVisibility(request.visibility);
    final uploadImageCount = readyImages.length +
        (hasReelImage ? 1 : 0) +
        readyReelImages.length +
        (hasDiscussionCover ? 1 : 0);
    final hasMediaUpload = uploadImageCount > 0 || hasVideo;
    final mode = request.isDiscussion
        ? 'discussion'
        : request.isPoll
            ? 'poll'
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

    if (request.isPoll && (pollQuestion.isEmpty || pollOptions.length < 2)) {
      return const CreatePostResult(
        ok: false,
        error: 'Add a poll question and at least two options.',
      );
    }

    if (request.isReel &&
        text.isEmpty &&
        !hasReelImage &&
        !hasReelImages &&
        !hasVideo) {
      return const CreatePostResult(
        ok: false,
        error: 'Add a caption, image, or video before posting a reel.',
      );
    }

    if (request.reelImages.any((image) => !image.isReady)) {
      return const CreatePostResult(
        ok: false,
        error: 'Please wait until all reel images are ready.',
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
        !request.isPoll &&
        !request.isReel &&
        !hasVideo &&
        !hasMusicPreview) {
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
      if (!request.isDiscussion && !request.isReel)
        'visibility': normalizedVisibility,
      if (hasImages)
        'imageDataUrls': readyImages.map((image) => image.dataUrl).toList(),
      if (albumTitle.isNotEmpty) 'albumTitle': albumTitle,
      if (request.isDiscussion) 'isDiscussion': true,
      if (request.isDiscussion && discussionTitle.isNotEmpty)
        'discussionTitle': discussionTitle,
      if (request.discussionCoverDataUrl?.trim().isNotEmpty == true)
        'discussionCoverDataUrl': request.discussionCoverDataUrl!.trim(),
      if (request.isPoll) 'isPoll': true,
      if (request.isPoll) 'pollQuestion': pollQuestion,
      if (request.isPoll) 'pollOptions': pollOptions,
      if (request.isPoll) 'pollDurationHours': request.pollDurationHours,
      if (request.isReel) 'isReel': true,
      if (request.isReel && hasReelImage)
        'imageDataUrl': request.reelImage!.dataUrl,
      if (request.isReel && hasReelImages)
        'reelImageDataUrls':
            readyReelImages.map((image) => image.dataUrl).toList(),
      if (hasVideo) 'videoDataUrl': request.videoDataUrl!.trim(),
      if (request.isReel && hasVideo && request.videoVolume < 1.0)
        'videoVolume': request.videoVolume.clamp(0.0, 1.0),
      if (!request.isReel && request.videoTitle?.trim().isNotEmpty == true)
        'videoTitle': request.videoTitle!.trim(),
      if (hasMusicPreview) 'musicTitle': musicTitle,
      if (hasMusicPreview) 'musicArtist': musicArtist,
      if (hasMusicPreview) 'musicArtworkUrl': musicArtworkUrl,
      if (hasMusicPreview) 'musicPreviewUrl': musicPreviewUrl,
      if (hasMusicPreview) 'musicSource': musicSource,
      if (request.withUserIds.isNotEmpty) 'withUserIds': request.withUserIds,
      'isSensitive': request.isSensitive,
      'isGhost': request.isGhost,
      if (request.location != null && request.location!.isNotEmpty)
        'location': request.location,
      if (request.feeling != null && request.feeling!.isNotEmpty)
        'feeling': request.feeling,
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
          readyReelImages.fold<int>(
            0,
            (total, image) => total + image.uploadByteCount,
          ) +
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
        'imageCount=${hasImages ? readyImages.length : (hasReelImage ? 1 : 0) + readyReelImages.length}; '
        'hasVideo=$hasVideo; '
        'hasMusicPreview=$hasMusicPreview; '
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
          .setAckTimeout(hasVideo ? 300000 : (hasMediaUpload ? 120000 : 65000))
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
        if (post == null ||
            !_looksLikeCreatedPost(post, text, readyImages.length)) {
          return;
        }

        _socketLog(
            '$eventName received before ACK; treating matching created post as success');
        totalPostWatch.stop();
        _socketLog(
            'total post duration=${totalPostWatch.elapsedMilliseconds}ms via $eventName');
        request.onProgress?.call(
          const CreatePostProgress(
            message: 'Post created.',
            progress: 1,
          ),
        );
        FeedService.notifyPostCreated(post);
        unawaited(FeedService().prependCachedHomePost(post));
        completer.complete(CreatePostResult(ok: true, post: post));
      }

      final timeoutDuration = hasVideo ? 300 : (hasMediaUpload ? 120 : 65);
      timeout = Timer(Duration(seconds: timeoutDuration), () {
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
        _socketLog(
            'socket connect duration=${connectWatch.elapsedMilliseconds}ms');
        final ackWatch = Stopwatch()..start();
        _socketLog(
          'connected before emit; connected=${socket?.connected == true}; id=${socket?.id ?? 'unknown'}',
        );
        request.onProgress?.call(
          CreatePostProgress(
            message:
                hasMediaUpload ? 'Uploading prepared media...' : 'Posting...',
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
                _socketLog(
                    'total post duration=${totalPostWatch.elapsedMilliseconds}ms via ACK');
                _socketLog('ACK success; payloadKeys=${payload.keys.toList()}');
                request.onProgress?.call(
                  const CreatePostProgress(
                    message: 'Post created.',
                    progress: 1,
                  ),
                );
                final createdPost =
                    Post.fromJson(Map<String, dynamic>.from(rawPost));
                FeedService.notifyPostCreated(createdPost);
                unawaited(FeedService().prependCachedHomePost(createdPost));
                completer.complete(
                  CreatePostResult(
                    ok: true,
                    post: createdPost,
                  ),
                );
                return;
              }
            }

            final error = response is Map
                ? response['error']?.toString()
                : 'Failed to create post.';
            _socketLog(
                'ACK error; error=$error; payloadKeys=${payload.keys.toList()}');
            completer.complete(
              CreatePostResult(
                ok: false,
                error: error?.isNotEmpty == true
                    ? error
                    : 'Failed to create post.',
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
    final cookie = prefs.getString(AuthService.sessionCookieKey);
    if (cookie != null && cookie.trim().isNotEmpty) {
      return _normalizeCookieHeader(cookie);
    }
    final token = prefs.getString('katsklub_auth_token');
    if (token != null && token.trim().isNotEmpty) {
      return 'katsklub_session=${token.trim()}; katsklub_auth_token=${token.trim()}';
    }
    return null;
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

    onProgress?.call(const CreatePostProgress(
        message: 'Preparing video...', progress: null));
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
      previewPath: picked.path,
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
      _imageLog(
          'GIF selected; preserving original bytes=${originalBytes.length}');
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

    if (webpBytes.isNotEmpty &&
        webpBytes.length < originalBytes.length * 0.95) {
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

    if (sessionCookie != null &&
        sessionCookie.length > 'katsklub_session='.length) {
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
    final match = RegExp(r'^data:([^;]+);base64,', caseSensitive: false)
        .firstMatch(dataUrl);
    return match?.group(1) ?? '';
  }

  Post? _readPostFromSocketEvent(dynamic data) {
    if (data is Map) {
      final raw = data['post'] is Map ? data['post'] as Map : data;
      try {
        return Post.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {}
    }
    return null;
  }

  bool _looksLikeCreatedPost(Post post, String text, int imageCount) {
    if (post.text.trim() == text.trim()) return true;
    if (text.trim().isEmpty) return true;
    if (post.text.trim().isNotEmpty && (text.trim().contains(post.text.trim()) || post.text.trim().contains(text.trim()))) return true;
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
    this.previewPath,
  });

  final String name;
  final String dataUrl;
  final int byteCount;
  final String mimeType;
  final String? previewPath;
}
