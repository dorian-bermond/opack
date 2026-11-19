import 'package:flutter/material.dart';
import '../../../shared/widgets/set_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../cube/data/cube_repository.dart';
import '../domain/pool.dart';

/// Lets the user pick a set or a cube of [game] not in [exclude]; [sets]
/// and [cubes] narrow the choice to one kind.
Future<PoolSource?> pickPoolSource(
  BuildContext context, {
  required Game game,
  Iterable<PoolSource> exclude = const [],
  bool sets = true,
  bool cubes = true,
}) =>
    showDialog<PoolSource>(
      context: context,
      builder: (context) =>
          _SourcePicker(game: game, exclude: exclude.toSet(), sets: sets, cubes: cubes),
    );

/// Display name of [source]: the set or cube name, or its id once deleted.
String sourceName(WidgetRef ref, Game game, PoolSource source, String language) =>
    switch (source) {
      SetSource(:final code) => ref
              .read(catalogRepositoryProvider)
              .setsFor(game)
              .where((s) => s.code == code)
              .map((s) => '${s.nameFor(language)} (${s.displayCode})')
              .firstOrNull ??
          code,
      CubeSource(:final id) =>
        ref.watch(cubesProvider).value?.where((c) => c.id == id).firstOrNull?.name ?? id,
      CardsSource(:final cards) => AppLocalizations.of(ref.context).pickedCards(cards.length),
    };

class _SourcePicker extends ConsumerStatefulWidget {
  const _SourcePicker({
    required this.game,
    required this.exclude,
    required this.sets,
    required this.cubes,
  });

  final Game game;
  final Set<PoolSource> exclude;
  final bool sets;
  final bool cubes;

  @override
  ConsumerState<_SourcePicker> createState() => _SourcePickerState();
}

class _SourcePickerState extends ConsumerState<_SourcePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final query = _query.trim().toLowerCase();
    bool matches(String text) => query.isEmpty || text.toLowerCase().contains(query);

    final cubes = [
      for (final cube in ref.watch(cubesProvider).value ?? const [])
        if (widget.cubes &&
            cube.game == widget.game &&
            !widget.exclude.contains(CubeSource(cube.id)) &&
            matches(cube.name))
          cube,
    ];
    final sets = [
      for (final set in ref.watch(catalogRepositoryProvider).setsFor(widget.game))
        if (widget.sets &&
            !widget.exclude.contains(SetSource(set.code)) &&
            (matches(set.code) || set.names.values.any(matches)))
          set,
    ];

    return AlertDialog(
      title: Text(l10n.addSource),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchBar(
                autoFocus: true,
                leading: const Icon(Icons.search),
                hintText: l10n.searchSets,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final cube in cubes)
                    ListTile(
                      leading: const Icon(Icons.view_module),
                      title: Text(cube.name),
                      subtitle: Text('${l10n.tabCubes} · ${l10n.cardsCount(cube.cards.length)}'),
                      onTap: () => Navigator.pop(context, CubeSource(cube.id)),
                    ),
                  for (final set in sets)
                    ListTile(
                      leading: SetSymbol(set, code: set.code, size: 28),
                      title: Text('${set.nameFor(language)} (${set.displayCode})'),
                      subtitle: Text(l10n.cardsCount(set.cardCount)),
                      onTap: () => Navigator.pop(context, SetSource(set.code)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
      ],
    );
  }
}
