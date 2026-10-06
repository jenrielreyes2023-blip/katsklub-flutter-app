import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_icons.dart';
import '../../widgets/voice_room_card.dart';
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
                          CustomIcons.roomCategory(
                            cat,
                            color: isSelected
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
                          // Pre-build upcoming rows offscreen so new cards are
                          // already rasterized when they scroll into view.
                          scrollCacheExtent: ScrollCacheExtent.pixels(600),
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
                            return VoiceRoomCard(
                              room: room,
                              onTap: () {
                                if (_currentUser != null) {
                                  VoiceRoomPinScreen.tryOpen(context, room, _currentUser!);
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
