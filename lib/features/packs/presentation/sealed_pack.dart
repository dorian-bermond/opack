import 'package:flutter/material.dart';

/// Relays a slash started anywhere on the screen to the sealed pack: the
/// pointer's positions, in global coordinates.
class SlashController extends ChangeNotifier {
  final List<Offset> _points = [];
  bool _ended = false;

  List<Offset> get points => List.unmodifiable(_points);
  bool get ended => _ended;

  void start(Offset global) {
    _points
      ..clear()
      ..add(global);
    _ended = false;
    notifyListeners();
  }

  void move(Offset global) {
    _points.add(global);
    notifyListeners();
  }

  void end() {
    _ended = true;
    notifyListeners();
  }
}

/// A sealed pack that opens on a tap, or by slashing across it: a drag
/// draws the cut along the pointer's path where it crosses the pack and,
/// once it spans enough of the pack sideways or up and down, tears the
/// pack in two along that line before [onOpen] fires. With a
/// [controller], the slash may start anywhere on the screen.
class SealedPack extends StatefulWidget {
  const SealedPack({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    required this.onOpen,
    this.enabled = true,
    this.controller,
    this.onTear,
  });

  final Widget child;
  final double width;
  final double height;

  /// Fires once the pack is fully open.
  final VoidCallback onOpen;
  final bool enabled;
  final SlashController? controller;

  /// Fires as the pack tears, answering what lies inside (the first card,
  /// face up), shown behind the pieces as they move away; `null` or
  /// absent, the pack just tears.
  final Widget? Function()? onTear;

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
  /// What the pack holds, once torn.
  Widget? _inside;

  /// The tear, then the bigger piece moving away.
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onOpen();
    });

  /// Tears the pack open, by a slash or a tap.
  void _tearOpen() {
    setState(() {
      _torn = true;
      _inside = widget.onTear?.call();
    });
    _tear.forward();
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_relayed);
  }

  @override
  void didUpdateWidget(SealedPack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_relayed);
      widget.controller?.addListener(_relayed);
    }
  }

  /// A slash relayed from outside: its points brought into the pack's
  /// coordinates, then handled like the pack's own.
  void _relayed() {
    final controller = widget.controller!;
    if (_torn || !widget.enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (controller.ended) {
      _release(DragEndDetails());
      return;
    }
    setState(() => _trail
      ..clear()
      ..addAll(controller.points.map(box.globalToLocal)));
  }

  /// The slash's extent sideways and up and down, as shares of the pack,
  /// counting only where it crosses the pack.
  (double, double) get _extent {
    if (_trail.length < 2) return (0, 0);
    var left = double.infinity, right = double.negativeInfinity;
    var top = double.infinity, bottom = double.negativeInfinity;
    for (final p in _trail) {
      final x = p.dx.clamp(0.0, widget.width);
      final y = p.dy.clamp(0.0, widget.height);
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
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
    widget.controller?.removeListener(_relayed);
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
      _tearOpen();
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

  /// What lies inside, lying still at the pack's center: drawn under the
  /// pieces, it shows as they move away. [shift] nudges it along with the
  /// bigger piece.
  Widget _insideCard(Offset shift) {
    final cardWidth = widget.width * 0.94;
    final cardHeight = cardWidth * 88 / 63;
    return Positioned(
      left: (widget.width - cardWidth) / 2 + shift.dx,
      top: (widget.height - cardHeight) / 2 + shift.dy,
      width: cardWidth,
      height: cardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: _inside,
      ),
    );
  }

  /// Whether the first piece (above a sideways cut, left of a vertical
  /// one) is the bigger of the two, judged by where the cut runs.
  bool _firstIsBigger(List<Offset> cut, bool vertical) {
    final inside = [for (final p in cut) if (vertical ? p.dy >= 0 && p.dy <= widget.height : p.dx >= 0 && p.dx <= widget.width) p];
    final points = inside.isEmpty ? cut : inside;
    final mean = points.fold(0.0, (sum, p) => sum + (vertical ? p.dx : p.dy)) / points.length;
    return vertical ? mean > widget.width / 2 : mean > widget.height / 2;
  }

  /// The way a piece leaves: straight away from the cut, up or down for a
  /// sideways cut, left or right for a vertical one.
  Offset _away({required bool first, required bool vertical}) =>
      vertical ? Offset(first ? -1 : 1, 0) : Offset(0, first ? -1 : 1);

  /// The opening in three parts: the pieces part ways; the bigger one
  /// pauses while the cards are pulled out of it back to the middle; then
  /// it leaves. Each as a 0 to 1 progress.
  static (double, double, double) _parts(double t) {
    double part(double from, double to) => Curves.easeInOut.transform(((t - from) / (to - from)).clamp(0.0, 1.0));
    return (part(0, 0.3), part(0.3, 0.65), part(0.65, 1));
  }

  @override
  Widget build(BuildContext context) {
    final cut = _cutLine();
    final vertical = _trail.length >= 2 && _vertical;
    return GestureDetector(
      key: const Key('sealedPack'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled && !_torn ? _tearOpen : null,
      // With a controller the screen relays the slash; else the pack takes it.
      onPanStart: widget.controller == null ? _start : null,
      onPanUpdate: widget.controller == null ? _slash : null,
      onPanEnd: widget.controller == null ? _release : null,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _tear,
            builder: (context, _) {
              final (p1, p2, p3) = _parts(_tear.value);
              final firstBigger = _firstIsBigger(cut, vertical);
              final size = Offset(widget.width, widget.height);
              Offset scaled(Offset direction, double by) => Offset(direction.dx * size.dx * by, direction.dy * size.dy * by);
              Widget piece({required bool first}) =>
                  ClipPath(clipper: _Side(cut: cut, vertical: vertical, first: first), child: widget.child);
              final smallDirection = _away(first: !firstBigger, vertical: vertical);
              final bigDirection = _away(first: firstBigger, vertical: vertical);

              // Part 1: both pieces part by a third of the pack. Part 3: they
              // go on out of sight.
              const step = 0.35;
              final smaller = Transform.translate(
                offset: scaled(smallDirection, step * p1 + 1.0 * p3),
                child: Opacity(opacity: 1 - p3, child: piece(first: !firstBigger)),
              );
              final bigger = Transform.translate(
                offset: scaled(bigDirection, step * p1 + 1.0 * p3),
                child: Opacity(opacity: 1 - p3, child: piece(first: firstBigger)),
              );
              // The cards ride in the bigger piece, then are pulled back to
              // the middle while it pauses.
              final shift = scaled(bigDirection, step * p1 * (1 - p2));

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_torn && _inside != null) _insideCard(shift),
                  Positioned.fill(child: bigger),
                  Positioned.fill(child: smaller),
                  // The cut, drawn only where it crosses the pack.
                  if (_trail.isNotEmpty && !_torn)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRect(
                          child: CustomPaint(
                            painter: _CutPainter(trail: _trail, color: Theme.of(context).colorScheme.primary),
                          ),
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
