import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../catalog/domain/models.dart';
import '../domain/card_filter.dart';
import 'labels.dart';

/// Lets the user narrow [items] by facet values and number ranges; every
/// change is reported through [onChanged] at once.
Future<void> showFilterSheet(
  BuildContext context, {
  required Game game,
  required List<CardWithInfo> items,
  required CardFilter filter,
  required ValueChanged<CardFilter> onChanged,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => _FilterSheet(
          game: game,
          items: items,
          filter: filter,
          onChanged: onChanged,
          controller: controller,
        ),
      ),
    );

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.game,
    required this.items,
    required this.filter,
    required this.onChanged,
    required this.controller,
  });

  final Game game;
  final List<CardWithInfo> items;
  final CardFilter filter;
  final ValueChanged<CardFilter> onChanged;
  final ScrollController controller;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late CardFilter _filter = widget.filter;

  /// At most this many values per facet, the most frequent first.
  static const _maxValues = 30;

  void _update(CardFilter filter) {
    setState(() => _filter = filter);
    widget.onChanged(filter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final facets = Facet.forGame(widget.game);

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.filters, style: theme.textTheme.titleLarge)),
            TextButton(
              onPressed: _filter.isEmpty ? null : () => _update(const CardFilter()),
              child: Text(l10n.clearFilters),
            ),
          ],
        ),
        for (final facet in facets)
          if (facet.numeric)
            ..._range(facet, l10n, theme)
          else
            ..._chips(facet, l10n, theme),
      ],
    );
  }

  List<Widget> _chips(Facet facet, AppLocalizations l10n, ThemeData theme) {
    final counts = <String, int>{};
    for (final item in widget.items) {
      for (final value in facet.valuesOf(item)) {
        counts.update(value, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final chosen = _filter.chosen[facet] ?? const {};
    if (counts.isEmpty && chosen.isEmpty) return const [];
    final values = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    final shown = {...values.take(_maxValues), ...chosen}.toList();
    return [
      const SizedBox(height: 12),
      Text(facetLabel(l10n, facet), style: theme.textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in shown)
            FilterChip(
              label: Text('${valueLabel(l10n, value, game: widget.game)} · ${counts[value] ?? 0}'),
              selected: chosen.contains(value),
              onSelected: (_) => _update(_filter.toggle(facet, value)),
            ),
        ],
      ),
    ];
  }

  List<Widget> _range(Facet facet, AppLocalizations l10n, ThemeData theme) {
    final numbers = [for (final item in widget.items) ?facet.numberOf(item)];
    if (numbers.isEmpty) return const [];
    final low = numbers.reduce((a, b) => a < b ? a : b).floor();
    final high = numbers.reduce((a, b) => a > b ? a : b).ceil();
    if (low == high) return const [];
    final step = facet == Facet.atk || facet == Facet.def ? 100 : 1;
    final (min, max) = _filter.ranges[facet] ?? (low, high);
    final values = RangeValues(
      min.clamp(low, high).toDouble(),
      max.clamp(low, high).toDouble(),
    );
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Text(facetLabel(l10n, facet), style: theme.textTheme.labelLarge)),
          Text('${values.start.round()} – ${values.end.round()}', style: theme.textTheme.labelLarge),
        ],
      ),
      RangeSlider(
        values: values,
        min: low.toDouble(),
        max: high.toDouble(),
        divisions: ((high - low) / step).ceil().clamp(1, 200),
        onChanged: (range) => _update(_filter.withRange(
          facet,
          range.start.round() == low && range.end.round() == high
              ? null
              : (range.start.round(), range.end.round()),
        )),
      ),
    ];
  }
}
