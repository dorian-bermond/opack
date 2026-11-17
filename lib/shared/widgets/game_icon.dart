import 'dart:typed_data';

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
/// and holes (`-`) cut, in the file's order (an `e` marks an even-odd
/// path), so overlaps and windings do not matter; then put under the
/// file's group transform.
class _Emblem {
  _Emblem(this.viewBox, (double, double, double, double) transform, List<(String, String)> shapes,
      {this.outline = 0})
      : path = _build(shapes, holes: true).transform(_matrix(transform)),
        silhouette = _build(shapes, holes: false).transform(_matrix(transform));

  /// The SVG view box: origin, then width and height.
  final (double, double, double, double) viewBox;
  final Path path;

  /// The solids alone, whose outer edge gets the [outline].
  final Path silhouette;

  /// A border around the silhouette, in view box units (0: none), to
  /// thicken a finely traced emblem.
  final double outline;

  static Float64List _matrix((double, double, double, double) transform) => (Matrix4.identity()
        ..translateByDouble(transform.$1, transform.$2, 0, 1)
        ..scaleByDouble(transform.$3, transform.$4, 1, 1))
      .storage;

  /// The shapes combined in order; without [holes], the solids alone.
  static Path _build(List<(String, String)> shapes, {required bool holes}) {
    var path = Path();
    for (final (kind, data) in shapes) {
      if (!holes && kind.startsWith('-')) continue;
      final shape = parseSvgPathData(data);
      if (kind.endsWith('e')) shape.fillType = PathFillType.evenOdd;
      path = Path.combine(kind.startsWith('-') ? PathOperation.difference : PathOperation.union, path, shape);
    }
    return path;
  }

  static final mtg = _Emblem(mtgIconViewBox, mtgIconTransform, mtgIconShapes);
  static final ygo = _Emblem(ygoIconViewBox, ygoIconTransform, ygoIconShapes, outline: 26);
  static final opc = _Emblem(opcIconViewBox, opcIconTransform, opcIconShapes, outline: 40);
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
    if (emblem.outline > 0) {
      // Under the emblem, so its inner details stay crisp; half the
      // stroke lies outside the edge.
      canvas.drawPath(
        emblem.silhouette,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = emblem.outline
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(emblem.path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.color != color || old.emblem != emblem;
}
