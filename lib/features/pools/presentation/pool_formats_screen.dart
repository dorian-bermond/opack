import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_loader.dart';

/// The formats of a pool: which boosters in which order, opened at once or
/// drafted with picks and burns per pass.
class PoolFormatsScreen extends StatelessWidget {
  const PoolFormatsScreen({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _Formats(play: pool),
      );
}

String formatKindLabel(AppLocalizations l10n, FormatKind kind) => switch (kind) {
      FormatKind.sealed => l10n.modeSealed,
      FormatKind.draft => l10n.modeDraft,
    };

class _Formats extends ConsumerWidget {
  const _Formats({required this.play});

  final PlayPool play;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pool = play.pool;
    void save(Pool updated) => ref.read(poolsProvider.notifier).save(updated);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.formats)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newFormat),
        onPressed: () async {
          final format = await editFormat(
            context,
            play,
            PlayFormat(
              id: 'format-${DateTime.now().microsecondsSinceEpoch}',
              name: l10n.newFormat,
              kind: FormatKind.sealed,
              rounds: [FormatRound(pool.boosters.firstOrNull?.name ?? BoosterDef.defaultName)],
            ),
          );
          if (format != null) save(pool.withFormat(format));
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(pool.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final format in pool.playFormats)
            Card(
              child: ListTile(
                title: Text(format.name),
                subtitle: Text([
                  l10n.formatSummary(formatKindLabel(l10n, format.kind), format.rounds.length),
                  if (format.kind == FormatKind.draft) '${l10n.seats}: ${format.seats}',
                  format.rounds.map((r) => r.booster).toSet().join(', '),
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.editSlot,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final edited = await editFormat(context, play, format);
                        if (edited != null) save(pool.withFormat(edited));
                      },
                    ),
                    IconButton(
                      tooltip: l10n.deleteFormat,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: pool.playFormats.length > 1 ? () => save(pool.withoutFormat(format.id)) : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Edits [format]; `null` when cancelled.
Future<PlayFormat?> editFormat(BuildContext context, PlayPool play, PlayFormat format) =>
    showDialog<PlayFormat>(
      context: context,
      builder: (context) => _FormatDialog(play: play, initial: format),
    );

class _FormatDialog extends StatefulWidget {
  const _FormatDialog({required this.play, required this.initial});

  final PlayPool play;
  final PlayFormat initial;

  @override
  State<_FormatDialog> createState() => _FormatDialogState();
}

class _FormatDialogState extends State<_FormatDialog> {
  late final _name = TextEditingController(text: widget.initial.name);
  late FormatKind _kind = widget.initial.kind;
  late int _seats = widget.initial.seats;
  late final List<FormatRound> _rounds = [...widget.initial.rounds];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final boosters = widget.play.pool.boosters.map((b) => b.name).toList();
    Widget stepper(int value, int min, int max, ValueChanged<int> onChanged) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: value > min ? () => onChanged(value - 1) : null),
            Text('$value', style: theme.textTheme.titleMedium),
            IconButton(icon: const Icon(Icons.add), onPressed: value < max ? () => onChanged(value + 1) : null),
          ],
        );

    return AlertDialog(
      title: Text(widget.initial.name),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: l10n.formatName)),
              const SizedBox(height: 12),
              Text(l10n.formatKind, style: theme.textTheme.labelLarge),
              SegmentedButton<FormatKind>(
                segments: [
                  for (final kind in FormatKind.values)
                    ButtonSegment(value: kind, label: Text(formatKindLabel(l10n, kind))),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.single),
              ),
              if (_kind == FormatKind.draft)
                Row(
                  children: [
                    Expanded(child: Text(l10n.seats, style: theme.textTheme.labelLarge)),
                    stepper(_seats, 2, 8, (v) => setState(() => _seats = v)),
                  ],
                ),
              const SizedBox(height: 12),
              Text(l10n.rounds, style: theme.textTheme.labelLarge),
              for (final (i, round) in _rounds.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 90, child: Text(l10n.roundNumber(i + 1), style: theme.textTheme.labelMedium)),
                          Expanded(
                            child: DropdownButton<String>(
                              value: boosters.contains(round.booster) ? round.booster : boosters.firstOrNull,
                              isExpanded: true,
                              onChanged: (b) => setState(() => _rounds[i] = round.copyWith(booster: b)),
                              items: [for (final b in boosters) DropdownMenuItem(value: b, child: Text(b))],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: i > 0 ? () => setState(() => _rounds.insert(i - 1, _rounds.removeAt(i))) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _rounds.length > 1 ? () => setState(() => _rounds.removeAt(i)) : null,
                          ),
                        ],
                      ),
                      if (_kind == FormatKind.draft)
                        Row(
                          children: [
                            Expanded(child: Text(l10n.picksPerPass, style: theme.textTheme.bodySmall)),
                            stepper(round.picks, 1, 5, (v) => setState(() => _rounds[i] = round.copyWith(picks: v))),
                            Expanded(child: Text(l10n.burnPerPass, style: theme.textTheme.bodySmall)),
                            stepper(round.burn, 0, 5, (v) => setState(() => _rounds[i] = round.copyWith(burn: v))),
                          ],
                        ),
                    ],
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addRound),
                onPressed: boosters.isEmpty
                    ? null
                    : () => setState(() => _rounds.add(FormatRound(_rounds.lastOrNull?.booster ?? boosters.first))),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.initial.copyWith(
              name: _name.text.trim().isEmpty ? widget.initial.name : _name.text.trim(),
              kind: _kind,
              seats: _seats,
              rounds: _rounds,
            ),
          ),
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}
