import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../catalog/domain/models.dart';
import '../domain/card_filter.dart';
import '../domain/pool_metrics.dart';
import 'labels.dart';

/// Shows every metric of [items] (the cards currently listed), one section
/// per breakdown with a bar per row.
Future<void> showMetricsSheet(
  BuildContext context, {
  required Game game,
  required List<CardWithInfo> items,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, controller) =>
            MetricsView(sections: poolMetrics(game, items), controller: controller),
      ),
    );

class MetricsView extends StatelessWidget {
  const MetricsView({super.key, required this.sections, this.controller});

  final List<MetricSection> sections;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String number(num value) => value is int || value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(2);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(l10n.poolStats, style: theme.textTheme.titleLarge),
        if (sections.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 16), child: Text(l10n.noCardText)),
        for (final section in sections) ...[
          const SizedBox(height: 16),
          Text(metricLabel(l10n, section.metric), style: theme.textTheme.titleSmall),
          if (section.average != null || section.max != null || section.known != null)
            Text(
              [
                if (section.average case final avg?) l10n.averageValue(number(avg)),
                if (section.max case final max?) l10n.highestValue(number(max)),
                if (section.known case final known?) l10n.knownOf(known),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
          _Bars(rows: section.rows, labels: (v) => valueLabel(l10n, v)),
        ],
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.rows, required this.labels});

  final List<(String, int)> rows;
  final String Function(String) labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = rows.fold(0, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      children: [
        for (final (label, count) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(labels(label), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: top == 0 ? 0 : count / top,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$count', textAlign: TextAlign.end, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
