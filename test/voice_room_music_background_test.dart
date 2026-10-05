import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:katsklub_flutter/services/voice_room_controller.dart';

void main() {
  group('buildVoiceRoomAudioSource', () {
    test('tags the source with a MediaItem so background playback keeps its foreground service', () {
      final source = buildVoiceRoomAudioSource(
        uri: Uri.parse('https://cdn.example.com/song.mp3'),
        headers: const {'User-Agent': 'test'},
        id: 'track-1',
        title: 'Test Song',
        artist: 'Test Artist',
        artworkUrl: 'https://example.com/art.jpg',
      );

      expect(source, isA<UriAudioSource>());
      final tag = (source as UriAudioSource).tag;
      expect(tag, isA<MediaItem>());
      final item = tag as MediaItem;
      expect(item.id, equals('track-1'));
      expect(item.title, equals('Test Song'));
      expect(item.artist, equals('Test Artist'));
      expect(item.artUri, equals(Uri.parse('https://example.com/art.jpg')));
    });

    test('falls back to default title/artist and null art for empty metadata', () {
      final source = buildVoiceRoomAudioSource(
        uri: Uri.parse('https://cdn.example.com/song.mp3'),
        id: '',
        title: '',
        artist: '',
        artworkUrl: '',
      );

      final item = (source as UriAudioSource).tag as MediaItem;
      expect(item.id, equals('voice-room-track'));
      expect(item.title, equals('Unknown Title'));
      expect(item.artist, equals('Unknown Artist'));
      expect(item.artUri, isNull);
    });

    test('supports file URIs for downloaded tracks', () {
      final source = buildVoiceRoomAudioSource(
        uri: Uri.parse('file:///data/song.mp3'),
        id: 'dl-1',
        title: 'Downloaded',
        artist: 'Someone',
        artworkUrl: 'https://example.com/thumb.jpg',
      );

      final uriSource = source as UriAudioSource;
      expect(uriSource.uri.scheme, equals('file'));
      final item = uriSource.tag as MediaItem;
      expect(item.title, equals('Downloaded'));
      expect(item.artUri, equals(Uri.parse('https://example.com/thumb.jpg')));
    });
  });
}
