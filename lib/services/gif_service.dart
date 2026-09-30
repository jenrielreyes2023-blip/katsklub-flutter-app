import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/gif_item.dart';

class GifService {
  static const String _fallbackGiphyKey = 'ldQeNHnpL3WcCxJE1uO8HTk17ICn8i34';
  static const String _giphyBaseUrl = 'https://api.giphy.com/v1/gifs';

  /// Fetch trending GIFs with fallback
  static Future<List<GifItem>> getTrending({int offset = 0, int limit = 25}) async {
    // 1. Try KatsKlub backend proxy first
    try {
      final backendUri = Uri.parse('${ApiConfig.apiBaseUrl}/api/gifs/trending?limit=$limit&offset=$offset');
      final response = await http.get(backendUri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = json['results'] as List<dynamic>? ?? [];
        return results
            .map((item) => GifItem.fromJson(item as Map<String, dynamic>))
            .where((g) => g.url.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[GifService] Backend trending error, falling back to direct Giphy: $e');
    }

    // 2. Direct Giphy fallback
    try {
      final giphyUri = Uri.parse(
        '$_giphyBaseUrl/trending?api_key=$_fallbackGiphyKey&limit=$limit&offset=$offset&rating=pg-13',
      );
      final response = await http.get(giphyUri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        return data
            .map((item) => GifItem.fromJson(item as Map<String, dynamic>))
            .where((g) => g.url.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[GifService] Direct Giphy trending error: $e');
    }

    return const [];
  }

  /// Search GIFs by query with fallback
  static Future<List<GifItem>> search(String query, {int offset = 0, int limit = 25}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return getTrending(offset: offset, limit: limit);
    }

    // 1. Try KatsKlub backend proxy first
    try {
      final backendUri = Uri.parse(
        '${ApiConfig.apiBaseUrl}/api/gifs/search?q=${Uri.encodeComponent(cleanQuery)}&limit=$limit&offset=$offset',
      );
      final response = await http.get(backendUri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = json['results'] as List<dynamic>? ?? [];
        return results
            .map((item) => GifItem.fromJson(item as Map<String, dynamic>))
            .where((g) => g.url.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[GifService] Backend search error, falling back to direct Giphy: $e');
    }

    // 2. Direct Giphy fallback
    try {
      final giphyUri = Uri.parse(
        '$_giphyBaseUrl/search?api_key=$_fallbackGiphyKey&q=${Uri.encodeComponent(cleanQuery)}&limit=$limit&offset=$offset&rating=pg-13',
      );
      final response = await http.get(giphyUri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        return data
            .map((item) => GifItem.fromJson(item as Map<String, dynamic>))
            .where((g) => g.url.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[GifService] Direct Giphy search error: $e');
    }

    return const [];
  }
}
