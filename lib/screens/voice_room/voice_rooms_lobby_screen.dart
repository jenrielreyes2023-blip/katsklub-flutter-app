import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/auth_service.dart';
import 'voice_room_screen.dart';

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
    'Chill ☕',
    'Gaming 🎮',
    'Music 🎶',
    'Kwentuhan 💬',
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

  void _showCreateRoomSheet() {
    final titleController = TextEditingController();
    String category = 'Chat';
    String theme = 'cosmic_night';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18191C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 18.w,
              right: 18.w,
              top: 16.h,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Create Voice Room 🎙️',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Chill Kwentuhan & Tugtugan 🎶',
                    hintStyle: const TextStyle(color: Colors.white38),
                    labelText: 'Room Topic / Title',
                    labelStyle: const TextStyle(color: Color(0xFFFF7A45)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  children: ['Chat', 'Music', 'Gaming', 'Chill'].map((c) {
                    final isSel = category == c;
                    return ChoiceChip(
                      label: Text(c),
                      selected: isSel,
                      selectedColor: const Color(0xFFFF7A45),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.white70,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (val) {
                        if (val) setSheetState(() => category = c);
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      Navigator.pop(ctx);
                      final token = await AuthService().getToken();

                      if (!mounted) return;

                      try {
                        final response = await http.post(
                          ApiConfig.uri('/api/voice-rooms'),
                          headers: {
                            'Content-Type': 'application/json',
                            if (token != null) 'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({
                            'title': title,
                            'category': category,
                            'theme': theme,
                          }),
                        );

                        if (!mounted) return;

                        if (response.statusCode == 200 || response.statusCode == 201) {
                          final data = jsonDecode(response.body);
                          if (data['ok'] == true && data['room'] != null) {
                            final room = VoiceRoom.fromJson(
                                Map<String, dynamic>.from(data['room']));
                            if (_currentUser != null) {
                              _fetchRooms();
                              VoiceRoomScreen.open(context, room, _currentUser!);
                            }
                            return;
                          }
                        }
                      } catch (e) {
                        debugPrint('[VoiceRoomsLobby] create room error: $e');
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to create room. Please try again.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A45),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Start Room Now',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _selectedCategory == 'All'
        ? _rooms
        : _rooms.where((r) => r.category.toLowerCase().contains(
            _selectedCategory.split(' ').first.toLowerCase())).toList();

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
            const Text(
              'Party Rooms 🎙️',
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
        onPressed: _showCreateRoomSheet,
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
          // Category Filter Chips
          SizedBox(
            height: 44.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7A45)
                          : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12.sp,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
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
          VoiceRoomScreen.open(context, room, _currentUser!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF26193E), Color(0xFF181528)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category tag + Live dot
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    room.category,
                    style: TextStyle(
                      color: const Color(0xFFFF7A45),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: const Color(0xFF10B981),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Host Avatar with Crown
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: const Color(0xFFFF7A45),
                  backgroundImage: room.host.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(room.host.avatarUrl)
                      : null,
                  child: room.host.avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                Positioned(
                  top: -6,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '👑',
                      style: TextStyle(fontSize: 8),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8.h),

            // Room Title
            Text(
              room.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 4.h),

            // Host name & Listeners count
            Row(
              children: [
                Expanded(
                  child: Text(
                    room.host.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
                Icon(Icons.mic_rounded, size: 12.r, color: Colors.white38),
                SizedBox(width: 2.w),
                Text(
                  '${room.occupiedSeatsCount}/8',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
