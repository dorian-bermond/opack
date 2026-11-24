import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/domain/card_filter.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/presentation/pool_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('grouping by tag leaves qualities aside, by quality takes only them', () {
    const card = CardData(id: 'X-1', names: {'en': 'X'}, rarity: Rarity.rare);
    final item = (card: card, info: null, tags: {'mine', 'rarity:rare', 'tier:S'});
    expect(GroupBy.tag.labelsOf(item, 'en'), ['mine']);
    expect(GroupBy.quality.labelsOf(item, 'en'), ['rarity:rare', 'tier:S']);
    expect(GroupBy.quality.labelsOf(item, 'en', quality: 'tier'), ['tier:S']);
    expect(GroupBy.quality.labelsOf(item, 'en', quality: 'nope'), ['ø']);
    expect(GroupBy.tag.labelsOf(item, 'en', quality: 'tier'), ['mine'], reason: 'tags ignore the quality');
    final bare = (card: card, info: null, tags: <String>{'rarity:rare'});
    expect(GroupBy.tag.labelsOf(bare, 'en'), [''], reason: 'a quality value is not a tag');
    expect(GroupBy.quality.labelsOf((card: card, info: null, tags: <String>{'mine'}), 'en'), ['ø']);
    expect(GroupBy.forGame(Game.mtg).take(3), [GroupBy.none, GroupBy.tag, GroupBy.quality]);
  });

  test('stacks group cards by the sort key, unknown values apart', () {
    const card = CardData(id: 'DMU-1', names: {'en': 'Karn'}, rarity: Rarity.mythic);
    const creature = MtgCardInfo(
      name: 'Karn',
      manaValue: 9,
      colors: [],
      types: ['Creature'],
      power: '4',
      layout: 'normal',
      setCode: 'DMU',
      collectorNumber: '1',
    );
    final item = (card: card, info: creature, tags: const <String>{});
    expect(stackLabel(CardSort.name, item, 'en'), 'K');
    expect(stackLabel(CardSort.rarity, item, 'en'), 'mythic');
    expect(stackLabel(CardSort.manaValue, item, 'en'), '7+');
    expect(stackLabel(CardSort.color, item, 'en'), 'C');
    expect(stackLabel(CardSort.type, item, 'en'), 'Creature');
    expect(stackLabel(CardSort.power, item, 'en'), '4');
    expect(stackLabel(CardSort.collector, item, 'en'), 'DMU');

    final unknown = (card: card, info: null, tags: const <String>{});
    expect(stackLabel(CardSort.manaValue, unknown, 'en'), '?');
    expect(stackLabel(CardSort.color, unknown, 'en'), '?');

    const monster = YgoCardInfo(
      name: 'Dragon',
      kind: YgoKind.monster,
      type: 'Link Monster',
      categories: ['Link'],
      frameType: 'link',
      race: 'Dragon',
      attribute: 'LIGHT',
      linkRating: 3,
      atk: 2500,
    );
    final link = (card: card, info: monster, tags: const <String>{});
    expect(stackLabel(CardSort.level, link, 'en'), 'LINK-3');
    expect(stackLabel(CardSort.atk, link, 'en'), '2500-2999');
    expect(stackLabel(CardSort.def, link, 'en'), '?');
    expect(stackLabel(CardSort.attribute, link, 'en'), 'LIGHT');
    expect(stackLabel(CardSort.archetype, link, 'en'), '');

    // The kind: monsters told apart as normal and effect while the setting is on.
    const vanilla = YgoCardInfo(name: 'Kuriboh', kind: YgoKind.monster, type: 'Normal Monster', frameType: 'normal');
    const spell = YgoCardInfo(name: 'Pot', kind: YgoKind.spell, type: 'Spell Card', frameType: 'spell');
    final plain = (card: card, info: vanilla, tags: const <String>{});
    final pot = (card: card, info: spell, tags: const <String>{});
    expect(stackLabel(CardSort.type, link, 'en'), 'link', reason: 'the frame');
    expect(stackLabel(CardSort.type, plain, 'en'), 'normal');
    expect(stackLabel(CardSort.type, pot, 'en'), 'spell');
    const pendulum = YgoCardInfo(name: 'Odd-Eyes', kind: YgoKind.monster, type: 'Pendulum Effect Fusion Monster', frameType: 'fusion_pendulum');
    expect(stackLabel(CardSort.type, (card: card, info: pendulum, tags: const <String>{}), 'en'), 'fusion',
        reason: 'a pendulum monster goes with its base frame');
    expect(CardSort.type.compare(plain, link, 'en'), lessThan(0), reason: 'normal before link');
    expect(CardSort.type.compare(link, pot, 'en'), lessThan(0), reason: 'monsters before spells');
    YgoKinds.splitNormalEffect = false;
    addTearDown(() => YgoKinds.splitNormalEffect = true);
    expect(stackLabel(CardSort.type, link, 'en'), 'monster');
    expect(stackLabel(CardSort.type, plain, 'en'), 'monster');
    expect(CardSort.type.compare(plain, link, 'en'), 0, reason: 'no difference between monsters');
  });

  test('the chosen view is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    expect(container.read(poolViewProvider), PoolView.list);
    container.read(poolViewProvider.notifier).select(PoolView.stacks);
    expect(container.read(poolViewProvider), PoolView.stacks);
    expect(prefs.getString('poolView'), 'stacks');
  });
}
