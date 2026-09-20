import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/src/proto/svga.pb.dart';
import 'package:archive/archive.dart';

void main() {
  test('Restore FRESH PAW text and keep flocking birds in upper sky', () async {
    final file = File('assets/badge/risingpaw.svga');
    final bytes = await file.readAsBytes();
    final inflated = ZLibDecoder().decodeBytes(bytes);
    final movie = MovieEntity()..mergeFromBuffer(inflated);

    // 1. Restore Sprite 17 (text: "FRESH PAW") to alpha = 1.0
    final textSprite = movie.sprites[17];
    expect(textSprite.imageKey, 'text');
    for (var f in textSprite.frames) {
      f.alpha = 1.0;
    }

    // 2. Setup flocking birds in upper sky (y = 18..38, above FRESH PAW which is y = 45..82)
    void setupBirdFlock({
      required List<SpriteEntity> wingSprites,
      required double startX,
      required double endX,
      required double startY,
      required double endY,
      required double waveAmp,
      required double waveFreq,
      required int flapPhaseOffset,
      required double scale,
    }) {
      final poseSequence = [
        0, 0, 0, 0, // up
        1, 1, 1, 1, // midup
        2, 2, 2, 2, // mid
        3, 3, 3, 3, // down
        2, 2, 2, 2, // mid
        1, 1, 1, 1, // midup
      ];

      for (var f = 0; f < 120; f++) {
        final progress = f / 119.0;
        final curX = startX + progress * (endX - startX);
        final curY = startY + progress * (endY - startY) + math.sin(progress * 2 * math.pi * waveFreq) * waveAmp;

        // Fade in at start (first 10 frames), fade out at end (last 10 frames)
        double alpha = 1.0;
        if (f < 10) {
          alpha = f / 10.0;
        } else if (f > 109) {
          alpha = (119 - f) / 10.0;
        }

        final flapFrame = (f + flapPhaseOffset) % 24;
        final activeWingIdx = poseSequence[flapFrame];

        for (var w = 0; w < 4; w++) {
          final sprite = wingSprites[w];
          final frameData = sprite.frames[f];
          if (w == activeWingIdx) {
            frameData.alpha = alpha;
            frameData.transform.a = scale;
            frameData.transform.b = 0.0;
            frameData.transform.c = 0.0;
            frameData.transform.d = scale;
            frameData.transform.tx = curX;
            frameData.transform.ty = curY;
          } else {
            frameData.alpha = 0.0;
          }
        }
      }
    }

    // Bird 1: Lead bird (55x43), flying at y ≈ 18..28 in open upper sky
    final bird1Wings = [
      movie.sprites[27], // up
      movie.sprites[28], // midup
      movie.sprites[29], // mid
      movie.sprites[30], // down
    ];
    setupBirdFlock(
      wingSprites: bird1Wings,
      startX: 80.0,
      endX: 415.0,
      startY: 23.0,
      endY: 20.0,
      waveAmp: 4.5,
      waveFreq: 2.0,
      flapPhaseOffset: 0,
      scale: 0.88,
    );

    // Bird 2: Companion bird (43x34), flying trailing below at y ≈ 29..39
    final bird2Wings = [
      movie.sprites[23], // up
      movie.sprites[24], // midup
      movie.sprites[25], // mid
      movie.sprites[26], // down
    ];
    setupBirdFlock(
      wingSprites: bird2Wings,
      startX: 45.0,
      endX: 380.0,
      startY: 33.0,
      endY: 30.0,
      waveAmp: 4.0,
      waveFreq: 2.0,
      flapPhaseOffset: 6,
      scale: 0.80,
    );

    // Write modified movie to risingpaw.svga
    final modifiedBytes = movie.writeToBuffer();
    final deflated = ZLibEncoder().encode(modifiedBytes);
    await File('assets/badge/risingpaw.svga').writeAsBytes(deflated);
    print('Successfully updated assets/badge/risingpaw.svga (${deflated.length} bytes)');

    // Verify Sprite 17 text alpha
    expect(movie.sprites[17].frames[0].alpha, 1.0);
    print('FRESH PAW text restored! alpha=${movie.sprites[17].frames[0].alpha}');
  });
}
