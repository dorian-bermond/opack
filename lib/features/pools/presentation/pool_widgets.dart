import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/play_pool.dart';
import '../domain/pool_config.dart';

/// Preset buttons for a pool's copy counts. Applying a preset over
/// single-card changes asks first, since it drops them.
class PresetPicker extends StatelessWidget {
  const PresetPicker({super.key, required this.config, required this.onChanged});

  static const maxCopies = 8;

  final PoolConfig config;
  final ValueChanged<PoolConfig> onChanged;

  Future<void> _apply(BuildContext context, PoolConfig preset) async {
    if (config.overrides.isNotEmpty) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.presetDropsChanges(config.overrides.length)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.apply)),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    onChanged(preset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preset = config.preset;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<PoolPreset?>(
          showSelectedIcon: false,
          segments: [
            for (final p in PoolPreset.values)
              ButtonSegment(
                value: p,
                icon: Icon(p.icon),
                label: Text(p.label(l10n)),
                tooltip: p.description(l10n),
              ),
            if (preset == null)
              ButtonSegment(value: null, icon: const Icon(Icons.tune), label: Text(l10n.poolCustom)),
          ],
          selected: {preset},
          onSelectionChanged: (selection) => switch (selection.single) {
            PoolPreset.open => _apply(context, const PoolConfig.open()),
            PoolPreset.closed => _apply(context, PoolConfig.closed(config.copies ?? 1)),
            null => null,
          },
        ),
        if (config.copies case final copies?)
          DropdownButton<int>(
            value: copies,
            onChanged: (value) => onChanged(config.withCopies(value)),
            items: [
              for (var n = 1; n <= maxCopies; n++)
                DropdownMenuItem(value: n, child: Text(l10n.copiesPerCard(n))),
            ],
          ),
      ],
    );
  }
}

extension PoolPresetPresentation on PoolPreset {
  String label(AppLocalizations l10n) => switch (this) {
        PoolPreset.open => l10n.poolOpen,
        PoolPreset.closed => l10n.poolClosed,
      };

  String description(AppLocalizations l10n) => switch (this) {
        PoolPreset.open => l10n.poolOpenDescription,
        PoolPreset.closed => l10n.poolClosedDescription,
      };

  IconData get icon => switch (this) {
        PoolPreset.open => Icons.all_inclusive,
        PoolPreset.closed => Icons.lock_outline,
      };
}

extension PoolConfigPresentation on PoolConfig {
  /// "Open", "Closed ×2" or "Custom".
  String label(AppLocalizations l10n) => switch (preset) {
        PoolPreset.open => l10n.poolOpen,
        PoolPreset.closed => '${l10n.poolClosed} ×$copies',
        null => l10n.poolCustom,
      };
}

extension PlayPoolPresentation on PlayPool {
  /// "12 packs of 15 cards available · 3 cards changed · 4 cards fit no slot".
  String summary(AppLocalizations l10n) => [
        packCount == null ? l10n.packsUnlimited : l10n.packsAvailable(packCount!, packSize),
        if (config.overrides.isNotEmpty) l10n.cardsChanged(config.overrides.length),
        if (unplaced > 0) l10n.cardsUnplaced(unplaced),
      ].join(' · ');
}

/// Short label for a copy count: `∞` when unlimited.
String copiesLabel(int? copies) => copies == null ? '∞' : '$copies';

/// The copy counts offered for a card: unlimited, 0 to the preset maximum,
/// and [current] when it lies beyond.
List<int?> copiesOptions(int? current) => [
      null,
      for (var n = 0; n <= PresetPicker.maxCopies; n++) n,
      if (current case final v? when v > PresetPicker.maxCopies) v,
    ];

/// Picks how many copies of a card the pool holds.
class CopiesDropdown extends StatelessWidget {
  const CopiesDropdown({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButton<int?>(
      value: value,
      onChanged: onChanged,
      items: [
        for (final n in copiesOptions(value))
          DropdownMenuItem(
            value: n,
            child: Tooltip(
              message: n == null ? l10n.unlimitedCopies : l10n.copiesCount(n),
              child: Text(copiesLabel(n)),
            ),
          ),
      ],
    );
  }
}
