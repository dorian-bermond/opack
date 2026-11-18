import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../card_info/presentation/labels.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_loader.dart';

/// The booster composition of a pool: its slots with their weighted
/// options, and a way to prefill them again from a set's booster or as
/// random packs.
class PoolCompositionScreen extends StatelessWidget {
  const PoolCompositionScreen({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _Composition(play: pool),
      );
}

/// `X 1/4 · Y 3/4`, the options of a slot with their chances.
/// A slot as the user reads it: its name when it has one, else its options.
String slotLabel(AppLocalizations l10n, PackSlot slot) => slot.name ?? slotOptionsLabel(l10n, slot);

String slotOptionsLabel(AppLocalizations l10n, PackSlot slot) => [
      for (final option in slot.options)
        slot.options.length == 1
            ? tagLabel(l10n, option.tag)
            : '${tagLabel(l10n, option.tag)} ${option.weight}/${slot.totalWeight}',
    ].join(' · ');

class _Composition extends ConsumerStatefulWidget {
  const _Composition({required this.play});

  final PlayPool play;

  @override
  ConsumerState<_Composition> createState() => _CompositionState();
}

class _CompositionState extends ConsumerState<_Composition> {
  static const packSizes = [5, 8, 9, 10, 11, 12, 14, 15, 16, 18, 20];

  /// The booster being edited (the first one at start).
  String? _selected;

  PlayPool get play => widget.play;

  BoosterDef get _booster =>
      play.pool.booster(_selected ?? '') ?? BoosterDef(BoosterDef.defaultName, const []);

