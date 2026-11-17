import 'package:flutter/material.dart';

/// A sealed pack that opens on a tap, or by slashing across its top: a
/// sideways drag draws the cut along the pack's top edge and, once long
/// enough, tears the top strip off before [onOpen] fires.
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

  /// Where the cut runs, as a share of the pack's height from the top.
  static const cutAt = 0.14;

  /// How far across the pack the slash must go to tear it.
  static const tearAt = 0.55;

  @override
  State<SealedPack> createState() => _SealedPackState();
}

class _SealedPackState extends State<SealedPack> with TickerProviderStateMixin {
  /// Where the pointer went while slashing, in the pack's coordinates.
  final List<Offset> _trail = [];
  bool _torn = false;
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onOpen();
    });

  /// Breathes the guide while the pack waits.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  /// How far across the pack the slash went, 0 to 1.
  double get _cut {
    if (_trail.length < 2) return 0;
    var left = double.infinity, right = double.negativeInfinity;
    for (final p in _trail) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
    }
    return ((right - left) / widget.width).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _tear.dispose();
    _pulse.dispose();
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

  @override
  Widget build(BuildContext context) {
    final cutY = widget.height * SealedPack.cutAt;
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
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // The body, below the cut.
                Positioned.fill(
                  child: ClipRect(
                    clipper: _Band(top: cutY, bottom: widget.height),
                    child: widget.child,
                  ),
                ),
                // The top strip, torn off upward once the slash went through.
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(t * widget.width * 0.3, -t * widget.height * 0.6),
                    child: Transform.rotate(
                      angle: -t * 0.5,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: 1 - t,
                        child: ClipRect(
                          clipper: _Band(top: 0, bottom: cutY),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
                // The guide: where to slash, while nothing is cut yet.
                if (_trail.isEmpty && !_torn && widget.enabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: _GuidePainter(y: cutY, glow: 0.45 + 0.4 * _pulse.value),
                        ),
                      ),
                    ),
                  ),
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

/// A dashed line along the cut with a scissors mark at its left end, so
/// the player knows where to slash; it breathes with [glow].
class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.y, required this.glow});

  final double y;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: glow * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var x = 18.0; x < size.width - 4; x += 12) {
      final end = (x + 6).clamp(0.0, size.width - 4);
      canvas.drawLine(Offset(x, y), Offset(end, y), shadow);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
    // The scissors: two rings and two blades pointing along the line.
    final c = Offset(10, y);
    canvas.drawCircle(c + const Offset(-4, -4), 2.6, shadow);
    canvas.drawCircle(c + const Offset(-4, 4), 2.6, shadow);
    canvas.drawCircle(c + const Offset(-4, -4), 2.6, paint);
    canvas.drawCircle(c + const Offset(-4, 4), 2.6, paint);
    canvas.drawLine(c + const Offset(-2, -2), c + const Offset(7, 2.5), shadow);
    canvas.drawLine(c + const Offset(-2, 2), c + const Offset(7, -2.5), shadow);
    canvas.drawLine(c + const Offset(-2, -2), c + const Offset(7, 2.5), paint);
    canvas.drawLine(c + const Offset(-2, 2), c + const Offset(7, -2.5), paint);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.y != y || old.glow != glow;
}

/// A horizontal band of the pack, from [top] to [bottom].
class _Band extends CustomClipper<Rect> {
  const _Band({required this.top, required this.bottom});

  final double top;
  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-size.width, top, size.width * 2, bottom);

  @override
  bool shouldReclip(_Band old) => old.top != top || old.bottom != bottom;
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
