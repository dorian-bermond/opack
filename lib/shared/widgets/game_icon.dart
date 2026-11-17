import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../features/catalog/domain/models.dart';
import 'mtg_icon_path.dart';
import 'opc_icon_path.dart';
import 'ygo_icon_path.dart';

/// A small emblem per game, each from an SVG under assets/icons: the
/// planeswalker symbol for MtG, the Millennium Puzzle for Yu-Gi-Oh!, the
/// Straw Hat jolly roger for One Piece.
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

/// The planeswalker symbol, from SVG path data (assets/icons/mtg.svg, see
/// `mtg_icon_path.dart`), fitted and centered in the icon's square.
class _PlaneswalkerPainter extends CustomPainter {
  _PlaneswalkerPainter(this.color);

  final Color color;

  static final Path _path = parseSvgPathData(mtgIconPath);

  @override
  void paint(Canvas canvas, Size size) {
    final (x, y, w, h) = mtgIconViewBox;
    final scale = size.width / (w > h ? w : h);
    canvas.save();
    canvas.translate((size.width - w * scale) / 2, (size.height - h * scale) / 2);
    canvas.scale(scale, scale);
    canvas.translate(-x, -y);
    canvas.drawPath(_path, Paint()..color = color);
    canvas.restore();
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
