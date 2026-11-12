import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/draft/domain/draft_session.dart';
import 'package:opack/features/packs/domain/pack_generator.dart';

import 'test_catalog.dart';

void main() {
  test('rounds can pick two and burn one per pass, from different packs', () {
    final set = loadBundled('mtg/DMU');
    final draft = PackGenerator(set.booster(), random: Random(1));
    final session = DraftSession.rounds(
      [
        DraftRound(draft, picks: 2, burn: 1),
        DraftRound(PackGenerator(set.booster(BoosterType.collector), random: Random(2))),
      ],
      seats: 4,
      random: Random(3),
    );
    expect(session.rounds, 2);
    expect(session.phase, DraftPhase.pick);
    expect(session.remainingInPhase, 2);
    final size = session.currentPack.length;

    session.pickCard(session.currentPack.first);
    expect(session.phase, DraftPhase.pick);
    expect(session.remainingInPhase, 1);
    session.pickCard(session.currentPack.first);
    expect(session.phase, DraftPhase.burn, reason: 'two taken, one to burn before passing');
    expect(session.userPool, hasLength(2));
    session.pickCard(session.currentPack.first);
    expect(session.userPool, hasLength(2), reason: 'a burned card goes nowhere');
    expect(session.pick, 2);
    expect(session.currentPack, hasLength(size - 3), reason: 'every seat took 2 and burned 1');

    while (session.round == 1) {
      session.pickCard(session.currentPack.first);
    }
    expect(session.currentRound.picks, 1);
    expect(session.currentRound.burn, 0);
    expect(session.currentPack.length, greaterThanOrEqualTo(size), reason: 'a fresh collector pack');
    for (final pool in session.pools) {
      expect(pool.length, session.userPool.length);
    }
  });

  for (final path in ['ygo/CIBR', 'mtg/DMU']) {
    test('$path draft gives every seat the same number of picks', () {
      final set = loadBundled(path);
      final session = DraftSession(
        PackGenerator(set.booster(), random: Random(6)),
        rounds: 3,
        random: Random(7),
      );

      var picks = 0;
      while (!session.isFinished) {
        expect(session.currentPack, isNotEmpty);
        session.pickCard(session.currentPack.first);
        picks++;
      }

      expect(picks, greaterThanOrEqualTo(3 * 9));
      for (final pool in session.pools) {
        expect(pool, hasLength(picks));
      }
    });
  }
}
