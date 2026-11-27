import 'package:flutter/material.dart';

import '../card_info/domain/card_info.dart';
import '../card_info/domain/ygo_words.dart';
import '../pools/domain/card_customs.dart';

/// The parts of a drawn card that stand for a field: what a click on the
/// card can ask to edit.
enum YgoCardPart { name, attribute, level, type, text, atk, def, link, set, code }

/// A print code (`CIBR-FR077`) in its two parts: the set (`CIBR`) and the
/// number (`FR077`); the whole as the set when there is no dash.
({String set, String code}) splitPrintCode(String printCode) {
  final at = printCode.indexOf('-');
  return at < 0 ? (set: printCode, code: '') : (set: printCode.substring(0, at), code: printCode.substring(at + 1));
}

/// A set and a number as one print code, empty parts left out.
String joinPrintCode(String set, String code) =>
    [if (set.trim().isNotEmpty) set.trim(), if (code.trim().isNotEmpty) code.trim()].join('-');

/// A Yu-Gi-Oh! card drawn from its details rather than scanned: the frame
/// of its kind, its artwork, attribute, level or rank stars, link arrows,
/// type line, text, ATK and DEF, set number and passcode.
///
/// The pictures come from `assets/ygo_template` (see
/// `tool/export_ygo_template.py`); every place below is in that template's
/// pixels, the card being [width] by [height], and the whole is scaled to
/// the room given. A pendulum monster is drawn in its base frame, without
/// its scales and pendulum effect.
class YgoCardFace extends StatelessWidget {
  const YgoCardFace({
    super.key,
    required this.name,
    required this.info,
    this.code,
    this.passcode,
    this.artwork,
    this.language = 'en',
    this.onPart,
  });

  /// The name printed, in the language shown.
  final String name;
  final YgoCardInfo info;

  /// The print code (`CIBR-FR077`) and the passcode, printed when given.
  final String? code;
  final String? passcode;

  /// The artwork alone (no frame), cropped square; empty box without one.
  final ImageProvider? artwork;

  /// The language of the card's fixed words (attribute, "Spell Card").
  final String language;

  /// When given, the card's parts can be clicked (the pointer shows it,
  /// and the part lights up under it): called with the part.
  final void Function(YgoCardPart part)? onPart;

  static const width = 1389.0;
  static const height = 2026.0;
  static const _assets = 'assets/ygo_template';

  static const _artwork = Rect.fromLTWH(168, 372, 1053, 1053);
  static const _name = Rect.fromLTWH(108, 113, 1038, 99);
  static const _attribute = Rect.fromLTWH(1162, 88, 133, 133);
  static const _levels = Rect.fromLTWH(142, 244, 1101, 89);
  static const _levelPitch = 92.0;
  static const _monsterType = Rect.fromLTWH(107, 1526, 1170, 54);
  static const _monsterText = Rect.fromLTWH(105, 1582, 1172, 259);
  static const _spellText = Rect.fromLTWH(106, 1532, 1175, 360);
  static const _spellType = Rect.fromLTWH(321, 262, 925, 66);
  static const _spellIcon = 77.0;
  static const _statsLine = Rect.fromLTWH(104, 1842, 1177, 5);
  // "ATK/" and "DEF/" against the left of their box, the number against
  // its right, so the numbers line up from card to card.
  static const _atk = Rect.fromLTWH(747, 1853, 249, 42);
  static const _def = Rect.fromLTWH(1030, 1853, 239, 42);
  static const _linkLabel = Rect.fromLTWH(1030, 1854, 197, 41);
  static const _linkNumber = Rect.fromLTWH(1232, 1853, 49, 42);
  static const _setNumber = Rect.fromLTWH(813, 1463, 432, 29);
  static const _setNumberLink = Rect.fromLTWH(708, 1463, 432, 29);
  static const _code = Rect.fromLTWH(65, 1937, 400, 30);

