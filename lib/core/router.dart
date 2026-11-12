import 'package:go_router/go_router.dart';

import '../features/catalog/domain/models.dart';
import '../features/catalog/presentation/home_screen.dart';
import '../features/cube/presentation/cube_list.dart';
import '../features/draft/presentation/draft_screen.dart';
import '../features/packs/presentation/pack_opening_screen.dart';
import '../features/pools/presentation/pool_composition_screen.dart';
import '../features/pools/presentation/pool_editor_screen.dart';
import '../features/pools/presentation/pool_formats_screen.dart';
import '../features/pools/presentation/pools_screen.dart';
import '../features/sealed/presentation/sealed_screen.dart';

/// `/game/<game>`: the pools of a game, the app's main screen.
String gamePath(Game game) => '/game/${game.name}';

/// `/game/<game>/cubes`: the imported cubes, to manage them.
String cubesPath(Game game) => '${gamePath(game)}/cubes';

/// `/game/<game>/pool/<id>/<mode>`, mode being `open`, `sealed`, `draft`
/// or `edit`.
String poolModePath(Game game, String poolId, String mode) =>
    '${gamePath(game)}/pool/${Uri.encodeComponent(poolId)}/$mode';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'game/:game',
          builder: (context, state) => PoolsScreen(game: _game(state)),
          routes: [
            GoRoute(
              path: 'cubes',
              builder: (context, state) => CubesScreen(game: _game(state)),
            ),
            GoRoute(
              path: 'pool/:pool/open',
              builder: (context, state) =>
                  PackOpeningScreen(game: _game(state), poolId: _pool(state)),
            ),
            GoRoute(
              path: 'pool/:pool/sealed',
              builder: (context, state) => SealedScreen(
                  game: _game(state), poolId: _pool(state), formatId: state.uri.queryParameters['format']),
            ),
            GoRoute(
              path: 'pool/:pool/draft',
              builder: (context, state) => DraftScreen(
                  game: _game(state), poolId: _pool(state), formatId: state.uri.queryParameters['format']),
            ),
            GoRoute(
              path: 'pool/:pool/formats',
              builder: (context, state) => PoolFormatsScreen(poolId: _pool(state)),
            ),
            GoRoute(
              path: 'pool/:pool/edit',
              builder: (context, state) => PoolEditorScreen(poolId: _pool(state)),
            ),
            GoRoute(
              path: 'pool/:pool/composition',
              builder: (context, state) => PoolCompositionScreen(poolId: _pool(state)),
            ),
          ],
        ),
      ],
    ),
  ],
);

Game _game(GoRouterState state) => Game.values.byName(state.pathParameters['game']!);

String _pool(GoRouterState state) => state.pathParameters['pool']!;
