import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/card_text/presentation/card_details_sheet.dart';
import '../../features/card_text/data/card_text_repository.dart';
import '../../features/catalog/domain/models.dart';
import '../../features/pools/presentation/pool_loader.dart';
import '../../l10n/app_localizations.dart';
import '../images/card_image_cache.dart';

/// The colors chosen for rarities, over the defaults; saved across
/// launches. [RarityPresentation.color] reads them.
final rarityColorsProvider = NotifierProvider<RarityColorsSetting, Map<Rarity, Color>>(RarityColorsSetting.new);

class RarityColorsSetting extends Notifier<Map<Rarity, Color>> {
  static String _key(Rarity rarity) => 'rarityColor:${rarity.name}';

  @override
  Map<Rarity, Color> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final colors = {
      for (final rarity in Rarity.values)
        if (prefs.getInt(_key(rarity)) case final argb?) rarity: Color(argb),
    };
    RarityPresentation._chosen = colors;
    return colors;
  }

  /// Colors [rarity], or restores its default with `null`.
  void set(Rarity rarity, Color? color) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (color == null) {
      prefs.remove(_key(rarity));
    } else {
      prefs.setInt(_key(rarity), color.toARGB32());
    }
    final colors = {for (final MapEntry(:key, :value) in state.entries) if (key != rarity) key: value, rarity: ?color};
    RarityPresentation._chosen = colors;
    state = colors;
  }
}

extension RarityPresentation on Rarity {
  /// The chosen colors, kept here so [color] stays a plain getter.
  static Map<Rarity, Color> _chosen = const {};

  String label(AppLocalizations l10n) => switch (this) {
        Rarity.common => l10n.rarityCommon,
        Rarity.uncommon => l10n.rarityUncommon,
        Rarity.rare => l10n.rarityRare,
        Rarity.mythic => l10n.rarityMythic,
        Rarity.superRare => l10n.raritySuperRare,
        Rarity.ultraRare => l10n.rarityUltraRare,
        Rarity.special => l10n.raritySpecial,
        Rarity.secretRare => l10n.raritySecretRare,
        Rarity.leader => l10n.rarityLeader,
        Rarity.parallel => l10n.rarityParallel,
        Rarity.manga => l10n.rarityManga,
        Rarity.treasure => l10n.rarityTreasure,
      };

  Color get color => _chosen[this] ?? defaultColor;

  Color get defaultColor => switch (this) {
        Rarity.common => Colors.blueGrey,
        Rarity.uncommon => Colors.teal,
        Rarity.rare => Colors.amber.shade700,
        Rarity.superRare => Colors.lightBlue,
        Rarity.ultraRare => Colors.purple,
        Rarity.mythic => Colors.deepOrange,
        Rarity.special => Colors.indigo,
        Rarity.secretRare => Colors.pink,
        Rarity.leader => Colors.cyan.shade700,
        Rarity.parallel => Colors.lime.shade700,
        Rarity.manga => Colors.red.shade900,
        Rarity.treasure => Colors.yellow.shade600,
      };
}

extension BoosterTypePresentation on BoosterType {
  String label(AppLocalizations l10n) => switch (this) {
        BoosterType.play => l10n.boosterPlay,
        BoosterType.draft => l10n.boosterDraft,
        BoosterType.standard => l10n.boosterStandard,
        BoosterType.set => l10n.boosterSet,
        BoosterType.collector => l10n.boosterCollector,
      };
}

/// How a revealed card shows its rarity: a colored border around it, or a
/// small colored dot at its bottom center.
enum RarityMarker { border, dot }

/// The chosen [RarityMarker], saved across launches.
final rarityMarkerProvider = NotifierProvider<RarityMarkerSetting, RarityMarker>(RarityMarkerSetting.new);

class RarityMarkerSetting extends Notifier<RarityMarker> {
  static const _key = 'rarityMarker';

  @override
  RarityMarker build() =>
      RarityMarker.values.asNameMap()[ref.read(sharedPreferencesProvider).getString(_key)] ?? RarityMarker.border;

  void select(RarityMarker marker) {
    ref.read(sharedPreferencesProvider).setString(_key, marker.name);
    state = marker;
  }
}

/// Width over height of a card: Yu-Gi-Oh! cards are 59 × 86 mm, MtG and
/// One Piece ones 63 × 88 mm.
double cardAspectRatio(CardData card) => card.passcode != null ? 59 / 86 : 63 / 88;

/// Width over height of [game]'s cards (see [cardAspectRatio]).
double gameCardAspect(Game game) => game == Game.ygo ? 59 / 86 : 63 / 88;

/// A card face (its picture once downloaded, else name and rarity), or its
/// back while [revealed] is false. Long-press or right-click a revealed card
/// for its text and text versions.
class CardTile extends ConsumerWidget {
  const CardTile({
    super.key,
    required this.card,
    this.revealed = true,
    this.onTap,
    this.hideRarity = false,
  });

  final CardData card;
  final bool revealed;
  final VoidCallback? onTap;

  /// Leaves the rarity marker out (in a tierlist, the tier says it all).
  final bool hideRarity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = dataLanguage(ref, context);
    final name = shownVersion(ref, card, language)?.name ?? card.nameFor(language);
    void details() => showCardDetails(context, card, poolId: PoolScope.of(context));
    final source = cardImageSource(card, language: pictureLanguage(ref, context));
    final image = revealed && source != null ? ref.watch(cardImageProvider(source)).value : null;