  /// The link arrows' boxes, by YGOPRODeck's marker names.
  static const _arrows = <String, Rect>{
    'top': Rect.fromLTWH(542, 274, 305, 97),
    'top-left': Rect.fromLTWH(92, 296, 165, 165),
    'top-right': Rect.fromLTWH(1132, 296, 165, 165),
    'bottom': Rect.fromLTWH(542, 1426, 305, 79),
    'right': Rect.fromLTWH(1222, 746, 97, 305),
    'left': Rect.fromLTWH(70, 746, 97, 305),
    'bottom-right': Rect.fromLTWH(1132, 1336, 165, 165),
    'bottom-left': Rect.fromLTWH(92, 1336, 165, 165),
  };

  static const _frames = {'normal', 'effect', 'ritual', 'fusion', 'synchro', 'xyz', 'link', 'spell', 'trap', 'token'};
  static const _attributes = {'dark', 'divine', 'earth', 'fire', 'light', 'water', 'wind'};
  static const _spellIcons = {'continuous', 'counter', 'equip', 'field', 'quick-play', 'ritual'};

  /// The frame drawn for [info]: its own (a pendulum's base frame), a
  /// spell's or a trap's, the effect one when it is unknown.
  static String frameOf(YgoCardInfo info) {
    if (info.kind == YgoKind.spell || info.kind == YgoKind.skill) return 'spell';
    if (info.kind == YgoKind.trap) return 'trap';
    final frame = info.frameType.replaceFirst('_pendulum', '');
    if (_frames.contains(frame)) return frame;
    return info.isNormalMonster ? 'normal' : 'effect';
  }

  /// The type line of a monster as printed, in [language] where its words
  /// are known: `[Zombie/Effect]`, `[Magicien/Effet]`. A word of the
  /// user's own is printed as typed.
  static String monsterTypeLine(YgoCardInfo info, {String language = 'en'}) {
    final words = ygoSubtypes(race: info.race, categories: info.categories);
    final known = ygoWords[language] ?? const <String, String>{};
    // Hair spaces around the bars, as the template sets them.
    return '[${[for (final w in words) known[w.toLowerCase()] ?? w].join(' / ')}]';
  }

  /// A card text as printed: each `●` starts its own line.
  static String printedText(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll(RegExp(r'\s*●\s*'), '\n● ').trim();

  /// `[Spell Card` and `]`, around the icon of a spell or trap that has one.
  static String spellTypeLabel(YgoKind kind, String language) => switch ((kind, language)) {
        (YgoKind.trap, 'fr') => 'Carte Piège',
        (YgoKind.trap, _) => 'Trap Card',
        (_, 'fr') => 'Carte Magie',
        _ => 'Spell Card',
      };

  /// How much of a screen pixel the thin texts are thickened by on each
  /// side when the card is shown small.
  static const _thickening = 0.27;

  /// The strokes added to a text so it stays readable on a card shown at
  /// [scale] of the template: the fonts are thin, and below about half the
  /// template's size their strokes are less than a pixel wide and fade.
  /// Nothing on a large card, which reads as printed.
  static List<Shadow>? thickeningAt(double scale, Color color) {
    if (scale >= 0.55) return null;
    // More the smaller the card, by the same amount on screen.
    final by = _thickening / scale;
    return [
      Shadow(offset: Offset(by, 0), color: color),
      Shadow(offset: Offset(-by, 0), color: color),
      Shadow(offset: Offset(0, by * 0.5), color: color),
    ];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // What the card is scaled by to fit the room given.
          final across = constraints.maxWidth.isFinite ? constraints.maxWidth / width : double.infinity;
          final down = constraints.maxHeight.isFinite ? constraints.maxHeight / height : double.infinity;
          final scale = across < down ? across : down;
          return _face(context, scale.isFinite ? scale : 1);
        },
      );

