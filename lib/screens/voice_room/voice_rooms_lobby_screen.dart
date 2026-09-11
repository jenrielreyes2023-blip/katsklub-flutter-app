import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_icons.dart';
import 'create_voice_room_screen.dart';
import 'voice_room_pin_screen.dart';

/// Lobby Screen to browse, search, and create WePlay-style live Voice Rooms
class VoiceRoomsLobbyScreen extends StatefulWidget {
  const VoiceRoomsLobbyScreen({super.key});

  @override
  State<VoiceRoomsLobbyScreen> createState() => _VoiceRoomsLobbyScreenState();
}

class _VoiceRoomsLobbyScreenState extends State<VoiceRoomsLobbyScreen> {
  List<VoiceRoom> _rooms = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  User? _currentUser;

  final List<String> _categories = [
    'All',
    'Chill',
    'Gaming',
    'Music',
    'Chat',
  ];

  Widget _getCategoryIcon(String cat, Color color, {double size = 13}) {
    switch (cat.toLowerCase()) {
      case 'chill':
        return CustomIcons.coffeeCup(color: color, size: size);
      case 'gaming':
        return CustomIcons.gamepad(color: color, size: size);
      case 'music':
        return CustomIcons.musicNote(color: color, size: size);
      case 'chat':
      case 'kwentuhan':
        return CustomIcons.chatBubble(color: color, size: size);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchRooms();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService().getSavedUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(ApiConfig.uri('/api/voice-rooms'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['rooms'] is List) {
          final list = (data['rooms'] as List)
              .map((r) => VoiceRoom.fromJson(Map<String, dynamic>.from(r)))
              .toList();
          if (mounted) {
            setState(() {
              _rooms = list;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[VoiceRoomsLobby] Error fetching rooms: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }



  Future<void> _navigateToCreateRoom() async {
    if (_currentUser == null) return;
    final didCreate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => CreateVoiceRoomScreen(
          currentUser: _currentUser!,
          existingRooms: _rooms,
        ),
      ),
    );
    if (didCreate == true) {
      _fetchRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _selectedCategory == 'All'
        ? _rooms
        : _rooms.where((r) => r.category.toLowerCase().contains(
            _selectedCategory.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1015),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CustomIcons.micParty(color: const Color(0xFFFF7A45), size: 18),
            const SizedBox(width: 8),
            const Text(
              'Party Rooms',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _fetchRooms,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateRoom,
        backgroundColor: const Color(0xFFFF7A45),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Create Room',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek Inline Category Filter Chips
          SizedBox(
            height: 30.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 6.w),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7A45).withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF7A45).withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.07),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat != 'All') ...[
                          _getCategoryIcon(
                            cat,
                            isSelected
                                ? const Color(0xFFFF7A45)
                                : Colors.white.withValues(alpha: 0.5),
                            size: 11.5,
                          ),
                          SizedBox(width: 4.w),
                        ],
                        Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFF7A45)
                                : Colors.white.withValues(alpha: 0.65),
                            fontSize: 11.sp,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 10.h),

          // Rooms List / Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF7A45)),
                  )
                : filteredRooms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_none_rounded,
                              size: 56.r,
                              color: Colors.white24,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'No live party rooms right now',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Tap "+ Create Room" to start the party!',
                              style: TextStyle(
                                color: const Color(0xFFFF7A45),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchRooms,
                        color: const Color(0xFFFF7A45),
                        child: GridView.builder(
                          padding: EdgeInsets.only(
                            left: 14.w,
                            right: 14.w,
                            top: 8.h,
                            bottom: 80.h,
                          ),
                          itemCount: filteredRooms.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            final room = filteredRooms[index];
                            return _buildRoomCard(room);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(VoiceRoom room) {
    return GestureDetector(
      onTap: () {
        if (_currentUser != null) {
          VoiceRoomPinScreen.tryOpen(context, room, _currentUser!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Card Face Image: Room Cover / Icon
              if (room.coverUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: room.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF1E2028),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF141519),
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white24, size: 36),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF22242C), Color(0xFF121317)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white.withValues(alpha: 0.08),
                      size: 48.r,
                    ),
                  ),
                ),

              // 2. Gradient Scrim Overlay for Readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.65, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.65),
                        const Color(0xFF0F1015).withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Foreground Content
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Category tag + Rule Badge + LIVE pill + Lock
                    Row(
                      children: [
                        // Category Chip
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _getCategoryIcon(room.category, const Color(0xFFFF7A45), size: 10),
                              SizedBox(width: 3.w),
                              Text(
                                room.category,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 4.w),

                        // Rule Badge (Permanent crown / 24h Temp)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.5.h),
                          decoration: BoxDecoration(
                            color: room.isPermanent
                                ? const Color(0xFFFFB800).withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: room.isPermanent
                                  ? const Color(0xFFFFB800).withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (room.isPermanent)
                                CustomIcons.crown(color: const Color(0xFFFFB800), size: 8)
                              else
                                const Icon(Icons.access_time_rounded, color: Colors.white70, size: 8.5),
                              SizedBox(width: 2.5.w),
                              Text(
                                room.durationBadgeText,
                                style: TextStyle(
                                  color: room.isPermanent ? const Color(0xFFFFB800) : Colors.white70,
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // LIVE Pill
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: const Color(0xFF10B981),
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (room.isLocked) ...[
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 9),
                          ),
                        ],
                      ],
                    ),

                    const Spacer(),

                    // Host Info Row (Host Avatar + Host Name + Mics)
                    Row(
                      children: [
                        Container(
                          width: 18.r,
                          height: 18.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 1),
                          ),
                          child: ClipOval(
                            child: room.host.avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: room.host.avatarUrl,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.person, color: Colors.white, size: 12),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: Text(
                            room.host.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        // Active Mics Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_rounded, size: 9.5.r, color: Colors.white70),
                              SizedBox(width: 2.w),
                              Text(
                                '${room.occupiedSeatsCount}/8',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4.h),

                    // Room Title
                    Text(
                      room.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
