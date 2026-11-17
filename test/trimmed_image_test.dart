import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/shared/widgets/trimmed_image.dart';

/// A [width]×[height] image whose pixels are [paint]'s colors (RGBA).
Future<(ui.Image, ByteData)> _image(int width, int height, List<int> Function(int x, int y) paint) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bytes.setRange((y * width + x) * 4, (y * width + x) * 4 + 4, paint(x, y));
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future.then((image) => (image, bytes.buffer.asByteData()));
}

void main() {
  test('the subject bounds leave out transparent and near-white margins', () async {
    // A 6×5 picture: white, with a transparent corner and a red pack from (2,1) to (3,3).
    final (image, pixels) = await _image(6, 5, (x, y) {
      if (x == 0 && y == 0) return [0, 0, 0, 0];
      if (x >= 2 && x <= 3 && y >= 1 && y <= 3) return [200, 30, 30, 255];
      return [250, 250, 250, 255];
    });
    expect(TrimmedImage.subjectBounds(image, pixels), const Rect.fromLTRB(2, 1, 4, 4));

    // Nothing to keep: the whole picture.
    final (blank, blankPixels) = await _image(3, 2, (x, y) => [255, 255, 255, 255]);
    expect(TrimmedImage.subjectBounds(blank, blankPixels), const Rect.fromLTWH(0, 0, 3, 2));
  });
}