  Widget _face(BuildContext context, double scale) {
    final thick = thickeningAt(scale, Colors.black);
    final frame = frameOf(info);
    final monster = info.kind == YgoKind.monster;
    final link = frame == 'link';
    final xyz = frame == 'xyz';
    // Names read white on the dark frames, as printed.
    final nameColor = (xyz || link || !monster) ? Colors.white : Colors.black;
    final frameInk = xyz ? Colors.white : Colors.black;
    final attribute = switch (info.kind) {
      YgoKind.spell => 'spell',
      YgoKind.trap => 'trap',
      YgoKind.skill => null,
      YgoKind.monster => info.attribute?.toLowerCase(),
    };
    final attributeAsset = attribute == null
        ? null
        : _attributes.contains(attribute)
            ? '$_assets/attribute-$attribute${language == 'fr' ? '-fr' : ''}.png'
            : (attribute == 'spell' || attribute == 'trap')
                ? '$_assets/attribute-$attribute.png'
                : null;
    final spellIcon = monster ? null : info.race?.toLowerCase();
    final stars = (info.level ?? 0).clamp(0, 12);
    final markers = {for (final m in info.linkMarkers) m.toLowerCase()};
    final text = printedText(info.text ?? '');

    // A printed card: its texts keep their size whatever the system's text
    // scale, or nothing would fit its boxes.
    return MediaQuery.withNoTextScaling(
      child: FittedBox(
      child: SizedBox(
        width: width,
        height: height,
        child: DefaultTextStyle(
        // Its own text styles only, wherever it is shown.
        style: const TextStyle(decoration: TextDecoration.none, color: Colors.black),
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset('$_assets/frame-$frame.jpg', fit: BoxFit.fill)),
            if (artwork case final artwork?)
              Positioned.fromRect(
                rect: _artwork,
                child: Image(image: artwork, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
            Positioned.fromRect(
              rect: _name,
              child: _FittedLine(
                key: const Key('ygoName'),
                text: name,
                style: TextStyle(fontFamily: 'YgoName', fontSize: 166, color: nameColor, height: 1),
                // The capitals sit in the middle of the name bar.
                shift: -19,
                // Slightly narrow, as printed; a long name is squeezed to
                // 30% at most, then printed smaller.
                maxSqueeze: 0.97,
                minSqueeze: 0.3,
              ),
            ),
            if (attributeAsset != null)
              Positioned.fromRect(rect: _attribute, child: Image.asset(attributeAsset, fit: BoxFit.fill)),
            // Levels fill from the right, ranks from the left.
            if (monster && !link)
              for (var i = 0; i < stars; i++)
                Positioned(
                  key: ValueKey('ygoStar-$i'),
                  left: xyz ? _levels.left + i * _levelPitch : _levels.right - _levels.height - i * _levelPitch,
                  top: _levels.top,
                  width: _levels.height,
                  height: _levels.height,
                  child: Image.asset('$_assets/${xyz ? 'rank' : 'level'}.png', fit: BoxFit.fill),
                ),
            if (link)
              for (final MapEntry(key: marker, value: rect) in _arrows.entries)
                Positioned.fromRect(
                  key: ValueKey('ygoArrow-$marker-${markers.contains(marker)}'),
                  rect: rect,
                  child: Image.asset(
                    '$_assets/link-$marker-${markers.contains(marker) ? 'active' : 'inactive'}.png',
                    fit: BoxFit.fill,
                  ),
                ),
            if (!monster)
              Positioned.fromRect(
                rect: _spellType,
                // Against the right edge, smaller when a long label needs it.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                  key: const Key('ygoSpellType'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('[${spellTypeLabel(info.kind, language)}', style: _typeStyle(71)),
                    if (_spellIcons.contains(spellIcon)) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: _spellIcon,
                        height: _spellIcon,
                        child: Image.asset('$_assets/icon-$spellIcon.png', fit: BoxFit.fill),
                      ),
                    ],
                    Text(']', style: _typeStyle(71)),
                  ],
                  ),
                ),
              ),
            if (monster)
              Positioned.fromRect(
                rect: _monsterType,
                child: _FittedLine(
                  key: const Key('ygoType'),
                  text: monsterTypeLine(info, language: language),
                  style: _typeStyle(45).copyWith(shadows: thick),
                ),
              ),
            Positioned.fromRect(
              rect: monster ? _monsterText : _spellText,
              child: _FittedText(
                key: const Key('ygoText'),
                text: text,
                // A monster without effect tells its story, in italics.
                style: TextStyle(
                  fontFamily: info.isNormalMonster ? 'YgoFlavor' : 'YgoText',
                  color: Colors.black,
                  height: 1,
                  shadows: thick,
                ),
                maxSize: 42,
              ),
            ),
            if (monster) ...[
              Positioned.fromRect(rect: _statsLine, child: const ColoredBox(color: Colors.black)),
              Positioned.fromRect(
                rect: link ? _atk.shift(const Offset(-282, 0)) : _atk,
                child: _Stat(key: const Key('ygoAtk'), label: 'ATK/', value: info.atkLabel ?? '?'),
              ),
              if (link) ...[
                Positioned.fromRect(rect: _linkLabel, child: Image.asset('$_assets/link-label.png', fit: BoxFit.fill)),
                Positioned.fromRect(
                  rect: _linkNumber,
                  child: _Stat(key: const Key('ygoLink'), value: '${info.linkRating ?? markers.length}'),
                ),
              ] else
                Positioned.fromRect(
                  rect: _def,
                  child: _Stat(key: const Key('ygoDef'), label: 'DEF/', value: info.defLabel ?? '?'),
                ),
            ],
            if (code case final code?)
              Positioned.fromRect(
                rect: link ? _setNumberLink : _setNumber,
                // The set and the number, each a part of its own to click.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (part, text) in [
                      (YgoCardPart.set, splitPrintCode(code).set),
                      (YgoCardPart.code, splitPrintCode(code).code),
                    ]) ...[
                      if (part == YgoCardPart.code && splitPrintCode(code).code.isNotEmpty)
                        Text('-', style: _smallStyle(frameInk).copyWith(shadows: thickeningAt(scale, frameInk))),
                      _PartButton(
                        key: ValueKey('ygoPart-${part.name}'),
                        onTap: switch (onPart) { null => null, final on => () => on(part) },
                        child: Text(
                          // Room to click an empty part.
                          text.isEmpty && onPart != null ? '    ' : text,
                          maxLines: 1,
                          softWrap: false,
                          style: _smallStyle(frameInk).copyWith(shadows: thickeningAt(scale, frameInk)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (passcode case final passcode?)
              Positioned.fromRect(
                rect: _code,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    passcode.padLeft(8, '0'),
                    maxLines: 1,
                    softWrap: false,
                    style: _smallStyle(frameInk).copyWith(letterSpacing: 4, shadows: thickeningAt(scale, frameInk)),
                  ),
                ),
              ),
            if (onPart case final onPart?)
              for (final (part, rect) in [
                (YgoCardPart.name, _name),
                if (monster) (YgoCardPart.attribute, _attribute),
                if (monster && !link) (YgoCardPart.level, _levels),
                (YgoCardPart.type, monster ? _monsterType : _spellType),
                (YgoCardPart.text, monster ? _monsterText : _spellText),
                if (monster) (YgoCardPart.atk, link ? _atk.shift(const Offset(-282, 0)) : _atk),
                if (monster && !link) (YgoCardPart.def, _def),
                if (link) (YgoCardPart.link, _linkLabel.expandToInclude(_linkNumber)),
              ])
                Positioned.fromRect(
                  // A little room around, easier to aim at.
                  rect: rect.inflate(6),
                  child: _PartButton(key: ValueKey('ygoPart-${part.name}'), onTap: () => onPart(part)),
                ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  static TextStyle _typeStyle(double size) =>
      TextStyle(fontFamily: 'YgoType', fontSize: size, color: Colors.black, height: 1, letterSpacing: 1);

  static TextStyle _smallStyle(Color color) =>
      TextStyle(fontFamily: 'YgoSmall', fontSize: 37, color: color, height: 1, letterSpacing: 1.5);
}

/// A part of the card that can be clicked: outlined while the pointer is
/// over it.
class _PartButton extends StatefulWidget {
  const _PartButton({super.key, required this.onTap, this.child});

  /// Nothing to do: the part is only drawn.
  final VoidCallback? onTap;
  final Widget? child;

  @override
  State<_PartButton> createState() => _PartButtonState();
}

class _PartButtonState extends State<_PartButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child ?? const SizedBox.shrink();
    return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered ? Colors.white.withValues(alpha: 0.18) : null,
              border: _hovered ? Border.all(color: Colors.white, width: 5) : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: _hovered ? const [BoxShadow(color: Colors.black54, blurRadius: 8)] : null,
            ),
            child: widget.child,
          ),
        ),
      );
  }
}

