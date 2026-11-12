import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../features/card_text/presentation/card_details_sheet.dart';
import '../../features/catalog/domain/models.dart';
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
    void details() => showCardDetails(context, card);
    final source = cardImageSource(card, language: pictureLanguage(ref, context));
    final image = revealed && source != null ? ref.watch(cardImageProvider(source)).value : null;

    return AspectRatio(
      aspectRatio: 63 / 88,
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
    );
  }
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
