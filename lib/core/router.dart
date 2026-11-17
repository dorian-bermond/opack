import 'package:go_router/go_router.dart';

import '../features/catalog/domain/models.dart';
import '../features/cube/presentation/cube_list.dart';
import '../features/draft/presentation/draft_screen.dart';
import '../features/packs/presentation/pack_opening_screen.dart';
import '../features/pools/presentation/pool_composition_screen.dart';
import '../features/pools/presentation/pool_details_screen.dart';
import '../features/pools/presentation/pool_editor_screen.dart';
import '../features/pools/presentation/pool_formats_screen.dart';
import '../features/pools/presentation/pools_screen.dart';
import '../features/pools/presentation/tierlist_screen.dart';
import '../shared/widgets/settings_screen.dart';
import '../features/sealed/presentation/sealed_screen.dart';

/// `/`: every pool of every game, the app's main screen.
const poolsPath = '/';

/// `/cubes`: the imported cubes of every game, to manage them.
const cubesPath = '/cubes';

/// `/settings`: the settings page.
const settingsPath = '/settings';

/// `/game/<game>/pool/<id>/<mode>`, mode being `open`, `sealed`, `draft`,
/// `edit` or `details`. The game segment keeps pool ids unique per game.
String poolModePath(Game game, String poolId, String mode) =>
    '/game/${game.name}/pool/${Uri.encodeComponent(poolId)}/$mode';

final router = GoRouter(
  routes: [
    GoRoute(
      path: poolsPath,
      builder: (context, state) => const PoolsScreen(),
      routes: [
        GoRoute(
          path: 'cubes',
          builder: (context, state) => const CubesScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: 'game/:game',
          // The game is no longer chosen up front: its pools live on the root.
          redirect: (context, state) =>
              state.fullPath == '/game/:game' ? poolsPath : null,
          builder: (context, state) => const PoolsScreen(),
          routes: [
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
              builder: (context, state) =>
                  PoolEditorScreen(poolId: _pool(state), taggingTag: state.uri.queryParameters['tag']),
            ),
            GoRoute(
              path: 'pool/:pool/tierlist',
              builder: (context, state) => TierlistScreen(
                poolId: _pool(state),
                quality: state.uri.queryParameters['quality'],
                tag: state.uri.queryParameters['tag'],
              ),
            ),
            GoRoute(
              path: 'pool/:pool/details',
              builder: (context, state) => PoolDetailsScreen(poolId: _pool(state)),
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