/// ATK, DEF or the link rating in bold small caps: the [label] against
/// the left of the box, the [value] against its right.
class _Stat extends StatelessWidget {
  const _Stat({super.key, this.label, required this.value});

  final String? label;
  final String value;

  static const _style =
      TextStyle(fontFamily: 'YgoStats', fontSize: 57, color: Colors.black, height: 1, letterSpacing: 2);

  @override
  Widget build(BuildContext context) => Stack(
        // Taller than its box and never wrapped: the box only places it.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (label case final label?)
            Positioned(left: 0, child: Text(label, maxLines: 1, softWrap: false, style: _style)),
          Positioned(right: 0, child: Text(value, maxLines: 1, softWrap: false, style: _style)),
        ],
      );
}

/// One line of text at its own size, squeezed sideways when it is wider
/// than its box (as long names are on a card), never wrapped; past
/// [minSqueeze] the whole line is printed smaller. It is never wider than
/// [maxSqueeze] of its own width. [shift] moves it down (up when
/// negative), for a font not sitting in the middle of its line.
class _FittedLine extends StatelessWidget {
  const _FittedLine({
    super.key,
    required this.text,
    required this.style,
    this.shift = 0,
    this.minSqueeze = 0.5,
    this.maxSqueeze = 1,
  });

  final String text;
  final TextStyle style;
  final double shift;
  final double minSqueeze;
  final double maxSqueeze;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final room = constraints.maxWidth / painter.width;
          final needed = room < maxSqueeze ? room : maxSqueeze;
          painter.dispose();
          final squeeze = needed < minSqueeze ? minSqueeze : needed;
          // What squeezing does not take is taken from the size.
          final shrink = needed / squeeze;
          return OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(0, shift),
              child: Transform(
                transform: Matrix4.diagonal3Values(squeeze * shrink, shrink, 1),
                alignment: Alignment.centerLeft,
                child: Text(text, maxLines: 1, softWrap: false, style: style),
              ),
            ),
          );
        },
      );
}

