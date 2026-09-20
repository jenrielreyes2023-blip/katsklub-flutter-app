import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/src/proto/svga.pb.dart';
import 'package:archive/archive.dart';

void main() {
  test('Verify risingpaw.svga text, daisies, and bird flight', () async {
    final file = File('assets/badge/risingpaw.svga');
    final bytes = await file.readAsBytes();
    final inflated = ZLibDecoder().decodeBytes(bytes);
    final movie = MovieEntity()..mergeFromBuffer(inflated);

    // 1. Check text sprite
    final textSprite = movie.sprites[17];
    expect(textSprite.imageKey, 'text');
    final textMaxAlpha = textSprite.frames.map((f) => f.alpha).reduce((a, b) => a > b ? a : b);
    print('Text max alpha: $textMaxAlpha (expected 0.0)');
    expect(textMaxAlpha, 0.0);

    // 2. Check Daisy 19 and 22 rotation
    for (var sIdx in [19, 22]) {
      final s = movie.sprites[sIdx];
      // Compute center for each frame: center = (tx + a*cx + c*cy, ty + b*cx + d*cy)
      // Since layout is 83x83, center is at 41.5, 41.5
      final f0 = s.frames[0];
      final f30 = s.frames[30];
      final f60 = s.frames[60];
      final f90 = s.frames[90];
      print('Daisy $sIdx: Frame 0 t=(${f0.transform.tx.toStringAsFixed(2)}, ${f0.transform.ty.toStringAsFixed(2)}), '
            'Frame 30 t=(${f30.transform.tx.toStringAsFixed(2)}, ${f30.transform.ty.toStringAsFixed(2)}), '
            'Frame 60 t=(${f60.transform.tx.toStringAsFixed(2)}, ${f60.transform.ty.toStringAsFixed(2)})');
    }

    // 3. Check Bird 1 and Bird 2
    for (var bIdx = 1; bIdx <= 2; bIdx++) {
      final wingSprites = bIdx == 1
          ? [movie.sprites[27], movie.sprites[28], movie.sprites[29], movie.sprites[30]]
          : [movie.sprites[23], movie.sprites[24], movie.sprites[25], movie.sprites[26]];
      
      print('\n=== BIRD $bIdx SAMPLES ===');
      for (var f = 0; f < 120; f += 20) {
        String active = 'none';
        double tx = 0, ty = 0, alpha = 0;
        for (var s in wingSprites) {
          if (s.frames[f].alpha > 0.01) {
            active = s.imageKey;
            alpha = s.frames[f].alpha;
            tx = s.frames[f].transform.tx;
            ty = s.frames[f].transform.ty;
            break;
          }
        }
        print('Frame $f: $active (alpha=${alpha.toStringAsFixed(2)}, x=${tx.toStringAsFixed(1)}, y=${ty.toStringAsFixed(1)})');
      }
    }
  });
}
