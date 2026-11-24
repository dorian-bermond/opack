import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The cards a [MarqueeSelection] can catch: every built [MarqueeTarget]
/// under it.
class _MarqueeScope extends InheritedWidget {
  const _MarqueeScope({required this.targets, required super.child});

  final Set<_MarqueeTargetState> targets;

  @override
  bool updateShouldNotify(_MarqueeScope oldWidget) => false;
}

/// [child] as something a selection rectangle catches under [id]; plain
/// outside of a [MarqueeSelection].
class MarqueeTarget extends StatefulWidget {
  const MarqueeTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<MarqueeTarget> createState() => _MarqueeTargetState();
}

class _MarqueeTargetState extends State<MarqueeTarget> {
  Set<_MarqueeTargetState>? _targets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final targets = context.getInheritedWidgetOfExactType<_MarqueeScope>()?.targets;
    if (targets == _targets) return;
    _targets?.remove(this);
    _targets = targets?..add(this);
  }

  @override
  void dispose() {
    _targets?.remove(this);
    super.dispose();
  }

  /// Where the target is on screen, `null` while it is not laid out.
  Rect? get _rect {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Lets the mouse draw a selection rectangle over [child], a vertical
/// scroll view driven by [controller], as in a file manager: holding the
/// left button and dragging catches every [MarqueeTarget] the rectangle
/// touches. The rectangle is anchored in the content, so the wheel and the
/// edges of the view scroll it along. It starts anywhere from the first
/// target down (what is above, a header, keeps its own gestures).
///
/// [onStart] tells a drag begins, `additive` with Ctrl or Shift held (the
/// selection is added to, else replaced); [onHits] gives the caught ids as
/// the rectangle changes. A press released without really moving is a
/// click: [onClick] gets the target under it, `null` on empty space.
class MarqueeSelection extends StatefulWidget {
  const MarqueeSelection({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onStart,
    required this.onHits,
    required this.onClick,
    required this.child,
  });

  final ScrollController controller;
  final bool enabled;
  final void Function(bool additive) onStart;
  final void Function(Set<String> ids) onHits;
  final void Function(String? id) onClick;
  final Widget child;

  /// The move from which a press is a rectangle rather than a click.
  static const threshold = 6.0;

  /// How close to the top or bottom edge the pointer scrolls the view.
  static const edge = 40.0;

  @override
  State<MarqueeSelection> createState() => _MarqueeSelectionState();
}

class _MarqueeSelectionState extends State<MarqueeSelection> {
  final _targets = <_MarqueeTargetState>{};

  /// Where the drag began, in the content (the screen plus the scroll
  /// offset), and where the pointer is on screen; `null` when idle.
  Offset? _start;
  Offset _pointer = Offset.zero;

  /// Whether the press moved enough to be a rectangle.
  bool _drawing = false;

  /// The targets met during the drag, where they are in the content: the
  /// ones scrolled out of the view stay caught.
  final _seen = <_MarqueeTargetState, (String, Rect)>{};
  Timer? _autoScroll;

  /// The view's corner on screen, to paint the rectangle in its own space.
  Offset _origin = Offset.zero;

  double get _offset => widget.controller.hasClients ? widget.controller.offset : 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrolled);
  }

  @override
  void didUpdateWidget(MarqueeSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scrolled);
      widget.controller.addListener(_scrolled);
    }
    if (!widget.enabled && _start != null) _stop();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrolled);
    _autoScroll?.cancel();
    super.dispose();
  }

  /// The scroll offset the targets were last laid out at: a scroll moves
  /// them only at the next frame.
  double _laidOut = 0;

  void _scrolled() {
    if (_start == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _start == null) return;
      _laidOut = _offset;
      if (_drawing) _update();
    });
  }

  /// Whether a press at [position] may start a rectangle: from the first
  /// target down.
  bool _allows(Offset position) {
    if (!widget.enabled) return false;
    double? top;
    for (final target in _targets) {
      final rect = target._rect;
      if (rect != null && (top == null || rect.top < top)) top = rect.top;
    }
    return top != null && position.dy >= top;
  }

  void _begin(DragStartDetails details) {
    _start = details.globalPosition + Offset(0, _offset);
    _pointer = details.globalPosition;
    _drawing = false;
    _laidOut = _offset;
    _seen.clear();
  }

  void _move(DragUpdateDetails details) {
    final start = _start;
    if (start == null) return;
    _pointer = details.globalPosition;
    if (!_drawing) {
      if ((_pointer + Offset(0, _offset) - start).distance < MarqueeSelection.threshold) return;
      _drawing = true;
      final keys = HardwareKeyboard.instance;
      widget.onStart(keys.isControlPressed || keys.isShiftPressed || keys.isMetaPressed);
      _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) => _scrollAtEdges());
    }
    _update();
  }

  /// The rectangle in the content.
  Rect get _rect => Rect.fromPoints(_start!, _pointer + Offset(0, _offset));

  void _update() {
    final shift = Offset(0, _laidOut);
    for (final target in _targets) {
      if (target._rect case final rect?) _seen[target] = (target.widget.id, rect.shift(shift));
    }
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached) _origin = box.localToGlobal(Offset.zero);
    final rect = _rect;
    widget.onHits({
      for (final (id, where) in _seen.values)
        if (where.overlaps(rect)) id,
    });
    setState(() {});
  }

  /// Scrolls while the pointer is by (or past) the top or bottom edge,
  /// faster the further it goes.
  void _scrollAtEdges() {
    final box = context.findRenderObject();
    final controller = widget.controller;
    if (box is! RenderBox || !controller.hasClients) return;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    final above = bounds.top + MarqueeSelection.edge - _pointer.dy;
    final below = _pointer.dy - (bounds.bottom - MarqueeSelection.edge);
    final delta = above > 0 ? -above : (below > 0 ? below : 0.0);
    if (delta == 0) return;
    final position = controller.position;
    final target = (position.pixels + delta.clamp(-60.0, 60.0) * 0.4)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) controller.jumpTo(target);
  }

  void _end() {
    final wasDrawing = _drawing;
    final pointer = _pointer;
    final pressed = _start != null;
    _stop();
    if (!pressed || wasDrawing) return;
    // Not a rectangle: a click, on the target under the pointer if any.
    String? under;
    for (final target in _targets) {
      if (target._rect?.contains(pointer) ?? false) under = target.widget.id;
    }
    widget.onClick(under);
  }

  void _stop() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _start = null;
    _drawing = false;
    _seen.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return RawGestureDetector(
      gestures: {
        _MarqueeRecognizer: GestureRecognizerFactoryWithHandlers<_MarqueeRecognizer>(
          () => _MarqueeRecognizer(allows: _allows),
          (recognizer) => recognizer
            ..allows = _allows
            ..onStart = _begin
            ..onUpdate = _move
            ..onEnd = ((_) => _end())
            ..onCancel = _stop,
        ),
      },
      child: Stack(
        children: [
          _MarqueeScope(targets: _targets, child: widget.child),
          if (_drawing)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  child: CustomPaint(
                    key: const Key('marquee'),
                    painter: _MarqueePainter(
                      // In the view: the content rectangle less the scroll
                      // and the view's place on screen.
                      from: _start! - Offset(0, _offset) - _origin,
                      to: _pointer - _origin,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A drag of the mouse's left button, only where [allows] says so. The
/// mouse does not scroll by dragging, so nothing is taken from the view;
/// touch keeps its own gestures.
class _MarqueeRecognizer extends PanGestureRecognizer {
  _MarqueeRecognizer({required this.allows})
      : super(
          supportedDevices: const {PointerDeviceKind.mouse},
          allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
        ) {
    // The rectangle's corner is where the button went down, not where the
    // move was told from a click.
    dragStartBehavior = DragStartBehavior.down;
  }

  bool Function(Offset position) allows;

  @override
  bool isPointerAllowed(PointerEvent event) => super.isPointerAllowed(event) && allows(event.position);
}

class _MarqueePainter extends CustomPainter {
  const _MarqueePainter({required this.from, required this.to, required this.color});

  /// The rectangle's corners in the view.
  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(from, to);
    canvas
      ..drawRect(rect, Paint()..color = color.withValues(alpha: 0.18))
      ..drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_MarqueePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to || oldDelegate.color != color;
}
