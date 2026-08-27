import 'package:flutter_test/flutter_test.dart';
import 'package:katsklub_flutter/services/youtube_service.dart';

void main() {
  group('YouTubeVideoItem', () {
    test('fromJson and toJson deserialize and serialize properly', () {
      final json = {
        'id': 'dQw4w9WgXcQ',
        'title': 'Never Gonna Give You Up',
        'duration': '3:33',
        'thumbnail': 'https://example.com/thumb.jpg',
        'author': 'Rick Astley',
        'viewCount': '1.8B views',
      };

      final item = YouTubeVideoItem.fromJson(json);

      expect(item.id, equals('dQw4w9WgXcQ'));
      expect(item.title, equals('Never Gonna Give You Up'));
      expect(item.duration, equals('3:33'));
      expect(item.thumbnail, equals('https://example.com/thumb.jpg'));
      expect(item.author, equals('Rick Astley'));
      expect(item.viewCount, equals('1.8B views'));

      final outJson = item.toJson();
      expect(outJson['id'], equals('dQw4w9WgXcQ'));
      expect(outJson['title'], equals('Never Gonna Give You Up'));
    });
  });

  group('YouTubeService Live Backend Test', () {
    test('searches and extracts stream URL successfully from local backend', () async {
      final service = YouTubeService(baseUrl: 'http://localhost:5000');

      final results = await service.searchVideos('flutter');
      expect(results, isNotEmpty);
      expect(results.first.id, isNotEmpty);
      expect(results.first.title, isNotEmpty);

      final streamUrl = await service.getStreamUrl('dQw4w9WgXcQ');
      expect(streamUrl, isNotNull);
      expect(streamUrl, startsWith('https://'));
    });
  });
}