  Future<String?> _askName(String title) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.boosterName),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(l10n.apply)),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _prefill(BuildContext context, WidgetRef ref, PackLayout layout) async {
    final l10n = AppLocalizations.of(context);
    final pool = play.pool;
    final prefill = switch (layout) {
      BoosterLayout(:final setCode, :final booster) => withCardsByRarity(
          prefillFromSet(play.sets[setCode]!, booster: booster),
          play.entries.map((e) => e.card),
        ),
      RandomLayout(:final packSize) =>
        prefillRandom(play.entries.map((e) => e.card), packSize: packSize),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.prefillTitle),
        content: Text(l10n.prefillWarning(prefill.slots.length, prefill.tags.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.apply)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(poolsProvider.notifier).save(pool.prefilled(prefill, layout: layout));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pool = play.pool;
    final booster = _booster;
    void save(Pool updated) => ref.read(poolsProvider.notifier).save(updated);
    void saveSlots(List<PackSlot> slots) => save(pool.withBooster(booster.copyWith(slots: slots)));
    final prefills = <PackLayout>[
      for (final source in pool.sources.whereType<SetSource>())
        if (play.sets[source.code] case final set?)
          for (final type in set.boosters.keys) BoosterLayout(set.code, booster: type),
      for (final size in packSizes) RandomLayout(size),
    ];
    String prefillLabel(PackLayout layout) => switch (layout) {
          BoosterLayout(:final setCode, :final booster) =>
            '${play.sets[setCode]?.displayCode ?? setCode} · ${booster?.label(l10n) ?? ''}',
          RandomLayout(:final packSize) => '${l10n.randomPacks} · ${l10n.cardsCount(packSize)}',
        };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.boosterComposition)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addSlot),
        onPressed: () async {
          final slot = await editSlot(context, play, null);
          if (slot != null) saveSlots([...booster.slots, slot]);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(pool.name, style: theme.textTheme.titleMedium),
          if (play.unplaced > 0) Text(l10n.cardsUnplaced(play.unplaced), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('bestVersions'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.bestVersions),
            subtitle: Text(l10n.bestVersionsHint),
            value: pool.bestVersions,
            onChanged: (on) => save(pool.withBestVersions(on)),
          ),
          const SizedBox(height: 12),
          Text(l10n.boosterKinds, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in pool.boosters)
                InputChip(
                  label: Text('${kind.name} · ${l10n.cardsCount(play.boosterPlay(kind.name)?.packSize ?? 0)}'),
                  selected: kind.name == booster.name,
                  onSelected: (_) => setState(() => _selected = kind.name),
                  deleteButtonTooltipMessage: l10n.deleteBooster,
                  onDeleted: pool.boosters.length > 1
                      ? () {
                          save(pool.withoutBooster(kind.name));
                          if (_selected == kind.name) setState(() => _selected = null);
                        }
                      : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l10n.newBooster),
                onPressed: () async {
                  final name = await _askName(l10n.newBooster);
                  if (name == null || pool.boosters.any((b) => b.name == name)) return;
                  save(pool.withBooster(BoosterDef(name, const [])));
                  setState(() => _selected = name);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${booster.name} · ${l10n.cardsCount(play.boosterPlay(booster.name)?.packSize ?? 0)}',
              style: theme.textTheme.titleSmall),
          if (booster.slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.noUserSlots, style: theme.textTheme.bodySmall),
            ),
          for (final (i, slot) in booster.slots.indexed)
            Card(
              child: ListTile(
                title: Text(l10n.slotRow(slot.count, slotLabel(l10n, slot))),
                subtitle: Text([
                  if (slot.name != null) slotOptionsLabel(l10n, slot),
                  for (final option in slot.options)
                    '${tagLabel(l10n, option.tag)}: ${l10n.slotCards(play.tagCards[option.tag]?.length ?? 0)}',
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.editSlot,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final edited = await editSlot(context, play, slot);
                        if (edited != null) saveSlots([...booster.slots]..[i] = edited);
                      },
                    ),
                    IconButton(
                      tooltip: l10n.deleteSlot,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => saveSlots([...booster.slots]..removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(l10n.prefillFrom, style: theme.textTheme.labelLarge),
          Text(l10n.prefillHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final layout in prefills)
                ActionChip(
                  avatar: Icon(layout is BoosterLayout ? Icons.style : Icons.shuffle, size: 18),
                  label: Text(prefillLabel(layout)),
                  onPressed: () => _prefill(context, ref, layout),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Edits [slot] (or a new one): the cards per pack and the weighted options.
/// `null` when cancelled or without a tag to pull from.
Future<PackSlot?> editSlot(BuildContext context, PlayPool play, PackSlot? slot) {
  final tags = play.tagNames;
  if (tags.isEmpty) return Future.value(null);
  return showDialog<PackSlot>(
    context: context,
    builder: (context) => _SlotDialog(play: play, tags: tags, initial: slot),
  );
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.play, required this.tags, this.initial});

  final PlayPool play;
  final List<String> tags;
  final PackSlot? initial;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  late int _count = widget.initial?.count ?? 1;
  late List<SlotOption> _options = [...?widget.initial?.options];
  late final _name = TextEditingController(text: widget.initial?.name ?? '');

  @override
  void initState() {
    super.initState();
    if (_options.isEmpty) _options = [SlotOption(widget.tags.first)];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = _options.fold(0, (sum, o) => sum + o.weight);
    Widget stepper(int value, int min, int max, ValueChanged<int> onChanged) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: value > min ? () => onChanged(value - 1) : null),
            Text('$value', style: theme.textTheme.titleMedium),
            IconButton(icon: const Icon(Icons.add), onPressed: value < max ? () => onChanged(value + 1) : null),
          ],
        );

    return AlertDialog(
      title: Text(widget.initial == null ? l10n.addSlot : l10n.editSlot),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('slotName'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.slotName, isDense: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(l10n.slotCount, style: theme.textTheme.labelLarge)),
                  stepper(_count, 1, 15, (v) => setState(() => _count = v)),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.slotOptions, style: theme.textTheme.labelLarge),
              for (final (i, option) in _options.indexed)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: widget.tags.contains(option.tag) ? option.tag : widget.tags.first,
                        isExpanded: true,
                        onChanged: (tag) => setState(() => _options[i] = SlotOption(tag!, option.weight)),
                        items: [
                          for (final tag in widget.tags)
                            DropdownMenuItem(
                              value: tag,
                              child: Text(
                                '${tagLabel(l10n, tag)} · ${l10n.slotCards(widget.play.tagCards[tag]?.length ?? 0)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    stepper(option.weight, 1, 99, (v) => setState(() => _options[i] = SlotOption(option.tag, v))),
                    SizedBox(
                      width: 44,
                      child: Text('${option.weight}/$total', style: theme.textTheme.labelMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _options.length > 1 ? () => setState(() => _options.removeAt(i)) : null,
                    ),
                  ],
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addOption),
                onPressed: () => setState(() => _options.add(SlotOption(widget.tags.first))),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, PackSlot(_count, _options, name: _name.text.trim().isEmpty ? null : _name.text.trim())),
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}
