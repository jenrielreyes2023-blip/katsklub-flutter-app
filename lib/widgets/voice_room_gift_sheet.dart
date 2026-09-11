import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_room.dart';
import '../services/voice_room_controller.dart';
import '../services/wallet_service.dart';
import 'custom_icons.dart';

/// Cute WePlay-style Virtual Gift Tray Drawer
class VoiceRoomGiftSheet extends StatefulWidget {
  const VoiceRoomGiftSheet({
    super.key,
    required this.room,
    this.initialReceiver,
  });

  final VoiceRoom room;
  final VoiceRoomUser? initialReceiver;

  static Future<void> show(
    BuildContext context, {
    required VoiceRoom room,
    VoiceRoomUser? initialReceiver,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VoiceRoomGiftSheet(
        room: room,
        initialReceiver: initialReceiver,
      ),
    );
  }

  @override
  State<VoiceRoomGiftSheet> createState() => _VoiceRoomGiftSheetState();
}

class _VoiceRoomGiftSheetState extends State<VoiceRoomGiftSheet> {
  late VoiceRoomUser _selectedReceiver;
  VoiceRoomGift _selectedGift = VoiceRoomGift.availableGifts.first;
  double _myCoins = 0.0;
  bool _isLoadingWallet = true;

  @override
  void initState() {
    super.initState();
    _selectedReceiver = widget.initialReceiver ?? widget.room.host;
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final balance = await WalletService().fetchBalance();
      if (mounted) {
        setState(() {
          _myCoins = balance.balanceCents / 100.0;
          _isLoadingWallet = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  List<VoiceRoomUser> _getPossibleRecipients() {
    final list = <VoiceRoomUser>[widget.room.host];
    for (final seat in widget.room.seats) {
      if (seat.user != null && seat.user!.id != widget.room.host.id) {
        if (!list.any((u) => u.id == seat.user!.id)) {
          list.add(seat.user!);
        }
      }
    }
    return list;
  }

  Future<void> _sendGift() async {
    if (_myCoins < _selectedGift.coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Kats Coins. Top up in your profile!'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    await VoiceRoomController().sendGift(_selectedGift, _selectedReceiver);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent ${_selectedGift.name} to ${_selectedReceiver.fullName}!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipients = _getPossibleRecipients();

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 14.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF18191C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          SizedBox(height: 12.h),

          // Header & Balance
          Row(
            children: [
              CustomIcons.giftBox(color: const Color(0xFFFF7A45), size: 18),
              SizedBox(width: 8.w),
              Text(
                'Send Gift',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CustomIcons.coinToken(color: const Color(0xFFFFB800), size: 13),
                    SizedBox(width: 5.w),
                    Text(
                      _isLoadingWallet ? '...' : '${_myCoins.toStringAsFixed(1)} KC',
                      style: TextStyle(
                        color: const Color(0xFFFFB800),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Receiver Selector
          Text(
            'To:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 44.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recipients.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final r = recipients[index];
                final isSelected = r.id == _selectedReceiver.id;
                final isHost = r.id == widget.room.host.id;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedReceiver = r;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7A45).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF7A45)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12.r,
                          backgroundColor: Colors.white10,
                          backgroundImage: r.avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(r.avatarUrl)
                              : null,
                          child: r.avatarUrl.isEmpty
                              ? const Icon(Icons.person, size: 12, color: Colors.white70)
                              : null,
                        ),
                        SizedBox(width: 6.w),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isHost) ...[
                              CustomIcons.crown(color: const Color(0xFFFFB800), size: 11),
                              SizedBox(width: 4.w),
                            ],
                            Text(
                              r.fullName,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFFF7A45) : Colors.white,
                                fontSize: 12.sp,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 16.h),

          // Gift Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: VoiceRoomGift.availableGifts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final gift = VoiceRoomGift.availableGifts[index];
              final isSelected = gift.id == _selectedGift.id;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGift = gift;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF7A45).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF7A45)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFFF7A45).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        child: Center(
                          child: CustomIcons.giftBox(
                            color: isSelected ? const Color(0xFFFF7A45) : Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              gift.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                CustomIcons.coinToken(color: const Color(0xFFFFB800), size: 10),
                                SizedBox(width: 4.w),
                                Text(
                                  '${gift.coins.toStringAsFixed(0)} KC',
                                  style: TextStyle(
                                    color: const Color(0xFFFFB800),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 18.h),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton(
              onPressed: _sendGift,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
              child: Text(
                'Send ${_selectedGift.name} (${_selectedGift.coins.toStringAsFixed(0)} KC)',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
