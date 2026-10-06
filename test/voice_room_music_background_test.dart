import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:katsklub_flutter/services/voice_room_controller.dart';
import 'package:katsklub_flutter/services/global_audio_player_service.dart';

void main() {
  group('buildVoiceRoomAudioSource', () {
    test('builds UriAudioSource without MediaItem so media notification is not created', () {
      final source = buildVoiceRoomAudioSource(
        uri: Uri.parse('https://cdn.example.com/song.mp3'),
        headers: const {'User-Agent': 'test'},
        id: 'track-1',
        title: 'Test Song',
        artist: 'Test Artist',
        artworkUrl: 'https://example.com/art.jpg',
      );

      expect(source, isA<UriAudioSource>());
      final uriSource = source as UriAudioSource;
      expect(uriSource.uri, equals(Uri.parse('https://cdn.example.com/song.mp3')));
      expect(uriSource.headers, equals(const {'User-Agent': 'test'}));
      expect(uriSource.tag, isNull);
    });

    test('supports file URIs for downloaded tracks without MediaItem tag', () {
      final source = buildVoiceRoomAudioSource(
        uri: Uri.parse('file:///data/song.mp3'),
        id: 'dl-1',
        title: 'Downloaded',
        artist: 'Someone',
        artworkUrl: 'https://example.com/thumb.jpg',
      );

      expect(source, isA<UriAudioSource>());
      final uriSource = source as UriAudioSource;
      expect(uriSource.uri.scheme, equals('file'));
      expect(uriSource.tag, isNull);
    });
  });

  group('runMusicStage', () {
    test('returns the action result on success', () async {
      final result = await runMusicStage('test', () async => 42);
      expect(result, equals(42));
    });

    test('throws TimeoutException instead of hanging forever', () async {
      await expectLater(
        runMusicStage(
          'hang',
          () => Completer<void>().future,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('rethrows action errors', () async {
      await expectLater(
        runMusicStage('boom', () => Future<void>.error(StateError('x'))),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('GlobalAudioPlayerService Voice Room Mode', () {
    test('isVoiceRoomMode initial state is false and instance is singleton', () {
      final service = GlobalAudioPlayerService.instance;
      expect(service, isNotNull);
      expect(service.isVoiceRoomMode, isFalse);
    });

    test('stopVoiceRoomMusic resets isVoiceRoomMode to false', () async {
      final service = GlobalAudioPlayerService.instance;
      await service.stopVoiceRoomMusic();
      expect(service.isVoiceRoomMode, isFalse);
      expect(service.queue, isEmpty);
    });
  });
}
