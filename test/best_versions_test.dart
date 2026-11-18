import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/packs/domain/best_versions.dart';
import 'package:opack/features/packs/domain/pack_source.dart';
import 'package:opack/features/pools/domain/play_pool.dart';
import 'package:opack/features/pools/domain/pool.dart';

void main() {
  const base = CardData(id: 'EB05-014', names: {'en': 'Shirahoshi'}, rarity: Rarity.superRare);
  const parallel = CardData(id: 'EB05-014_p1', names: {'en': 'Shirahoshi'}, rarity: Rarity.parallel, printedRarity: Rarity.superRare);
  const manga = CardData(id: 'EB05-014_p2', names: {'en': 'Shirahoshi'}, rarity: Rarity.manga, printedRarity: Rarity.superRare);
  const nami = CardData(id: 'EB05-055', names: {'en': 'Nami'}, rarity: Rarity.superRare);
  const namiA = CardData(id: 'EB05-055_p1', names: {'en': 'Nami'}, rarity: Rarity.parallel, printedRarity: Rarity.superRare);
  const namiB = CardData(id: 'EB05-055_p2', names: {'en': 'Nami'}, rarity: Rarity.parallel, printedRarity: Rarity.superRare);
  const common = CardData(id: 'EB05-001', names: {'en': 'Camie'}, rarity: Rarity.common);

  test('every print maps to the rarest version of its card, the latest print when equal', () {
    expect(baseCardId('OP05-119_p2'), 'OP05-119');
    expect(baseCardId('OP12-090_r1'), 'OP12-090');
    expect(baseCardId('CIBR-FR077'), 'CIBR-FR077');
    final best = bestVersions([base, parallel, manga, nami, namiA, namiB, common]);
    expect(best['EB05-014'], manga);
    expect(best['EB05-014_p1'], manga);
    expect(best['EB05-014_p2'], manga);
    expect(best['EB05-055'], namiB, reason: 'two parallel arts: the latest');
    expect(best['EB05-001'], common, reason: 'alone, itself');
  });

  test('a pool dealing the best versions swaps every pulled card, foil kept', () {
    var pool = Pool.empty(Game.opc, name: 'p').withSource(const CardsSource([base, parallel, manga, common]), cards: [base, parallel, manga, common]);
    pool = pool.copyWith(slots: const [PackSlot(1, [SlotOption('rarity:superRare')]), PackSlot(1, [SlotOption('rarity:common')])]);
    expect(pool.bestVersions, isFalse);
    final plain = PlayPool.resolve(pool, sets: const {}, cubes: const {}).boosterPlay('Booster')!.newSource().nextPack();
    expect(plain.map((c) => c.id), ['EB05-014', 'EB05-001']);

    final upgraded = pool.withBestVersions(true);
    final reloaded = Pool.fromJson(jsonDecode(jsonEncode(upgraded.toJson())) as Map<String, dynamic>);
    expect(reloaded.bestVersions, isTrue);
    expect(reloaded.copyWith(name: 'q').bestVersions, isTrue, reason: 'kept by copyWith');
    expect(reloaded.withBestVersions(false).toJson().containsKey('bestVersions'), isFalse);
    final pack = PlayPool.resolve(reloaded, sets: const {}, cubes: const {}).boosterPlay('Booster')!.newSource().nextPack();
    expect(pack.map((c) => c.id), ['EB05-014_p2', 'EB05-001']);

    final foil = BestVersionsSource(_Fixed([base.asFoil()]), bestVersions([base, manga])).nextPack().single;
    expect(foil.id, 'EB05-014_p2');
    expect(foil.foil, isTrue);
  });
}

class _Fixed implements PackSource {
  const _Fixed(this.pack);
  final List<CardData> pack;
  @override
  List<CardData> nextPack() => pack;
}
