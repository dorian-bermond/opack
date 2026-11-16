import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/domain/card_filter.dart';
import 'package:opack/features/card_info/domain/card_info.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/features/pools/presentation/pool_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('grouping by tag leaves qualities aside, by quality takes only them, both take all', () {
    const card = CardData(id: 'X-1', names: {'en': 'X'}, rarity: Rarity.rare);
    final item = (card: card, info: null, tags: {'mine', 'rarity:rare', 'tier:S'});
    expect(GroupBy.tag.labelsOf(item, 'en'), ['mine']);
    expect(GroupBy.quality.labelsOf(item, 'en'), ['rarity:rare', 'tier:S']);
    expect(GroupBy.tagAndQuality.labelsOf(item, 'en'), unorderedEquals(['mine', 'rarity:rare', 'tier:S']));
    expect(GroupBy.quality.labelsOf(item, 'en', quality: 'tier'), ['tier:S']);
    expect(GroupBy.tagAndQuality.labelsOf(item, 'en', quality: 'tier'), unorderedEquals(['mine', 'tier:S']));
    expect(GroupBy.quality.labelsOf(item, 'en', quality: 'nope'), ['']);
    expect(GroupBy.tag.labelsOf(item, 'en', quality: 'tier'), ['mine'], reason: 'tags ignore the quality');
    final bare = (card: card, info: null, tags: <String>{'rarity:rare'});
    expect(GroupBy.tag.labelsOf(bare, 'en'), [''], reason: 'a quality value is not a tag');
    expect(GroupBy.quality.labelsOf((card: card, info: null, tags: <String>{'mine'}), 'en'), ['']);
    expect(GroupBy.forGame(Game.mtg).take(4), [GroupBy.none, GroupBy.tag, GroupBy.quality, GroupBy.tagAndQuality]);
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