/// A justified paragraph fitted to its box as the template fits it: at
/// [maxSize] and [maxSqueeze] of its width (printed texts are a little
/// narrow), else down to nine tenths of that size, then squeezed sideways
/// (to half its width at most) so more words fit a line, and only then
/// printed smaller still.
class _FittedText extends StatelessWidget {
  const _FittedText({super.key, required this.text, required this.style, required this.maxSize});

  final String text;
  final TextStyle style;
  final double maxSize;

  static const maxSqueeze = 0.88;
  static const minSqueeze = 0.5;
  static const minSize = 12.0;

  /// The font size and the sideways squeeze at which [text] fits a box
  /// [width] by [height].
  static ({double size, double squeeze}) fit(
      String text, TextStyle style, double maxSize, double width, double height) {
    bool fits(double size, double squeeze) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: width / squeeze);
      final ok = painter.height <= height;
      painter.dispose();
      return ok;
    }

    // The largest value between [low] (which fits) and [high] that fits.
    double search(double low, double high, double step, bool Function(double value) ok) {
      while (high - low > step) {
        final middle = (low + high) / 2;
        ok(middle) ? low = middle : high = middle;
      }
      return low;
    }

    if (fits(maxSize, maxSqueeze)) return (size: maxSize, squeeze: maxSqueeze);
    final small = maxSize * 0.9;
    if (fits(small, maxSqueeze)) {
      return (size: search(small, maxSize, 0.25, (s) => fits(s, maxSqueeze)), squeeze: maxSqueeze);
    }
    if (fits(small, minSqueeze)) {
      return (size: small, squeeze: search(minSqueeze, maxSqueeze, 0.01, (q) => fits(small, q)));
    }
    if (!fits(minSize, minSqueeze)) return (size: minSize, squeeze: minSqueeze);
    return (size: search(minSize, small, 0.25, (s) => fits(s, minSqueeze)), squeeze: minSqueeze);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final (:size, :squeeze) = fit(text, style, maxSize, constraints.maxWidth, constraints.maxHeight);
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: constraints.maxWidth / squeeze,
              minHeight: 0,
              maxHeight: constraints.maxHeight,
              child: Transform(
                transform: Matrix4.diagonal3Values(squeeze, 1, 1),
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth / squeeze,
                  child: Text(text, textAlign: TextAlign.justify, style: style.copyWith(fontSize: size)),
                ),
              ),
            ),
          );
        },
      );
}
