import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A picture file shown without its empty margins: the transparent or
/// near-white border around its subject is measured once and cropped away,
/// then the rest is fitted in the box. For product pictures that come
/// with wide blank margins.
class TrimmedImage extends StatefulWidget {
  const TrimmedImage(this.file, {super.key, this.fit = BoxFit.contain});

  final File file;
  final BoxFit fit;

  /// Measured subject bounds per file path, so a picture is scanned once.
  static final Map<String, Rect> _bounds = {};

  /// The bounds of the pixels that are neither transparent nor near-white.
  static Rect subjectBounds(ui.Image image, ByteData pixels) {
    final width = image.width;
    final height = image.height;
    var left = width, top = height, right = -1, bottom = -1;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final r = pixels.getUint8(i);
        final g = pixels.getUint8(i + 1);
        final b = pixels.getUint8(i + 2);
        final a = pixels.getUint8(i + 3);
        if (a < 16 || (r > 240 && g > 240 && b > 240)) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < left) return Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    return Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
  }

  @override
  State<TrimmedImage> createState() => _TrimmedImageState();
}

class _TrimmedImageState extends State<TrimmedImage> {
  ui.Image? _image;
  Rect? _bounds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrimmedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _load();
  }

  Future<void> _load() async {
    final path = widget.file.path;
    final image = await decodeImageFromList(await widget.file.readAsBytes());
    var bounds = TrimmedImage._bounds[path];
    if (bounds == null) {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      bounds = pixels == null
          ? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
          : TrimmedImage.subjectBounds(image, pixels);
      TrimmedImage._bounds[path] = bounds;
    }
    if (!mounted || widget.file.path != path) {
      image.dispose();
      return;
    }
    _image?.dispose();
    setState(() {
      _image = image;
      _bounds = bounds;
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final bounds = _bounds;
    if (image == null || bounds == null) return const SizedBox.expand();
    return CustomPaint(
      key: const Key('trimmedImage'),
      painter: _TrimmedPainter(image, bounds, widget.fit),
      child: const SizedBox.expand(),
    );
  }
}

class _TrimmedPainter extends CustomPainter {
  const _TrimmedPainter(this.image, this.bounds, this.fit);

  final ui.Image image;
  final Rect bounds;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    final sizes = applyBoxFit(fit, bounds.size, size);
    final destination = Alignment.center.inscribe(sizes.destination, Offset.zero & size);
    canvas.drawImageRect(image, bounds, destination, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_TrimmedPainter old) => old.image != image || old.bounds != bounds || old.fit != fit;
}
