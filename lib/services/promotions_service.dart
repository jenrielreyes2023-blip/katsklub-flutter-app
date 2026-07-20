import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

class Promotion {
  final String id;
  final String title;
  final String text;
  final String? imageUrl;
  final String? actionUrl;
  final String buttonText;
  final bool isEnabled;

  Promotion({
    required this.id,
    required this.title,
    required this.text,
    this.imageUrl,
    this.actionUrl,
    required this.buttonText,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'buttonText': buttonText,
      'isEnabled': isEnabled,
    };
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      actionUrl: json['actionUrl']?.toString(),
      buttonText: json['buttonText']?.toString() ?? 'Learn More',
      isEnabled: json['isEnabled'] == null ? true : json['isEnabled'] == true,
    );
  }

  Post toPost() {
    return Post(
      id: 'promo_$id',
      authorFullName: title,
      authorUsername: 'sponsor',
      authorAvatarUrl: '',
      authorIsVerified: true,
      authorIsAdmin: true,
      authorIsAuthor: false,
      isFollowingAuthor: false,
      ownedByMe: false,
      visibility: 'public',
      repostOriginalPostId: '',
      text: text,
      isReel: false,
      isAlbum: false,
      isDiscussion: false,
      albumTitle: '',
      discussionTitle: '',
      discussionCoverUrl: '',
      videoUrl: '',
      videoPosterUrl: '',
      videoTitle: '',
      youtubeVideoId: '',
      createdAt: DateTime.now(),
      imageUrls: imageUrl != null && imageUrl!.isNotEmpty ? [imageUrl!] : [],
      imageAspectRatios: imageUrl != null && imageUrl!.isNotEmpty ? [1.0] : [],
      thumbnailUrls: imageUrl != null && imageUrl!.isNotEmpty ? [imageUrl!] : [],
      likeCount: 0,
      likedByMe: false,
      bookmarkedByMe: false,
      commentCount: 0,
      repostCount: 0,
      isPromotion: true,
      promotionUrl: actionUrl ?? '',
      promotionButtonText: buttonText,
    );
  }
}

class PromotionsService {
  static const String _prefsKey = 'katsklub_promotions_list';

  static final List<Promotion> _defaultPromotions = [
    Promotion(
      id: 'default_premium',
      title: 'KatsKlub Premium',
      text: 'Show off your style! Unlock exclusive chat border outlines, golden name shimmers, custom stickers, and rare trophies. Visit the Shop to unlock your status today!',
      buttonText: 'Visit Shop',
      actionUrl: 'katsklub://shop',
      imageUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?q=80&w=600&auto=format&fit=crop',
    ),
    Promotion(
      id: 'default_telegram',
      title: 'KatsKlub Community',
      text: 'Connect with thousands of other cat and pet lovers on our Telegram group. Share daily cat moments, tips, and get fast support from the devs!',
      buttonText: 'Join Telegram',
      actionUrl: 'https://t.me/katsklub',
      imageUrl: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?q=80&w=600&auto=format&fit=crop',
    ),
  ];

  Future<List<Promotion>> getPromotions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return _defaultPromotions;
      }
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => Promotion.fromJson(item)).toList();
    } catch (_) {
      return _defaultPromotions;
    }
  }

  Future<void> savePromotions(List<Promotion> promotions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(promotions.map((p) => p.toJson()).toList());
      await prefs.setString(_prefsKey, jsonStr);
    } catch (_) {}
  }

  Future<List<Post>> getActivePromotionPosts() async {
    final promos = await getPromotions();
    return promos
        .where((p) => p.isEnabled)
        .map((p) => p.toPost())
        .toList();
  }
}
