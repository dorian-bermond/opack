import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../features/catalog/domain/models.dart';
import 'opc_icon_path.dart';
import 'ygo_icon_path.dart';

/// A small emblem per game: a planeswalker spark for MtG, drawn here; the
/// Millennium Puzzle for Yu-Gi-Oh! and the Straw Hat jolly roger for One
/// Piece, from traced SVGs (assets/icons).
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

/// The Millennium Puzzle, traced from a drawing into SVG path data (see
/// `ygo_icon_path.dart`), scaled to the icon's size.
class _MillenniumPuzzlePainter extends CustomPainter {
  _MillenniumPuzzlePainter(this.color);

  final Color color;

  // The trace cuts its holes (eye, ring, tear) with the even-odd rule.
  static final Path _path = parseSvgPathData(ygoIconPath)..fillType = PathFillType.evenOdd;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / ygoIconViewBox;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(_path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MillenniumPuzzlePainter old) => old.color != color;
}

/// The Straw Hat jolly roger, from a traced SVG (assets/icons/opc.svg,
/// see `opc_icon_path.dart`): its paths, drawn under the file's group
/// transform, fitted and centered in the icon's square.
class _StrawHatFlagPainter extends CustomPainter {
  _StrawHatFlagPainter(this.color);

  final Color color;

  static final List<Path> _paths = [for (final d in opcIconPaths) parseSvgPathData(d)];

  @override
  void paint(Canvas canvas, Size size) {
    final (w, h) = opcIconViewBox;
    final scale = size.width / (w > h ? w : h);
    canvas.save();
    // Centered in the square, since the drawing is not one.
    canvas.translate((size.width - w * scale) / 2, (size.height - h * scale) / 2);
    canvas.scale(scale, scale);
    canvas.translate(opcIconTranslate.$1.toDouble(), opcIconTranslate.$2.toDouble());
    canvas.scale(opcIconScale.$1, opcIconScale.$2);
    final paint = Paint()..color = color;
    for (final path in _paths) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrawHatFlagPainter old) => old.color != color;
}
