import 'package:flutter_test/flutter_test.dart';
import 'package:katsklub_flutter/services/youtube_music_service.dart';

void main() {
  group('YouTubeMusicSong', () {
    test('fromJson and toJson deserialize and serialize properly', () {
      final json = {
        'id': 'xTvyyoF_LZY',
        'title': 'Shape of You',
        'artist': 'Ed Sheeran',
        'album': '÷ (Divide)',
        'duration': '3:53',
        'thumbnail': 'https://example.com/thumb.jpg',
      };

      final song = YouTubeMusicSong.fromJson(json);

      expect(song.id, equals('xTvyyoF_LZY'));
      expect(song.title, equals('Shape of You'));
      expect(song.artist, equals('Ed Sheeran'));
      expect(song.album, equals('÷ (Divide)'));
      expect(song.duration, equals('3:53'));
      expect(song.thumbnail, equals('https://example.com/thumb.jpg'));

      final outJson = song.toJson();
      expect(outJson['id'], equals('xTvyyoF_LZY'));
      expect(outJson['title'], equals('Shape of You'));
    });
  });

  group('YouTubeMusicService Live Backend Tests', () {
    test('searches songs, retrieves charts, and gets lyrics from local backend', () async {
      final service = YouTubeMusicService(baseUrl: 'http://localhost:5000');

      // 1. Search songs
      final songs = await service.searchSongs('Ed Sheeran');
      expect(songs, isNotEmpty);
      expect(songs.first.id, isNotEmpty);
      expect(songs.first.title, isNotEmpty);

      // 2. Charts
      final chartsResult = await service.getCharts();
      expect(chartsResult.charts, isNotEmpty);

      // 3. Lyrics
      final lyrics = await service.getLyrics(songs.first.id);
      // Lyrics may or may not be null depending on the song, but method returns cleanly
      expect(lyrics == null || lyrics.isNotEmpty, isTrue);
    });
  });
}
