import 'package:flutter/material.dart';

/// A sealed pack that opens on a tap, or by slashing across it: a drag
/// draws the cut along the pointer's path and, once it spans enough of
/// the pack sideways or up and down, tears the pack in two along that
/// line before [onOpen] fires.
class SealedPack extends StatefulWidget {
  const SealedPack({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    required this.onOpen,
    this.enabled = true,
  });

  final Widget child;
  final double width;
  final double height;
  final VoidCallback onOpen;
  final bool enabled;

  /// Where a tap's cut runs, as a share of the pack's height from the top.
  static const cutAt = 0.14;

  /// How far across the pack (or down it) the slash must go to tear it.
  static const tearAt = 0.55;

  @override
  State<SealedPack> createState() => _SealedPackState();
}

class _SealedPackState extends State<SealedPack> with SingleTickerProviderStateMixin {
  /// Where the pointer went while slashing, in the pack's coordinates.
  final List<Offset> _trail = [];
  bool _torn = false;
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onOpen();
    });

  /// The slash's extent sideways and up and down, as shares of the pack.
  (double, double) get _extent {
    if (_trail.length < 2) return (0, 0);
    var left = double.infinity, right = double.negativeInfinity;
    var top = double.infinity, bottom = double.negativeInfinity;
    for (final p in _trail) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
      if (p.dy < top) top = p.dy;
      if (p.dy > bottom) bottom = p.dy;
    }
    return ((right - left) / widget.width, (bottom - top) / widget.height);
  }

  /// Whether the slash runs up and down rather than sideways.
  bool get _vertical {
    final (dx, dy) = _extent;
    return dy > dx;
  }

  /// How far the slash went, 0 to 1, along its own direction.
  double get _cut {
    final (dx, dy) = _extent;
    return (dx > dy ? dx : dy).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _tear.dispose();
    super.dispose();
  }

  void _start(DragStartDetails details) {
    if (_torn || !widget.enabled) return;
    setState(() => _trail
      ..clear()
      ..add(details.localPosition));
  }

  void _slash(DragUpdateDetails details) {
    if (_torn || !widget.enabled) return;
    setState(() => _trail.add(details.localPosition));
  }

  void _release(DragEndDetails details) {
    if (_torn || !widget.enabled) return;
    if (_cut >= SealedPack.tearAt) {
      setState(() => _torn = true);
      _tear.forward();
    } else {
      setState(_trail.clear);
    }
  }

  /// The cut as a line from one edge of the pack to the opposite one: the
  /// slash's own path, extended straight to both edges; a straight line
  /// at [SealedPack.cutAt] when the pack was tapped open.
  List<Offset> _cutLine() {
    if (_trail.length < 2) {
      final y = widget.height * SealedPack.cutAt;
      return [Offset(-1, y), Offset(widget.width + 1, y)];
    }
    final points = [..._trail];
    if (_vertical) {
      if (points.first.dy > points.last.dy) points.setAll(0, points.reversed.toList());
      return [Offset(points.first.dx, -1), ...points, Offset(points.last.dx, widget.height + 1)];
    }
    if (points.first.dx > points.last.dx) points.setAll(0, points.reversed.toList());
    return [Offset(-1, points.first.dy), ...points, Offset(widget.width + 1, points.last.dy)];
  }

  @override
  Widget build(BuildContext context) {
    final cut = _cutLine();
    final vertical = _trail.length >= 2 && _vertical;
    return GestureDetector(
      key: const Key('sealedPack'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled && !_torn ? widget.onOpen : null,
      onPanStart: _start,
      onPanUpdate: _slash,
      onPanEnd: _release,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _tear,
            builder: (context, _) {
              final t = Curves.easeIn.transform(_tear.value);
              // The piece that stays, and the one torn off: the top one for
              // a sideways cut, the left one for a vertical cut.
              final torn = vertical
                  ? Transform.translate(
                      offset: Offset(-t * widget.width * 0.6, t * widget.height * 0.2),
                      child: Transform.rotate(
                        angle: t * 0.4,
                        alignment: Alignment.topCenter,
                        child: Opacity(
                          opacity: 1 - t,
                          child: ClipPath(clipper: _Side(cut: cut, vertical: true, first: true), child: widget.child),
                        ),
                      ),
                    )
                  : Transform.translate(
                      offset: Offset(t * widget.width * 0.3, -t * widget.height * 0.6),
                      child: Transform.rotate(
                        angle: -t * 0.5,
                        alignment: Alignment.centerLeft,
                        child: Opacity(
                          opacity: 1 - t,
                          child: ClipPath(clipper: _Side(cut: cut, vertical: false, first: true), child: widget.child),
                        ),
                      ),
                    );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipPath(clipper: _Side(cut: cut, vertical: vertical, first: false), child: widget.child),
                  ),
                  Positioned.fill(child: torn),
                  if (_trail.isNotEmpty && !_torn)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CutPainter(trail: _trail, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The part of the pack on one side of the [cut] line. For a sideways
/// cut, [first] is the piece above it; for a [vertical] one, the piece
/// left of it.
class _Side extends CustomClipper<Path> {
  const _Side({required this.cut, required this.vertical, required this.first});

  final List<Offset> cut;
  final bool vertical;
  final bool first;

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(cut.first.dx, cut.first.dy);
    for (final p in cut.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (vertical) {
      final far = first ? -size.width : size.width * 2;
      path
        ..lineTo(far, cut.last.dy)
        ..lineTo(far, cut.first.dy);
    } else {
      final far = first ? -size.height : size.height * 2;
      path
        ..lineTo(cut.last.dx, far)
        ..lineTo(cut.first.dx, far);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_Side old) =>
      old.first != first || old.vertical != vertical || old.cut.length != cut.length || old.cut != cut;
}

/// The cut drawn as the slash goes: a bright line along the pointer's
/// [trail].
class _CutPainter extends CustomPainter {
  const _CutPainter({required this.trail, required this.color});

  final List<Offset> trail;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.isEmpty) return;
    final path = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (final p in trail.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CutPainter old) => old.trail.length != trail.length || old.color != color;
}
