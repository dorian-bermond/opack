import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../card_info/data/card_info_repository.dart';
import '../../card_text/presentation/card_details_sheet.dart';
import '../data/pool_repository.dart';
import '../domain/play_pool.dart';
import '../domain/pool.dart';
import 'pool_loader.dart';
import 'pool_view.dart';
import 'pool_widgets.dart';

/// A mode of its own, like the tierlist, to set how many copies of each
/// card the pool holds: the preset, then card by card by tapping.
class CopiesScreen extends StatelessWidget {
  const CopiesScreen({super.key, required this.poolId});

  final String poolId;

  @override
  Widget build(BuildContext context) => PoolLoader(
        poolId: poolId,
        builder: (context, pool) => _Copies(play: pool),
      );
}

class _Copies extends ConsumerStatefulWidget {
  const _Copies({required this.play});

  final PlayPool play;

  @override
  ConsumerState<_Copies> createState() => _CopiesState();
}

class _CopiesState extends ConsumerState<_Copies> {
  String _query = '';

  Pool get _pool => widget.play.pool;

  void _save(Pool pool) => ref.read(poolsProvider.notifier).save(pool);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final play = widget.play;
    final pool = _pool;
    final config = pool.config;
    final language = dataLanguage(ref, context);
    final infos = ref.watch(poolCardInfoProvider(pool.id)).value?.infos ?? const {};
    final listed = {for (final e in play.entries) e.card.id: e.listed};
    final query = _query.trim().toLowerCase();
    final items = [
      for (final e in play.entries)
        if (query.isEmpty || shownName(ref, e.card, language).toLowerCase().contains(query) || e.card.id.toLowerCase().contains(query))
          (card: e.card, info: play.customizedInfo(e.card.id, infos[e.card.id]), tags: play.tagsOfCard(e.card.id)),
    ]..sort((a, b) => shownName(ref, a.card, language).compareTo(shownName(ref, b.card, language)));

    final actions = PoolCardActions(
      copiesOf: (card) => pool.copiesOf(card.id, listed: listed[card.id] ?? 1),
      listedOf: (card) => listed[card.id] ?? 1,
      changed: (card) => config.overrides.containsKey(card.id),
      setCopies: (card, copies) =>
          _save(pool.copyWith(config: config.withCard(card.id, copies, listed: listed[card.id] ?? 1))),
      tint: (_) => null,
      onTags: (_) {},
      tagsOf: (_) => const [],
      showCopies: true,
      // A tap asks the copies of the card.
      onTap: (card) async {
        final picked = await pickCopies(context, pool.copiesOf(card.id, listed: listed[card.id] ?? 1));
        if (picked != null) {
          _save(pool.copyWith(config: config.withCard(card.id, picked.copies, listed: listed[card.id] ?? 1)));
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.poolCopies),
        actions: [
          if (config.overrides.isNotEmpty)
            IconButton(
              key: const Key('resetCopies'),
              tooltip: l10n.resetCards,
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _save(pool.copyWith(config: config.withoutOverrides())),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PresetPicker(config: config, onChanged: (c) => _save(pool.copyWith(config: c))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('${play.summary(l10n)} · ${l10n.copiesHint}', style: theme.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: l10n.searchCards,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [PoolGallerySliver(items: items, actions: actions)],
            ),
          ),
        ],
      ),
    );
  }
}
