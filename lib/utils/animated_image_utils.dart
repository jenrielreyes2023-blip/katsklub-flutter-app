import 'dart:math' as math;
import 'dart:typed_data';

import '../models/user.dart';

/// Maximum size allowed for animated cover photos (3.5 MB) to avoid memory strain.
const int maxAnimatedCoverSizeBytes = 3670016; // 3.5 MB

/// Maximum size allowed for animated avatars (2.5 MB) to avoid memory strain.
const int maxAnimatedAvatarSizeBytes = 2621440; // 2.5 MB

/// Check if the raw bytes represent a GIF image.
bool isGifBytes(Uint8List bytes) {
  return bytes.length > 3 &&
      bytes[0] == 0x47 && // G
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46;   // F
}

/// Check if the raw bytes represent an animated WebP image.
/// An animated WebP conforms to the Extended WebP (VP8X) specification
/// and includes an animation bit or ANIM/ANMF chunks.
bool isAnimatedWebpBytes(Uint8List bytes) {
  if (bytes.length < 21) return false;

  // Check 'RIFF' header at 0..3 and 'WEBP' at 8..11
  final isRiff = bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46;
  final isWebp = bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;

  if (!isRiff || !isWebp) return false;

  // Check for VP8X chunk (Extended File Format)
  final isVp8x = bytes[12] == 0x56 && // V
      bytes[13] == 0x50 &&             // P
      bytes[14] == 0x38 &&             // 8
      bytes[15] == 0x58;               // X

  if (isVp8x && bytes.length > 20) {
    // In VP8X, offset 20 contains feature flags. Bit 1 (0x02) indicates Animation.
    final flags = bytes[20];
    if ((flags & 0x02) != 0) {
      return true;
    }
  }

  // Fallback search in header for 'ANIM' or 'ANMF' chunk identifiers
  final searchLimit = math.min(bytes.length - 4, 4096);
  for (int i = 12; i < searchLimit; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x4E) { // 'AN'
      if ((bytes[i + 2] == 0x49 && bytes[i + 3] == 0x4D) || // 'ANIM'
          (bytes[i + 2] == 0x4D && bytes[i + 3] == 0x46)) { // 'ANMF'
        return true;
      }
    }
  }

  return false;
}

/// Returns true if the image is an animated GIF or animated WebP.
bool isAnimatedImageBytes(Uint8List bytes) {
  return isGifBytes(bytes) || isAnimatedWebpBytes(bytes);
}

/// Determines the MIME type for an animated image payload.
String getAnimatedMimeType(Uint8List bytes) {
  if (isGifBytes(bytes)) return 'image/gif';
  if (isAnimatedWebpBytes(bytes)) return 'image/webp';
  return 'image/jpeg';
}

/// Helper to determine if a user has admin privileges.
bool isAdminUser(User? user) {
  if (user == null) return false;
  final uname = user.username?.trim().toLowerCase() ?? '';
  return user.isAdmin == true || uname == 'jayriel' || uname == 'gemini';
}

/// Cover photos: Only Authors and Admins are permitted to use animated formats.
bool canUseAnimatedCover(User? user) {
  if (user == null) return false;
  final role = user.roleTitle?.trim().toLowerCase() ?? '';
  return isAdminUser(user) || user.isAuthor == true || role == 'author';
}

/// Profile avatars: Only Admins are permitted to use animated formats.
bool canUseAnimatedAvatar(User? user) {
  return isAdminUser(user);
}
