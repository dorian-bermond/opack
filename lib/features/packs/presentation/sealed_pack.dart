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

class _SealedPackState extends State<SealedPack> with SingleTickerProviderStateMixin {
  /// The cut's progress across the pack while slashing, 0 to 1.
  double _cut = 0;
  bool _torn = false;
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onOpen();
    });

  @override
  void dispose() {
    _tear.dispose();
    super.dispose();
  }

  void _slash(DragUpdateDetails details) {
    if (_torn || !widget.enabled) return;
    setState(() => _cut = (_cut + details.delta.dx.abs() / widget.width).clamp(0.0, 1.0));
  }

  void _release(DragEndDetails details) {
    if (_torn || !widget.enabled) return;
    if (_cut >= SealedPack.tearAt) {
      setState(() => _torn = true);
      _tear.forward();
    } else {
      setState(() => _cut = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cutY = widget.height * SealedPack.cutAt;
    return GestureDetector(
      key: const Key('sealedPack'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled && !_torn ? widget.onOpen : null,
      onHorizontalDragUpdate: _slash,
      onHorizontalDragEnd: _release,
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
                if (_cut > 0 && !_torn)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _CutPainter(progress: _cut, y: cutY, color: Theme.of(context).colorScheme.primary)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
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

/// The cut drawn along the top of the pack as the slash goes: a bright
/// jagged line from the left edge to [progress] of the width.
class _CutPainter extends CustomPainter {
  const _CutPainter({required this.progress, required this.y, required this.color});

  final double progress;
  final double y;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final end = size.width * progress;
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x < end; x += 6) {
      path.lineTo(x + 3, (x ~/ 6).isEven ? y - 2.5 : y + 2.5);
    }
    path.lineTo(end, y);
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
  bool shouldRepaint(_CutPainter old) => old.progress != progress || old.y != y || old.color != color;
}
