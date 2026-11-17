import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/settings_menu.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/models.dart';
import '../../catalog/presentation/home_screen.dart';
import '../../../shared/widgets/game_icon.dart';
import '../../pools/domain/pool.dart';
import '../../pools/presentation/pool_list.dart';
import '../data/cube_repository.dart';
import '../domain/cube.dart';

/// The cubes of every game, one tab each: import, delete, start a pool
/// from one.
class CubesScreen extends StatelessWidget {
  const CubesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: Game.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabCubes),
          actions: const [SettingsMenu()],
          bottom: TabBar(
            tabs: [for (final game in Game.values) Tab(icon: GameIcon(game, size: 22), text: game.label(l10n))],
          ),
        ),
        body: TabBarView(
          children: [for (final game in Game.values) CubeList(game: game)],
        ),
      ),
    );
  }
}

/// The imported cubes of one game, with the import action.
class CubeList extends ConsumerStatefulWidget {
  const CubeList({super.key, required this.game});

  final Game game;

  @override
  ConsumerState<CubeList> createState() => _CubeListState();
}

class _CubeListState extends ConsumerState<CubeList> {
  bool _importing = false;

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final result = switch (widget.game) {
        Game.mtg => await _importFromCubeCobra(),
        Game.ygo => await _importFromFile(),
        Game.opc => await _importOpcFile(),
      };
      if (result == null) return;
      await ref.read(cubesProvider.notifier).add(result.cube);
      messenger.showSnackBar(SnackBar(
        content: Text([
          l10n.cubeImported(result.cube.name, result.cube.cards.length),
          if (result.unresolved.isNotEmpty)
            l10n.unresolvedCards(result.unresolved.length, result.unresolved.take(5).join(', ')),
        ].join('\n')),
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed('$error'))));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<({Cube cube, List<String> unresolved})?> _importFromCubeCobra() async {
    final id = await showDialog<String>(
      context: context,
      builder: (context) => const _CubeCobraDialog(),
    );
    if (id == null || id.trim().isEmpty) return null;
    final cube = await importCubeCobra(id, ref.read(catalogRepositoryProvider));
    return (cube: cube, unresolved: const <String>[]);
  }

  Future<({Cube cube, List<String> unresolved})?> _importFromFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['ydk', 'txt'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return importYgoList(
      name: file.name.replaceFirst(RegExp(r'\.(ydk|txt)$', caseSensitive: false), ''),
      fileName: file.name,
      text: utf8.decode(bytes, allowMalformed: true),
      bundle: rootBundle,
    );
  }

  Future<({Cube cube, List<String> unresolved})?> _importOpcFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['txt']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return importOpcList(
      name: file.name.replaceFirst(RegExp(r'\.txt$', caseSensitive: false), ''),
      fileName: file.name,
      text: utf8.decode(bytes, allowMalformed: true),
      catalog: ref.read(catalogRepositoryProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubes = ref.watch(cubesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(widget.game == Game.mtg ? Icons.cloud_download : Icons.upload_file),
        label: Text(widget.game == Game.mtg ? l10n.importCubeCobra : l10n.importCubeFile),
      ),
      body: cubes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (all) {
          final mine = all.where((c) => c.game == widget.game).toList();
          if (mine.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  switch (widget.game) {
                    Game.mtg => l10n.noCubesMtg,
                    Game.ygo => l10n.noCubesYgo,
                    Game.opc => l10n.noCubesOpc,
                  },
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: mine.length,
            itemBuilder: (context, i) => _CubeTile(cube: mine[i]),
          );
        },
      ),
    );
  }
}

class _CubeTile extends ConsumerWidget {
  const _CubeTile({required this.cube});

  final Cube cube;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(cube.name, style: theme.textTheme.titleMedium)),
                IconButton(
                  tooltip: l10n.deleteCube,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(cubesProvider.notifier).remove(cube.id),
                ),
              ],
            ),
            Text('${cube.source} · ${l10n.cardsCount(cube.cards.length)}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.createPool),
                  onPressed: () => createPool(context, ref, cube.game, CubeSource(cube.id)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CubeCobraDialog extends StatefulWidget {
  const _CubeCobraDialog();

  @override
  State<_CubeCobraDialog> createState() => _CubeCobraDialogState();
}

class _CubeCobraDialogState extends State<_CubeCobraDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void submit() => Navigator.pop(context, _controller.text);
    return AlertDialog(
      title: Text(l10n.importCubeCobra),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.cubeCobraIdLabel,
          hintText: 'vintage',
        ),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: submit, child: Text(l10n.import)),
      ],
    );
  }
}
