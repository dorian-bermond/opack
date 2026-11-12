import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/data/catalog_repository.dart';
import '../../features/catalog/domain/models.dart';

/// Loads a bundled set, then builds [builder] with it.
class SetLoader extends ConsumerWidget {
  const SetLoader({
    super.key,
    required this.game,
    required this.setCode,
    required this.builder,
  });

  final Game game;
  final String setCode;
  final Widget Function(BuildContext context, CardSet set) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(cardSetProvider((game, setCode))).when(
          data: (set) => builder(context, set),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('$error')),
          ),
        );
  }
}