    final preview = revealed && image != null && ref.watch(cardHoverPreviewProvider);
    final marker = hideRarity ? null : ref.watch(rarityMarkerProvider);
    ref.watch(rarityColorsProvider); // rebuilds when a rarity color changes
    final dot = revealed && marker == RarityMarker.dot;

    return AspectRatio(
      aspectRatio: cardAspectRatio(card),
      child: _HoverPreview(
        enabled: preview,
        image: image,
        ratio: cardAspectRatio(card),
        child: _RarityGlow(
        enabled: !revealed,
        color: card.rarity.color,
        child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: revealed && marker == RarityMarker.border ? card.rarity.color : theme.colorScheme.outline,
            width: marker == RarityMarker.border ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: revealed ? details : null,
          onSecondaryTap: revealed ? details : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !revealed
                ? ColoredBox(
                    key: const ValueKey('back'),
                    color: theme.colorScheme.primaryContainer,
                    child: Center(
                      child: Icon(
                        Icons.style,
                        size: 32,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                : image != null
                    ? Stack(
                        key: const ValueKey('picture'),
                        fit: StackFit.expand,
                        children: [
                          Image.file(image, fit: BoxFit.cover),
                          if (card.foil)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(Icons.auto_awesome,
                                  size: 16, color: theme.colorScheme.tertiary),
                            ),
                        ],
                      )
                    : Padding(
                        key: const ValueKey('front'),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            if (card.foil)
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome,
                                      size: 14, color: theme.colorScheme.tertiary),
                                  const SizedBox(width: 4),
                                  Text(l10n.foil, style: theme.textTheme.labelSmall),
                                ],
                              ),
                            Text(
                              card.rarity.label(l10n),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: card.rarity.color),
                            ),
                            Text(card.id, style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
          ),
              if (dot)
                Positioned(
                  bottom: 5,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      key: const Key('rarityDot'),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: card.rarity.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }
}

/// Shows [image] large, next to the pointer, once it has hovered [child]
/// for a moment, until it leaves; nothing on touch screens, where there is
/// no hover.
class _HoverPreview extends StatefulWidget {
  const _HoverPreview({required this.enabled, required this.image, required this.ratio, required this.child});

  final bool enabled;
  final File? image;

  /// Width over height of the card, so the preview has no bars.
  final double ratio;
  final Widget child;

  /// How long the pointer rests on the card before the preview shows.
  static const delay = Duration(milliseconds: 450);

  /// The preview's width; the card's text reads at this size.
  static const width = 360.0;

  @override
  State<_HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<_HoverPreview> {
  Timer? _timer;
  OverlayEntry? _entry;
  Offset _pointer = Offset.zero;

  @override
  void didUpdateWidget(_HoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.image != oldWidget.image) _hide();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _enter(PointerEnterEvent event) {
    if (!widget.enabled) return;
    _pointer = event.position;
    _timer?.cancel();
    _timer = Timer(_HoverPreview.delay, _show);
  }

  void _move(PointerHoverEvent event) {
    _pointer = event.position;
    _entry?.markNeedsBuild();
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    // The card may go while the tree is being built (the last card of a
    // stack flying out under the pointer): the overlay is cleaned up
    // once the frame is done, not in the middle of it.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        entry.remove();
        entry.dispose();
      });
    } else {
      entry.remove();
      entry.dispose();
    }
  }

  void _show() {
    final image = widget.image;
    if (!mounted || image == null || _entry != null) return;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(builder: (context) {
      final size = MediaQuery.sizeOf(context);
      const width = _HoverPreview.width;
      final height = width / widget.ratio;
      // Beside the pointer, flipped to the left or clamped when short on room.
      var left = _pointer.dx + 24;
      if (left + width > size.width) left = _pointer.dx - 24 - width;
      final top = (_pointer.dy - height / 2).clamp(8.0, (size.height - height - 8).clamp(8.0, double.infinity));
      return Positioned(
        left: left.clamp(8.0, (size.width - width - 8).clamp(8.0, double.infinity)),
        top: top,
        child: IgnorePointer(
          child: Material(
            key: const Key('cardPreview'),
            elevation: 12,
            borderRadius: BorderRadius.circular(width / 22),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              height: height,
              child: Image.file(image, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    });
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: _enter,
        onHover: _move,
        onExit: (_) => _hide(),
        child: widget.child,
      );
}

/// A rarity-colored glow around a face-down card while the pointer hovers
/// or presses it: a hint of what is about to be revealed.
class _RarityGlow extends StatefulWidget {
  const _RarityGlow({required this.enabled, required this.color, required this.child});

  final bool enabled;
  final Color color;
  final Widget child;

  @override
  State<_RarityGlow> createState() => _RarityGlowState();
}

class _RarityGlowState extends State<_RarityGlow> {
  bool _hovered = false;

  // The exit callback also fires while this widget is being removed (the
  // pointer is still over it), in the middle of a frame when a rebuild is
  // not allowed: apply it after the frame, and only if still mounted.
  void _hover(bool hovered) {
    if (!mounted || hovered == _hovered) return;
    _hovered = hovered;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() {});
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowing = widget.enabled && _hovered;
    return MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: Listener(
        onPointerDown: (_) => _hover(true),
        onPointerUp: (_) => _hover(false),
        onPointerCancel: (_) => _hover(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: glowing
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.8), blurRadius: 18, spreadRadius: 3)]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Responsive grid of card tiles.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 63 / 88,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
