import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/youtube_service.dart';
import '../widgets/create_post_composer.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    required this.user,
    this.onPostCreated,
    this.initialYouTubeVideo,
    super.key,
  });

  final User user;
  final VoidCallback? onPostCreated;
  final YouTubeVideoItem? initialYouTubeVideo;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  int _composerKey = 0;

  void _handlePostCreated() {
    setState(() {
      _composerKey++;
    });

    widget.onPostCreated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Created.')),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CreatePostComposer(
      key: ValueKey(_composerKey),
      user: widget.user,
      onPostCreated: _handlePostCreated,
      initialYouTubeVideo: widget.initialYouTubeVideo,
    );
  }
}
