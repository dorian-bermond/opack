import 'dart:convert';
import 'dart:io';

import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/cube/domain/cube.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';
import 'package:opack/features/pools/domain/pool_config.dart';

/// A bundled set read straight from disk, e.g. `loadBundled('ygo/CIBR')`.
CardSet loadBundled(String path) => CardSet.fromJson(
      jsonDecode(File('assets/sets/$path.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// A cube resolved as a pool with [config] (the cube as listed by default).
PlayPool cubePool(Cube cube, [PoolConfig config = const PoolConfig.closed()]) => PlayPool.resolve(
      Pool.ofCube(cube).copyWith(config: config),
      sets: const {},
      cubes: {cube.id: cube},
    );
