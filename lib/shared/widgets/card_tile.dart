import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/card_text/presentation/card_details_sheet.dart';
import '../../features/catalog/domain/models.dart';
import '../../features/pools/presentation/pool_loader.dart';
import '../../l10n/app_localizations.dart';
import '../images/card_image_cache.dart';

extension RarityPresentation on Rarity {
  String label(AppLocalizations l10n) => switch (this) {
        Rarity.common => l10n.rarityCommon,
        Rarity.uncommon => l10n.rarityUncommon,
        Rarity.rare => l10n.rarityRare,
        Rarity.mythic => l10n.rarityMythic,
        Rarity.superRare => l10n.raritySuperRare,
        Rarity.ultraRare => l10n.rarityUltraRare,
        Rarity.special => l10n.raritySpecial,
        Rarity.secretRare => l10n.raritySecretRare,
      };

  Color get color => switch (this) {
        Rarity.common => Colors.blueGrey,
        Rarity.uncommon => Colors.teal,
        Rarity.rare => Colors.amber.shade700,
        Rarity.superRare => Colors.lightBlue,
        Rarity.ultraRare => Colors.purple,
        Rarity.mythic => Colors.deepOrange,
        Rarity.special => Colors.indigo,
        Rarity.secretRare => Colors.pink,
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

/// Width over height of a card: Yu-Gi-Oh! cards are 59 × 86 mm, MtG ones
/// 63 × 88 mm.
double cardAspectRatio(CardData card) => card.passcode != null ? 59 / 86 : 63 / 88;

/// A card face (its picture once downloaded, else name and rarity), or its
/// back while [revealed] is false. Long-press or right-click a revealed card
/// for its text and text versions.
class CardTile extends ConsumerWidget {
  const CardTile({
    super.key,
    required this.card,
    this.revealed = true,
    this.onTap,
  });

  final CardData card;
  final bool revealed;
  final VoidCallback? onTap;

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
            color: revealed ? card.rarity.color : theme.colorScheme.outline,
            width: 3,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: revealed ? details : null,
          onSecondaryTap: revealed ? details : null,
          child: AnimatedSwitcher(
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
    _entry?.remove();
    _entry = null;
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
