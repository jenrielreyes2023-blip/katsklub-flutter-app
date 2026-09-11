import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../models/user.dart';
import '../../models/voice_room.dart';
import '../../services/auth_service.dart';
import '../../services/feed_service.dart';
import '../../services/voice_room_controller.dart';
import '../../widgets/custom_icons.dart';

/// Dedicated Full Screen to Edit Voice Room Details, Icon, Description & Admins
class EditVoiceRoomScreen extends StatefulWidget {
  final VoiceRoom room;
  final VoiceRoomController controller;

  const EditVoiceRoomScreen({
    super.key,
    required this.room,
    required this.controller,
  });

  static Future<bool?> open(
    BuildContext context,
    VoiceRoom room,
    VoiceRoomController controller,
  ) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => EditVoiceRoomScreen(room: room, controller: controller),
      ),
    );
  }

  @override
  State<EditVoiceRoomScreen> createState() => _EditVoiceRoomScreenState();
}

class _EditVoiceRoomScreenState extends State<EditVoiceRoomScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  XFile? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  bool _isSaving = false;
  String _savingStatus = 'Saving...';
  String? _errorMessage;

  List<VoiceRoomUser> _admins = [];
  bool _isLoadingAdmins = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.room.title);
    _descriptionController = TextEditingController(text: widget.room.description);
    try {
      _admins = List<VoiceRoomUser>.from(widget.room.admins);
    } catch (_) {
      _admins = <VoiceRoomUser>[];
    }
    _loadAdmins();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoadingAdmins = true);
    try {
      final list = await widget.controller.fetchAdmins(widget.room.id);
      if (mounted) {
        setState(() {
          _admins = list;
          _isLoadingAdmins = false;
        });
      }
    } catch (e) {
      debugPrint('[EditVoiceRoom] Error loading admins: $e');
      if (mounted) setState(() => _isLoadingAdmins = false);
    }
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Room ID copied: ${widget.room.roomCode}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    if (_isSaving) return;
    HapticFeedback.selectionClick();

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pickedImageFile = picked;
        _pickedImageBytes = bytes;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[EditVoiceRoom] Image pick error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not access gallery. Please try again.';
        });
      }
    }
  }

  void _clearPickedImage() {
    HapticFeedback.selectionClick();
    setState(() {
      _pickedImageFile = null;
      _pickedImageBytes = null;
    });
  }

  Future<String?> _uploadImageToR2(Uint8List bytes, String filename) async {
    try {
      final token = await AuthService().getToken();
      final uri = ApiConfig.uri('/api/upload/image');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename.isNotEmpty ? filename : 'room_icon_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          return (data['url'] ?? data['fileUrl'])?.toString();
        }
      }
    } catch (e) {
      debugPrint('[EditVoiceRoom] Image upload failed: $e');
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) return;

    final newTitle = _titleController.text.trim();
    final newDescription = _descriptionController.text.trim();
    final hasNewImage = _pickedImageBytes != null;
    final hasTitleChanged = newTitle != widget.room.title;
    final hasDescChanged = newDescription != widget.room.description;

    if (!hasNewImage && !hasTitleChanged && !hasDescChanged) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _savingStatus = hasNewImage ? 'Uploading room icon...' : 'Saving changes...';
    });

    String? uploadedCoverUrl;

    if (hasNewImage) {
      uploadedCoverUrl = await _uploadImageToR2(
        _pickedImageBytes!,
        _pickedImageFile?.name ?? 'room_icon.jpg',
      );

      if (uploadedCoverUrl == null || uploadedCoverUrl.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to upload image. Please try again.';
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _savingStatus = 'Updating room details...';
    });

    final ok = await widget.controller.updateRoomInfo(
      title: hasTitleChanged ? newTitle : null,
      coverUrl: uploadedCoverUrl ?? (hasNewImage ? uploadedCoverUrl : null),
      description: hasDescChanged ? newDescription : null,
    );

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room details updated successfully.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to update room. Please try again.';
      });
    }
  }

  Future<void> _removeAdmin(VoiceRoomUser admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to remove @${admin.username} as an admin of this room?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.selectionClick();
    final ok = await widget.controller.removeAdmin(widget.room.id, admin.id);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _admins.removeWhere((a) => a.id == admin.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@${admin.username} removed as admin.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove admin. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAddAdminSheet() {
    if (_admins.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum of 4 admins reached for this room.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14151C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddAdminSheet(
        roomId: widget.room.id,
        hostId: widget.room.host.id,
        currentAdmins: _admins,
        controller: widget.controller,
        onAdminAdded: (newAdmin) {
          setState(() {
            if (!_admins.any((a) => a.id == newAdmin.id)) {
              _admins.add(newAdmin);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1015),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Room',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2.h),
            InkWell(
              onTap: _copyRoomId,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ID: ${widget.room.roomCode}',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.copy_rounded,
                      color: const Color(0xFFFF7A45),
                      size: 11.5.sp,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: const Color(0xFFFF7A45),
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 8.h),

                // Center Circular Room Icon with Edit Sign
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _isSaving ? null : _pickImageFromGallery,
                        child: Container(
                          width: 104.r,
                          height: 104.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF17181F),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _buildIconPreview(),
                          ),
                        ),
                      ),

                      // Edit Sign Overlay Badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isSaving ? null : _pickImageFromGallery,
                          child: Container(
                            width: 32.r,
                            height: 32.r,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7A45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0F1015),
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10.h),

                // Icon Action Buttons & Labels
                Text(
                  _pickedImageBytes != null ? 'New Icon Selected' : 'Set Room Icon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Tap circle to select an icon preview for your room',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11.sp,
                  ),
                ),

                if (_pickedImageBytes != null) ...[
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _isSaving ? null : _pickImageFromGallery,
                        icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white70),
                        label: Text(
                          'Choose Another',
                          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      TextButton.icon(
                        onPressed: _isSaving ? null : _clearPickedImage,
                        icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                        label: Text(
                          'Remove',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 24.h),

                // Room Name
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ROOM NAME',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),

                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  maxLength: 50,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Enter room name',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF17181F),
                    counterStyle: const TextStyle(color: Colors.white30),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFF7A45), width: 1.2),
                    ),
                    suffixIcon: _titleController.text.isNotEmpty && !_isSaving
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.white30, size: 18),
                            onPressed: () {
                              _titleController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a room name';
                    }
                    if (val.trim().length < 2) {
                      return 'Room name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 14.h),

                // Room Description
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ROOM DESCRIPTION',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),

                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  maxLength: 160,
                  maxLines: 3,
                  style: TextStyle(color: Colors.white, fontSize: 13.5.sp, height: 1.3),
                  decoration: InputDecoration(
                    hintText: 'Add a topic or description for your room (e.g. late night acoustic music, chitchat, gaming)...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF17181F),
                    counterStyle: const TextStyle(color: Colors.white30),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFF7A45), width: 1.2),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                SizedBox(height: 18.h),

                // Room Admins Section (Owner + Max 4 Admins)
                _buildAdminsSection(),

                SizedBox(height: 18.h),

                // Room Meta Card
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17181F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildMetaRow('Room Code', widget.room.roomCode),
                      const Divider(color: Colors.white10, height: 16),
                      _buildMetaRow('Category', widget.room.category),
                      const Divider(color: Colors.white10, height: 16),
                      _buildMetaRow(
                        'Room Type',
                        widget.room.isPermanent ? 'Permanent (199 KC)' : '24-Hour Temporary',
                        trailingWidget: widget.room.isPermanent
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomIcons.crown(color: const Color(0xFFFFB800), size: 10),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Permanent',
                                    style: TextStyle(
                                      color: const Color(0xFFFFB800),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildMetaRow('Owner / Host', widget.room.host.fullName),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.redAccent, fontSize: 12.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 28.h),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A45),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: const Color(0xFFFF7A45).withValues(alpha: 0.4),
                    ),
                    child: _isSaving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16.r,
                                height: 16.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                _savingStatus,
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminsSection() {
    final host = widget.room.host;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF17181F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ROOM ADMINS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _admins.length >= 4
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFFFF7A45).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _admins.length >= 4
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFFFF7A45).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${_admins.length}/4 Admins',
                  style: TextStyle(
                    color: _admins.length >= 4 ? const Color(0xFFEF4444) : const Color(0xFFFF7A45),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Owner + maximum 4 admins. Admins can manage speakers, lock seats, and moderate visitors.',
            style: TextStyle(color: Colors.white38, fontSize: 11.sp, height: 1.3),
          ),
          SizedBox(height: 12.h),

          // Owner Card (always shown at top)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFB800).withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: host.avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: host.avatarUrl,
                          width: 34.r,
                          height: 34.r,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _avatarPlaceholder(host.username),
                        )
                      : _avatarPlaceholder(host.username),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        host.fullName.isNotEmpty ? host.fullName : host.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${host.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB800), Color(0xFFFF7A00)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIcons.crown(color: Colors.black, size: 9),
                      SizedBox(width: 3.w),
                      const Text(
                        'OWNER',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Admin Cards
          if (_isLoadingAdmins) ...[
            SizedBox(height: 12.h),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
              ),
            ),
          ] else if (_admins.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _admins.length,
              separatorBuilder: (_, __) => SizedBox(height: 6.h),
              itemBuilder: (context, index) {
                final admin = _admins[index];
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipOval(
                        child: admin.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: admin.avatarUrl,
                                width: 34.r,
                                height: 34.r,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _avatarPlaceholder(admin.username),
                              )
                            : _avatarPlaceholder(admin.username),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin.fullName.isNotEmpty ? admin.fullName : admin.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '@${admin.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 19),
                        tooltip: 'Remove Admin',
                        onPressed: () => _removeAdmin(admin),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          SizedBox(height: 12.h),

          // Add Admin Button
          if (_admins.length < 4)
            InkWell(
              onTap: _openAddAdminSheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A45).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF7A45).withValues(alpha: 0.35),
                    style: BorderStyle.solid,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      color: const Color(0xFFFF7A45),
                      size: 16.r,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Add Room Admin (${4 - _admins.length} slots left)',
                      style: TextStyle(
                        color: const Color(0xFFFF7A45),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(String text) {
    return Container(
      width: 34.r,
      height: 34.r,
      color: const Color(0xFF282932),
      child: Center(
        child: Text(
          text.isNotEmpty ? text[0].toUpperCase() : '?',
          style: TextStyle(color: Colors.white54, fontSize: 13.sp, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildIconPreview() {
    if (_pickedImageBytes != null) {
      return Image.memory(
        _pickedImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (widget.room.coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.room.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: const Color(0xFF17181F),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildDefaultRoomIcon(),
      );
    }

    return _buildDefaultRoomIcon();
  }

  Widget _buildDefaultRoomIcon() {
    return Container(
      color: const Color(0xFF17181F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radio_rounded,
              size: 36.r,
              color: Colors.white38,
            ),
            SizedBox(height: 4.h),
            Text(
              'No Icon',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {Widget? trailingWidget}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 13.sp),
        ),
        trailingWidget ??
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
      ],
    );
  }
}

/// Modal Bottom Sheet to Search & Add Admins from Friendlist or User ID / Username
class _AddAdminSheet extends StatefulWidget {
  final int roomId;
  final int hostId;
  final List<VoiceRoomUser> currentAdmins;
  final VoiceRoomController controller;
  final ValueChanged<VoiceRoomUser> onAdminAdded;

  const _AddAdminSheet({
    required this.roomId,
    required this.hostId,
    required this.currentAdmins,
    required this.controller,
    required this.onAdminAdded,
  });

  @override
  State<_AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends State<_AddAdminSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FeedService _feedService = FeedService();

  List<User> _followingUsers = [];
  bool _isLoadingFollowing = true;

  List<User> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  String? _addingUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFollowingUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowingUsers() async {
    setState(() => _isLoadingFollowing = true);
    try {
      final me = await AuthService().getSavedUser();
      final username = me?.username ?? '';
      if (username.isNotEmpty) {
        final list = await _feedService.getUserFollowing(username);
        if (mounted) {
          setState(() {
            _followingUsers = list;
            _isLoadingFollowing = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[AddAdminSheet] Error fetching following: $e');
    }
    if (mounted) setState(() => _isLoadingFollowing = false);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 380), () async {
      setState(() => _isSearching = true);
      try {
        final results = await _feedService.searchUsers(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('[AddAdminSheet] Search error: $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  bool _isUserHost(User user) {
    final uid = int.tryParse(user.id ?? '');
    return uid != null && uid == widget.hostId;
  }

  bool _isUserAlreadyAdmin(User user) {
    final uid = int.tryParse(user.id ?? '');
    if (uid == null) return false;
    return widget.currentAdmins.any((a) => a.id == uid);
  }

  Future<void> _addAdmin(User user) async {
    final uid = int.tryParse(user.id ?? '');
    if (uid == null) return;

    HapticFeedback.lightImpact();
    setState(() => _addingUserId = user.id);

    final res = await widget.controller.addAdmin(widget.roomId, targetUserId: uid);

    if (!mounted) return;
    setState(() => _addingUserId = null);

    if (res['ok'] == true) {
      HapticFeedback.mediumImpact();
      final newAdmin = VoiceRoomUser(
        id: uid,
        username: user.username ?? '',
        fullName: user.fullName ?? user.username ?? '',
        avatarUrl: user.avatarUrl ?? '',
      );
      widget.onAdminAdded(newAdmin);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@${user.username} is now an admin of this room.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // If reached maximum 4 admins, pop sheet
      if (widget.currentAdmins.length + 1 >= 4) {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Could not add admin.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: 520.h + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 10.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Room Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Search by username, user ID, or pick from friends',
                      style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Segmented Tabs
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFFFF7A45),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Friendlist / Following'),
                Tab(text: 'Search / User ID'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowingTab(),
                _buildSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
    if (_isLoadingFollowing) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A45)),
      );
    }

    if (_followingUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 40.r, color: Colors.white24),
            SizedBox(height: 8.h),
            Text(
              'No followed friends found',
              style: TextStyle(color: Colors.white54, fontSize: 13.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              'Use the Search tab to find users by username or User ID.',
              style: TextStyle(color: Colors.white30, fontSize: 11.sp),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _followingUsers.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
      itemBuilder: (ctx, i) => _buildUserRow(_followingUsers[i]),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.white, fontSize: 13.5.sp),
            decoration: InputDecoration(
              hintText: 'Search by username or user ID...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1F28),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7A45)),
                )
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? 'Type a username or numeric ID above'
                            : 'No matching users found',
                        style: TextStyle(color: Colors.white30, fontSize: 12.sp),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
                      itemBuilder: (ctx, i) => _buildUserRow(_searchResults[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildUserRow(User user) {
    final isHost = _isUserHost(user);
    final isAlreadyAdmin = _isUserAlreadyAdmin(user);
    final isAdding = _addingUserId == user.id;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          ClipOval(
            child: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: user.avatarUrl!,
                    width: 38.r,
                    height: 38.r,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarBox(user.username ?? '?'),
                  )
                : _avatarBox(user.username ?? '?'),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (user.fullName != null && user.fullName!.isNotEmpty)
                            ? user.fullName!
                            : (user.username ?? 'User'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (user.isVerified) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.verified, size: 14.r, color: const Color(0xFF1D9BF0)),
                    ],
                  ],
                ),
                Text(
                  '@${user.username ?? ''} ${user.id != null ? "• ID: ${user.id}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          if (isHost)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Host',
                style: TextStyle(
                  color: Color(0xFFFFB800),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (isAlreadyAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: isAdding ? null : () => _addAdmin(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A45),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                minimumSize: Size.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isAdding
                  ? SizedBox(
                      width: 12.r,
                      height: 12.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '+ Add',
                      style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _avatarBox(String text) {
    return Container(
      width: 38.r,
      height: 38.r,
      color: const Color(0xFF282932),
      child: Center(
        child: Text(
          text.isNotEmpty ? text[0].toUpperCase() : '?',
          style: TextStyle(color: Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
