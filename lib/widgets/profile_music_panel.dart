import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../screens/playlist_screen.dart';
import '../services/music_service.dart';

class ProfileMusicPanel extends StatefulWidget {
  const ProfileMusicPanel({
    required this.username,
    required this.canManagePlaylists,
    super.key,
  });

  final String username;
  final bool canManagePlaylists;

  @override
  State<ProfileMusicPanel> createState() => _ProfileMusicPanelState();
}

class _ProfileMusicPanelState extends State<ProfileMusicPanel> {
  final MusicService _musicService = MusicService();

  List<Playlist> _playlists = const <Playlist>[];
  List<Playlist> _suggestedPlaylists = const <Playlist>[];
  final Set<int> _cloningPlaylistIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  @override
  void didUpdateWidget(ProfileMusicPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _loadPlaylists();
    }
  }

  Future<void> _loadPlaylists() async {
    final username = widget.username.trim();
    if (username.isEmpty) {
      setState(() {
        _playlists = const <Playlist>[];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final playlists = await _musicService.getUserPlaylists(username);
      if (!mounted || widget.username.trim() != username) {
        return;
      }

      List<Playlist> suggestions = const <Playlist>[];
      if (playlists.isEmpty) {
        try {
          suggestions = await _musicService.getSuggestedPlaylists();
        } catch (_) {}
      }

      setState(() {
        _playlists = playlists;
        _suggestedPlaylists = suggestions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || widget.username.trim() != username) {
        return;
      }

      setState(() {
        _playlists = const <Playlist>[];
        _suggestedPlaylists = const <Playlist>[];
        _isLoading = false;
        _errorMessage = 'Unable to load playlists right now.';
      });
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var isSubmitting = false;
    String? errorMessage;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              if (title.isEmpty || isSubmitting) {
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              final playlist = await _musicService.createPlaylist(
                title: title,
                description: description.isEmpty ? null : description,
              );

              if (playlist == null) {
                setDialogState(() {
                  isSubmitting = false;
                  errorMessage = 'Failed to create playlist.';
                });
                return;
              }

              if (!dialogContext.mounted) {
                return;
              }

              Navigator.of(dialogContext).pop(true);
            }

            return AlertDialog(
              title: const Text('Create playlist'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    enabled: !isSubmitting,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'My favorites',
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    enabled: !isSubmitting,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: Text(isSubmitting ? 'Creating...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (created == true) {
      await _loadPlaylists();
    }
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistScreen(playlistId: playlist.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.canManagePlaylists) ...[
            _CreatePlaylistCard(onTap: _showCreatePlaylistDialog),
            const SizedBox(height: 16),
          ],
          Text(
            'Playlists',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: headerColor,
                ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const _ProfileMusicInfoCard(message: 'Loading playlists...')
          else if (_errorMessage != null)
            _ProfileMusicErrorCard(
              message: _errorMessage!,
              onRetry: _loadPlaylists,
            )
          else if (_playlists.isEmpty) ...[
            const _ProfileMusicInfoCard(message: 'No playlists yet.'),
            if (_suggestedPlaylists.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Suggested Playlists',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: headerColor,
                    ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  for (final playlist in _suggestedPlaylists)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlaylistCard(
                        playlist: playlist,
                        onTap: () => _openPlaylist(playlist),
                        trailing: _buildCloneButton(playlist),
                      ),
                    ),
                ],
              ),
            ],
          ]
          else
            Column(
              children: [
                for (final playlist in _playlists)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlaylistCard(
                      playlist: playlist,
                      onTap: () => _openPlaylist(playlist),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _clonePlaylist(Playlist playlist) async {
    if (_cloningPlaylistIds.contains(playlist.id)) return;
    setState(() {
      _cloningPlaylistIds.add(playlist.id);
    });
    try {
      final cloned = await _musicService.clonePlaylist(playlist.id);
      if (cloned != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${playlist.title}" added to your playlists!')),
        );
        await _loadPlaylists();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add playlist.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding playlist.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cloningPlaylistIds.remove(playlist.id);
        });
      }
    }
  }

  Widget _buildCloneButton(Playlist playlist) {
    final isCloning = _cloningPlaylistIds.contains(playlist.id);
    return isCloning
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7A45)),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.playlist_add_rounded, color: Color(0xFFFF7A45), size: 24),
            tooltip: 'Add to my library',
            onPressed: () => _clonePlaylist(playlist),
          );
  }
}

class _CreatePlaylistCard extends StatelessWidget {
  const _CreatePlaylistCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF242526) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create playlist',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organize your favorite uploaded tracks',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    this.trailing,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF242526) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 72,
                  height: 72,
                  color: isDark ? const Color(0xFF1E1F20) : const Color(0xFF111827),
                  child: playlist.resolvedCoverUrl.isEmpty
                      ? const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 30,
                        )
                      : CachedNetworkImage(
                          imageUrl: playlist.resolvedCoverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF111827),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.description.isEmpty
                          ? 'No description'
                          : playlist.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${playlist.trackCount} ${playlist.trackCount == 1 ? 'track' : 'tracks'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing ?? const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMusicInfoCard extends StatelessWidget {
  const _ProfileMusicInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242526) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF6B7280),
            ),
      ),
    );
  }
}

class _ProfileMusicErrorCard extends StatelessWidget {
  const _ProfileMusicErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF991B1B),
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
