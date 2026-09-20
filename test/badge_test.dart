import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga/src/proto/svga.pb.dart';
import 'package:archive/archive.dart';

void main() {
  test('Test risingpaw.svga', () async {
    final file = File('assets/badge/risingpaw.svga');
    expect(file.existsSync(), isTrue);
    final bytes = await file.readAsBytes();
    final inflated = ZLibDecoder().decodeBytes(bytes);
    final movie = MovieEntity()..mergeFromBuffer(inflated);
    print('SUCCESS! Version: ${movie.version}, viewBox: ${movie.params.viewBoxWidth}x${movie.params.viewBoxHeight}, fps: ${movie.params.fps}, frames: ${movie.params.frames}');
    print('Sprites: ${movie.sprites.length}, Images: ${movie.images.length}');
    expect(movie.version, equals('2.0.0'));
    expect(movie.params.frames, equals(120));
  });
}
