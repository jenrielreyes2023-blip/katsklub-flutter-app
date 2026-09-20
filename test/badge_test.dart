import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/src/proto/svga.pb.dart';
import 'package:archive/archive.dart';

void main() {
  test('Fix daisy rotation in place', () async {
    final file = File('assets/badge/risingpaw.svga');
    final bytes = await file.readAsBytes();
    final inflated = ZLibDecoder().decodeBytes(bytes);
    final movie = MovieEntity()..mergeFromBuffer(inflated);
    
    // Daisy sprites to fix: index 19 and index 22
    for (final spriteIdx in [19, 22]) {
      final s = movie.sprites[spriteIdx];
      // Get frame 0 initial center
      final f0 = s.frames[0];
      const cx = 83.0 / 2.0; // 41.5
      const cy = 83.0 / 2.0; // 41.5
      final fixedCenterX = f0.transform.a * cx + f0.transform.c * cy + f0.transform.tx;
      final fixedCenterY = f0.transform.b * cx + f0.transform.d * cy + f0.transform.ty;
      print('Sprite $spriteIdx Fixed Center: ($fixedCenterX, $fixedCenterY)');

      for (var fIdx = 0; fIdx < s.frames.length; fIdx++) {
        final f = s.frames[fIdx];
        if (f.hasTransform()) {
          final a = f.transform.a;
          final b = f.transform.b;
          final c = f.transform.c;
          final d = f.transform.d;
          // New tx, ty that locks the center at (fixedCenterX, fixedCenterY)
          final newTx = fixedCenterX - (a * cx + c * cy);
          final newTy = fixedCenterY - (b * cx + d * cy);
          f.transform.tx = newTx;
          f.transform.ty = newTy;
        }
      }
    }

    // Serialize and compress
    final newBytes = movie.writeToBuffer();
    final compressed = ZLibEncoder().encode(newBytes);
    await File('assets/badge/risingpaw.svga').writeAsBytes(compressed);
    print('Updated assets/badge/risingpaw.svga with fixed daisy rotation! New size: ${compressed.length}');
  });
}
