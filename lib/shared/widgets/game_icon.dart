import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/catalog/domain/models.dart';

/// A small drawn emblem per game: a straw hat skull flag for One Piece, a
/// planeswalker spark for MtG, the Millennium Puzzle for Yu-Gi-Oh!. Drawn
/// here rather than taken from the games' trademarked logos.
class GameIcon extends StatelessWidget {
  const GameIcon(this.game, {super.key, this.size = 24, this.color});

  final Game game;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paint = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: switch (game) {
          Game.mtg => _PlaneswalkerPainter(paint),
          Game.ygo => _MillenniumPuzzlePainter(paint),
          Game.opc => _StrawHatFlagPainter(paint),
        },
      ),
    );
  }
}

/// A five-pointed spark: the planeswalker symbol's silhouette.
class _PlaneswalkerPainter extends CustomPainter {
  const _PlaneswalkerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final path = Path();
    // Five long points with deep concave sides, like a flame.
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final tip = c + Offset(math.cos(a), math.sin(a)) * r;
      final inA = a + math.pi / 5;
      final inner = c + Offset(math.cos(inA), math.sin(inA)) * r * 0.36;
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      // Curved sides bow inwards toward the center.
      final nextA = -math.pi / 2 + (i + 1) * 2 * math.pi / 5;
      final nextTip = c + Offset(math.cos(nextA), math.sin(nextA)) * r;
      path.quadraticBezierTo(inner.dx, inner.dy, nextTip.dx, nextTip.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(c, r * 0.12, Paint()..color = color.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_PlaneswalkerPainter old) => old.color != color;
}

/// An upside-down pyramid bearing the Eye of Wdjat.
class _MillenniumPuzzlePainter extends CustomPainter {
  const _MillenniumPuzzlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeJoin = StrokeJoin.round;
    // The ring at the top, then the pyramid hanging from it.
    canvas.drawCircle(Offset(w / 2, h * 0.1), w * 0.08, line);
    final pyramid = Path()
      ..moveTo(w * 0.08, h * 0.26)
      ..lineTo(w * 0.92, h * 0.26)
      ..lineTo(w / 2, h * 0.98)
      ..close();
    canvas.drawPath(pyramid, line);
    // The eye: an almond with its pupil, sitting in the upper half.
    final eye = Path()
      ..moveTo(w * 0.28, h * 0.46)
      ..quadraticBezierTo(w / 2, h * 0.28, w * 0.72, h * 0.46)
      ..quadraticBezierTo(w / 2, h * 0.64, w * 0.28, h * 0.46)
      ..close();
    canvas.drawPath(eye, line..strokeWidth = w * 0.05);
    canvas.drawCircle(Offset(w / 2, h * 0.46), w * 0.07, fill);
    // The tear line under the eye.
    canvas.drawLine(Offset(w * 0.5, h * 0.6), Offset(w * 0.44, h * 0.76), line);
  }

  @override
  bool shouldRepaint(_MillenniumPuzzlePainter old) => old.color != color;
}

/// A skull under a straw hat, over crossed bones: the Straw Hat jolly roger.
class _StrawHatFlagPainter extends CustomPainter {
  const _StrawHatFlagPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final hole = Paint()..color = color.withValues(alpha: 0.0)..blendMode = BlendMode.clear;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.saveLayer(Offset.zero & size, Paint());
    // Crossed bones behind.
    canvas.drawLine(Offset(w * 0.12, h * 0.92), Offset(w * 0.88, h * 0.4), line);
    canvas.drawLine(Offset(w * 0.88, h * 0.92), Offset(w * 0.12, h * 0.4), line);
    // The skull: a rounded head with a jaw.
    final skull = Path()
      ..addOval(Rect.fromCenter(center: Offset(w / 2, h * 0.52), width: w * 0.5, height: h * 0.48))
      ..addRect(Rect.fromLTWH(w * 0.36, h * 0.66, w * 0.28, h * 0.14));
    canvas.drawPath(skull, fill);
    // Eyes and nose, cut out.
    canvas.drawCircle(Offset(w * 0.42, h * 0.5), w * 0.06, hole);
    canvas.drawCircle(Offset(w * 0.58, h * 0.5), w * 0.06, hole);
    canvas.drawCircle(Offset(w * 0.5, h * 0.62), w * 0.03, hole);
    // The straw hat: a wide brim and a low crown with its band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.26, w * 0.8, h * 0.1), Radius.circular(w * 0.05)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.3, h * 0.1, w * 0.4, h * 0.2), Radius.circular(w * 0.08)),
      fill,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.22, w * 0.4, h * 0.05), hole);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrawHatFlagPainter old) => old.color != color;
}
