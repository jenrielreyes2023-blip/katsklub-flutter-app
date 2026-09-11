import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/custom_icons.dart';
import 'voice_room_screen.dart';

class CreateVoiceRoomScreen extends StatefulWidget {
  final User currentUser;
  final List<VoiceRoom> existingRooms;

  const CreateVoiceRoomScreen({
    super.key,
    required this.currentUser,
    required this.existingRooms,
  });

  @override
  State<CreateVoiceRoomScreen> createState() => _CreateVoiceRoomScreenState();
}

class _CreateVoiceRoomScreenState extends State<CreateVoiceRoomScreen> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  String _category = 'Chat';
  String _roomType = 'temporary'; // 'temporary' | 'permanent'
  double _myCoins = 0.0;
  bool _isLoadingCoins = true;
  bool _isSubmitting = false;

  VoiceRoom? _userActiveTempRoom;
  VoiceRoom? _userActivePermRoom;

  final List<String> _categories = const ['Chat', 'Music', 'Gaming', 'Chill'];

  @override
  void initState() {
    super.initState();
    _findActiveRooms();
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _findActiveRooms() {
    for (final r in widget.existingRooms) {
      if (r.host.id.toString() == widget.currentUser.id.toString() && r.isActive) {
        if (!r.isPermanent && !r.isExpired) {
          _userActiveTempRoom = r;
        } else if (r.isPermanent) {
          _userActivePermRoom = r;
        }
      }
    }
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final balance = await WalletService().fetchBalance();
      if (mounted) {
        setState(() {
          _myCoins = balance.balanceCents / 100.0;
          _isLoadingCoins = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[CreateVoiceRoom] WalletService fetch error: $e');
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoadingCoins = false);
        return;
      }

      final res = await http.get(
        ApiConfig.uri('/api/wallet'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['ok'] == true) {
          num? raw;
          if (data['balanceCents'] is num) {
            raw = (data['balanceCents'] as num) / 100.0;
          } else if (data['coinsBalance'] is num) {
            raw = data['coinsBalance'] as num;
          } else if (data['balance'] is num) {
            raw = data['balance'] as num;
          } else if (data['coins_balance'] is num) {
            raw = data['coins_balance'] as num;
          } else if (data['wallet'] is Map) {
            final w = data['wallet'] as Map;
            if (w['balanceCents'] is num) {
              raw = (w['balanceCents'] as num) / 100.0;
            } else if (w['coinsBalance'] is num) {
              raw = w['coinsBalance'] as num;
            } else if (w['balance'] is num) {
              raw = w['balance'] as num;
            } else if (w['coins_balance'] is num) {
              raw = w['coins_balance'] as num;
            }
          }

          if (raw != null && mounted) {
            setState(() {
              _myCoins = raw!.toDouble();
              _isLoadingCoins = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[CreateVoiceRoom] Direct wallet fetch error: $e');
    }
    if (mounted) setState(() => _isLoadingCoins = false);
  }

  Future<void> _confirmDissolveActiveRoom() async {
    if (_userActiveTempRoom == null) return;
    final active = _userActiveTempRoom!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Dissolve Room?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to dissolve "${active.title}"?\n\nAll participants will be disconnected and the room will be closed permanently.',
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Dissolve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      var res = await http.post(
        ApiConfig.uri('/api/voice-rooms/${active.id}/close'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 404) {
        res = await http.post(
          ApiConfig.uri('/api/voice-rooms/${active.id}/dissolve'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
      }

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _userActiveTempRoom = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Room "${active.title}" dissolved successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to dissolve room. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[CreateVoiceRoom] Dissolve room error: $e');
    }
  }

  Future<void> _handleCreateRoom() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a room title.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final isPermanent = _roomType == 'permanent';
    if (isPermanent && _userActivePermRoom != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You already own an active permanent room ("${_userActivePermRoom!.title}"). Only 1 permanent room is allowed per user.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (isPermanent && _myCoins < 199.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient KatsCoins. 199 KC required for permanent rooms.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!isPermanent && _userActiveTempRoom != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please dissolve your existing temporary room before creating a new one.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await AuthService().getToken();
      final response = await http.post(
        ApiConfig.uri('/api/voice-rooms'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'category': _category,
          'theme': 'cosmic_night',
          'roomType': _roomType,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true && data['room'] != null) {
          final room = VoiceRoom.fromJson(Map<String, dynamic>.from(data['room']));
          Navigator.of(context).pop(true);
          VoiceRoomScreen.open(context, room, widget.currentUser);
          return;
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['error'].toString()),
                backgroundColor: Colors.redAccent,
              ),
            );
            setState(() => _isSubmitting = false);
            return;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CreateVoiceRoom] Create room error: $e');
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create room. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPermanent = _roomType == 'permanent';
    final hasEnoughCoins = _myCoins >= 199.0;
    final hasActiveTemp = !isPermanent && _userActiveTempRoom != null;
    final hasActivePerm = isPermanent && _userActivePermRoom != null;
    final canSubmit = !_isSubmitting &&
        (isPermanent ? (hasEnoughCoins && !hasActivePerm) : !hasActiveTemp);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1015),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Voice Room',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Title
                    const Text(
                      'Room Title',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Acoustic & Late Night Chill',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF17181F),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),

                    SizedBox(height: 22.h),

                    // Section: Category (Minimalist Black / White / Gray Pills)
                    const Text(
                      'Category',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: _categories.map((cat) {
                        final isSelected = _category == cat;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _category = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: EdgeInsets.only(right: cat != _categories.last ? 6.w : 0),
                              padding: EdgeInsets.symmetric(vertical: 9.h),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF17181F),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                cat,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white70,
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 22.h),

                    // Section: Room Duration & Rule
                    const Text(
                      'Duration & Access',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // 24h Free Room Tile (Monochrome Neutral Dark Card)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _roomType = 'temporary');
                      },
                      child: Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17181F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: !isPermanent
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                            width: !isPermanent ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18.w,
                              height: 18.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !isPermanent ? Colors.white : Colors.white24,
                                  width: !isPermanent ? 5 : 1.5,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '24-Hour Room',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'FREE',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Dissolves automatically after 24 hours. Limited to 1 active room.',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11.sp,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // Permanent Room Tile (Monochrome Neutral Dark Card with Subtle Gold Token)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (_userActivePermRoom != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('You already own an active permanent room ("${_userActivePermRoom!.title}"). Only 1 permanent room is allowed per user.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        setState(() => _roomType = 'permanent');
                      },
                      child: Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17181F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPermanent
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                            width: isPermanent ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18.w,
                              height: 18.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isPermanent
                                      ? Colors.white
                                      : (_userActivePermRoom != null
                                          ? Colors.white12
                                          : Colors.white24),
                                  width: isPermanent ? 5 : 1.5,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Permanent Room',
                                        style: TextStyle(
                                          color: _userActivePermRoom != null && !isPermanent
                                              ? Colors.white54
                                              : Colors.white,
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_userActivePermRoom != null) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'OWNED (1/1)',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CustomIcons.coinToken(
                                                color: const Color(0xFFFFB800),
                                                size: 9,
                                              ),
                                              SizedBox(width: 3.w),
                                              Text(
                                                '199 KC',
                                                style: TextStyle(
                                                  color: const Color(0xFFFFB800),
                                                  fontSize: 9.sp,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    _userActivePermRoom != null
                                        ? 'You already own an active permanent room ("${_userActivePermRoom!.title}"). Only 1 permanent room is allowed.'
                                        : 'Never dissolves. Stays available indefinitely as your personal lounge.',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11.sp,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Balance status when Permanent selected
                    if (isPermanent) ...[
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14151C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            CustomIcons.coinToken(
                              color: hasEnoughCoins ? const Color(0xFFFFB800) : Colors.white38,
                              size: 13,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              _isLoadingCoins
                                  ? 'Checking wallet balance...'
                                  : 'Wallet: ${_myCoins.toStringAsFixed(1)} KC',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (!hasEnoughCoins && !_isLoadingCoins)
                              Text(
                                'Need ${(199 - _myCoins).toStringAsFixed(1)} KC more',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Active Temporary Room Warning Card (Neutral Studio Style)
                    if (hasActiveTemp) ...[
                      SizedBox(height: 14.h),
                      Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF191A22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: Colors.white70, size: 16),
                                SizedBox(width: 6.w),
                                Text(
                                  'Active Temporary Room Exists',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              '"${_userActiveTempRoom!.title}"',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Only 1 temporary room is allowed per host. Please dissolve your active room before creating a new one.',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11.sp,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _confirmDissolveActiveRoom,
                                icon: const Icon(Icons.delete_sweep_rounded,
                                    color: Colors.white70, size: 14),
                                label: const Text(
                                  'Dissolve Active Room',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Submit Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: canSubmit ? _handleCreateRoom : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    foregroundColor: canSubmit ? Colors.black : Colors.white38,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          isPermanent
                              ? (hasActivePerm
                                  ? 'Permanent Room Owned (1/1 Limit)'
                                  : (hasEnoughCoins
                                      ? 'Create Permanent Room (199 KC)'
                                      : 'Insufficient KC (199 KC Required)'))
                              : (hasActiveTemp
                                  ? 'Dissolve Active Room First'
                                  : 'Create 24-Hour Room'),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
