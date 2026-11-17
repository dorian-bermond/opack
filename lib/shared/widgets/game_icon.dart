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
          Game.mtg => _EmblemPainter(_Emblem.mtg, paint),
          Game.ygo => _EmblemPainter(_Emblem.ygo, paint),
          Game.opc => _EmblemPainter(_Emblem.opc, paint),
        },
      ),
    );
  }
}

/// An emblem's shape, built once from its SVG shapes: solids (`+`) added
/// and holes (`-`) cut, in the file's order, so overlaps and windings do
/// not matter.
class _Emblem {
  _Emblem(this.viewBox, List<(String, String)> shapes) : path = _build(shapes);

  /// The SVG view box: origin, then width and height.
  final (double, double, double, double) viewBox;
  final Path path;

  static Path _build(List<(String, String)> shapes) {
    var path = Path();
    for (final (kind, data) in shapes) {
      final shape = parseSvgPathData(data);
      path = Path.combine(kind == '-' ? PathOperation.difference : PathOperation.union, path, shape);
    }
    return path;
  }

  static final mtg = _Emblem(mtgIconViewBox, mtgIconShapes);
  static final ygo = _Emblem(ygoIconViewBox, ygoIconShapes);
  static final opc = _Emblem(opcIconViewBox, opcIconShapes);
}

/// Paints an emblem fitted and centered in the icon's square.
class _EmblemPainter extends CustomPainter {
  const _EmblemPainter(this.emblem, this.color);

  final _Emblem emblem;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final (x, y, w, h) = emblem.viewBox;
    final scale = size.width / (w > h ? w : h);
    canvas.save();
    canvas.translate((size.width - w * scale) / 2, (size.height - h * scale) / 2);
    canvas.scale(scale, scale);
    canvas.translate(-x, -y);
    canvas.drawPath(emblem.path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.color != color || old.emblem != emblem;
}
