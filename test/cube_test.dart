import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/cube/domain/cube.dart';
import 'package:opack/features/cube/domain/cube_parsers.dart';
import 'package:opack/features/draft/domain/draft_session.dart';
import 'test_catalog.dart';

void main() {
  test('CubeCobra mainboard becomes cards with French names and ELO', () {
    final parsed = parseCubeCobra({
      'name': 'Traditional Powered Cube',
      'cards': {
        'mainboard': [
          {
            'details': {
              'name': 'Lightning Bolt',
              'set': 'm10',
              'collector_number': '146',
              'rarity': 'common',
              'colors': ['R'],
              'elo': 1650.5,
            },
          },
          {
            'details': {'name': 'Black Lotus', 'set': 'lea', 'collector_number': '232', 'rarity': 'rare'},
          },
        ],
        'maybeboard': [
          {'details': {'name': 'Ignored'}},
        ],
      },
    }, {'Lightning Bolt': 'Foudre'});

    expect(parsed.name, 'Traditional Powered Cube');
    expect(parsed.cards, hasLength(2));
    final bolt = parsed.cards.first;
    expect(bolt.id, 'M10-146');
    expect(bolt.nameFor('fr'), 'Foudre');
    expect(bolt.colors, 'R');
    expect(bolt.score, 1650.5);
    expect(parsed.cards.last.nameFor('fr'), 'Black Lotus');
  });

  test('CubeCobra links and IDs', () {
    expect(cubeCobraId('https://cubecobra.com/cube/list/vintage'), 'vintage');
    expect(cubeCobraId('https://cubecobra.com/cube/overview/abc-123?view=x'), 'abc-123');
    expect(cubeCobraId('  vintage '), 'vintage');
  });

  final database = YgoCardDatabase([
    {'id': '15693423', 'names': {'en': 'Evenly Matched', 'fr': 'À Forces Égales'}},
    {'id': '89631139', 'names': {'en': 'Blue-Eyes White Dragon', 'fr': 'Dragon Blanc aux Yeux Bleus'}, 'alt': ['89631140']},
    {'id': '23771716', 'names': {'en': '7 Colored Fish', 'fr': 'Poisson 7 Couleurs'}},
  ]);

  test('.ydk files resolve passcodes, including alternate artworks', () {
    final parsed = parseYgoList('#created by ...\n#main\n15693423\n089631140\n!side\n99999999\n', database);
    expect(parsed.cards.map((c) => c.id), ['15693423', '89631139']);
    expect(parsed.unresolved, ['99999999']);
  });

  test('name lists accept French, English and counts', () {
    final parsed = parseYgoList(
      'à forces égales\nBlue-Eyes White Dragon\n2x Dragon Blanc aux Yeux Bleus\n7 Colored Fish\nNope',
      database,
    );
    expect(parsed.cards.map((c) => c.nameFor('en')), [
      'Evenly Matched',
      'Blue-Eyes White Dragon',
      'Blue-Eyes White Dragon',
      'Blue-Eyes White Dragon',
      '7 Colored Fish',
    ]);
    expect(parsed.unresolved, ['Nope']);
  });

  List<CardData> cubeCards(int count) => List.generate(
        count,
        (i) => CardData(id: '$i', names: {'en': 'Card $i'}, rarity: Rarity.common, score: i.toDouble()),
      );

  Cube cubeOf(int count) => Cube(
        id: 'c',
        game: Game.mtg,
        name: 'Test',
        source: 'test',
        importedAt: DateTime(2026),
        cards: cubeCards(count),
      );

  test('closed cube never deals a card twice', () {
    final dealer = cubePool(cubeOf(45)).newSource();
    final dealt = [for (var i = 0; i < 3; i++) ...dealer.nextPack()];
    expect(dealt.map((c) => c.id).toSet(), hasLength(45));
    expect(dealer.nextPack, throwsStateError);
  });

  test('cube draft: seats from cube size, bots take the best ELO', () {
    final pool = cubePool(cubeOf(400));
    final seats = pool.seatsFor(3);
    expect(seats, 8); // 400 cards >= 8 x 3 x 15

    final session = DraftSession(
      pool.newSource(),
      rounds: 3,
      seats: seats,
      random: Random(3),
    );
    // The pack passed to the user lost its best card to the bot on the left.
    final firstPack = [...session.currentPack];
    session.pickCard(firstPack.first);
    final passed = session.currentPack;
    final botPick = session.pools[seats - 1].single;
    expect(passed.every((c) => c.score! < botPick.score!), isTrue);

    while (!session.isFinished) {
      session.pickCard(session.currentPack.first);
    }
    final all = session.pools.expand((pool) => pool).map((c) => c.id).toList();
    expect(all.toSet(), hasLength(all.length), reason: 'no card drafted twice');
    expect(session.userPool, hasLength(45));
  });
}
