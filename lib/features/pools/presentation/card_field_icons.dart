import 'package:flutter/material.dart';

import '../../catalog/domain/models.dart';
import '../domain/card_customs.dart';

/// An icon and the color it is drawn in (`null` for the text's own).
typedef FieldIcon = ({IconData icon, Color? color});

/// The icon naming a card field in the editor, by its key (`attribute`,
/// `card.name.fr`): what the field is about, `null` when nothing tells it
/// better than its name.
IconData? fieldIcon(String key) {
  final field = key.startsWith(cardFieldPrefix) ? key.substring(cardFieldPrefix.length) : key;
  if (field.startsWith('name')) return Icons.badge_outlined;
  return switch (field) {
    'rarity' || 'printedRarity' => Icons.diamond_outlined,
    'colors' || 'colorIdentity' || 'producedMana' => Icons.palette_outlined,
    'attribute' => Icons.auto_awesome_outlined,
    'supertype' => Icons.style_outlined,
    'race' || 'type' || 'types' || 'subtypes' || 'supertypes' || 'typeLine' => Icons.category_outlined,
    'categories' || 'frameType' || 'layout' => Icons.crop_portrait,
    'archetype' => Icons.groups_outlined,
    'level' => Icons.star_outline,
    'linkRating' || 'linkMarkers' => Icons.link,
    'scale' => Icons.balance,
    'atk' || 'power' => Icons.flash_on_outlined,
    'def' || 'defense' || 'toughness' => Icons.shield_outlined,
    'loyalty' || 'life' => Icons.favorite_border,
    'manaCost' || 'manaValue' || 'cost' => Icons.water_drop_outlined,
    'counter' => Icons.replay,
    'keywords' => Icons.sell_outlined,
    'text' => Icons.notes,
    'flavor' => Icons.format_quote,
    'hasEffect' => Icons.bolt_outlined,
    'setCode' || 'setName' => Icons.inventory_2_outlined,
    'collectorNumber' => Icons.tag,
    _ => null,
  };
}

/// The icon of a value picked for a field: a Yu-Gi-Oh! attribute, monster
/// type or category, an MtG type, a One Piece color or attack attribute.
/// They are plain pictograms in the value's usual color, not the games'
/// own symbols. `null` for a value with none (a word of the user's own).
FieldIcon? valueIcon(Game game, String key, String value) {
  final field = key.startsWith(cardFieldPrefix) ? key.substring(cardFieldPrefix.length) : key;
  final word = value.trim().toLowerCase();
  if (word.isEmpty) return null;
  return switch (field) {
    'attribute' => _attributes[word],
    'race' || 'subtypes' || 'categories' || 'frameType' || 'supertype' when game == Game.ygo =>
      _ygoTypes[word] ?? _ygoKinds[word],
    'types' || 'supertypes' when game == Game.mtg => _mtgTypes[word],
    'type' when game == Game.opc => _opcTypes[word],
    _ => null,
  };
}

/// Yu-Gi-Oh! attributes, and One Piece attack attributes.
const _attributes = <String, FieldIcon>{
  'dark': (icon: Icons.dark_mode, color: Color(0xFF7E57C2)),
  'light': (icon: Icons.light_mode, color: Color(0xFFF9A825)),
  'earth': (icon: Icons.landscape, color: Color(0xFF8D6E63)),
  'water': (icon: Icons.water_drop, color: Color(0xFF1E88E5)),
  'fire': (icon: Icons.local_fire_department, color: Color(0xFFE53935)),
  'wind': (icon: Icons.air, color: Color(0xFF43A047)),
  'divine': (icon: Icons.wb_sunny, color: Color(0xFFFFB300)),
  'slash': (icon: Icons.content_cut, color: Color(0xFFE53935)),
  'strike': (icon: Icons.sports_mma, color: Color(0xFFFB8C00)),
  'ranged': (icon: Icons.gps_fixed, color: Color(0xFF1E88E5)),
  'special': (icon: Icons.auto_awesome, color: Color(0xFF8E24AA)),
  'wisdom': (icon: Icons.menu_book, color: Color(0xFF43A047)),
};

/// Yu-Gi-Oh! monster types, and the types of spells and traps.
const _ygoTypes = <String, FieldIcon>{
  'aqua': (icon: Icons.water, color: null),
  'beast': (icon: Icons.pets, color: null),
  'beast-warrior': (icon: Icons.sports_martial_arts, color: null),
  'cyberse': (icon: Icons.memory, color: null),
  'dinosaur': (icon: Icons.terrain, color: null),
  'divine-beast': (icon: Icons.wb_sunny_outlined, color: null),
  'dragon': (icon: Icons.whatshot, color: null),
  'fairy': (icon: Icons.self_improvement, color: null),
  'fiend': (icon: Icons.mood_bad, color: null),
  'fish': (icon: Icons.set_meal, color: null),
  'illusion': (icon: Icons.blur_on, color: null),
  'insect': (icon: Icons.bug_report, color: null),
  'machine': (icon: Icons.precision_manufacturing, color: null),
  'plant': (icon: Icons.eco, color: null),
  'psychic': (icon: Icons.psychology, color: null),
  'pyro': (icon: Icons.local_fire_department_outlined, color: null),
  'reptile': (icon: Icons.gesture, color: null),
  'rock': (icon: Icons.hexagon_outlined, color: null),
  'sea serpent': (icon: Icons.waves, color: null),
  'spellcaster': (icon: Icons.auto_fix_high, color: null),
  'thunder': (icon: Icons.bolt, color: null),
  'warrior': (icon: Icons.security, color: null),
  'winged beast': (icon: Icons.flutter_dash, color: null),
  'wyrm': (icon: Icons.all_inclusive, color: null),
  'zombie': (icon: Icons.sick_outlined, color: null),
  'continuous': (icon: Icons.all_inclusive, color: null),
  'counter': (icon: Icons.undo, color: null),
  'equip': (icon: Icons.add, color: null),
  'field': (icon: Icons.explore_outlined, color: null),
  'quick-play': (icon: Icons.bolt, color: null),
};

/// Yu-Gi-Oh! categories and frames, in the frame's color.
const _ygoKinds = <String, FieldIcon>{
  'normal': (icon: Icons.crop_portrait, color: Color(0xFFC9A66B)),
  'effect': (icon: Icons.crop_portrait, color: Color(0xFFD9763D)),
  'fusion': (icon: Icons.crop_portrait, color: Color(0xFF9C5BB5)),
  'synchro': (icon: Icons.crop_portrait, color: Color(0xFFBDBDBD)),
  'xyz': (icon: Icons.crop_portrait, color: Color(0xFF424242)),
  'link': (icon: Icons.link, color: Color(0xFF1976D2)),
  'ritual': (icon: Icons.crop_portrait, color: Color(0xFF5C8DD6)),
  'token': (icon: Icons.crop_portrait, color: Color(0xFF9E9E9E)),
  'monster': (icon: Icons.crop_portrait, color: Color(0xFFD9763D)),
  'skill': (icon: Icons.crop_portrait, color: Color(0xFF3F6E9E)),
  'spell': (icon: Icons.crop_portrait, color: Color(0xFF26A69A)),
  'trap': (icon: Icons.crop_portrait, color: Color(0xFFC2185B)),
  'pendulum': (icon: Icons.balance, color: null),
  'tuner': (icon: Icons.tune, color: null),
  'flip': (icon: Icons.flip, color: null),
  'gemini': (icon: Icons.people_outline, color: null),
  'spirit': (icon: Icons.air, color: null),
  'toon': (icon: Icons.draw_outlined, color: null),
  'union': (icon: Icons.join_inner, color: null),
};

/// MtG card types and supertypes.
const _mtgTypes = <String, FieldIcon>{
  'creature': (icon: Icons.pets, color: null),
  'instant': (icon: Icons.bolt, color: null),
  'sorcery': (icon: Icons.auto_fix_high, color: null),
  'enchantment': (icon: Icons.auto_awesome, color: null),
  'artifact': (icon: Icons.settings_outlined, color: null),
  'land': (icon: Icons.landscape, color: null),
  'planeswalker': (icon: Icons.person_outline, color: null),
  'battle': (icon: Icons.flag_outlined, color: null),
  'legendary': (icon: Icons.workspace_premium_outlined, color: null),
  'basic': (icon: Icons.circle_outlined, color: null),
  'snow': (icon: Icons.ac_unit, color: null),
};

/// One Piece card types.
const _opcTypes = <String, FieldIcon>{
  'leader': (icon: Icons.workspace_premium_outlined, color: null),
  'character': (icon: Icons.person_outline, color: null),
  'event': (icon: Icons.bolt, color: null),
  'stage': (icon: Icons.landscape, color: null),
};

/// The game's own picture of a value, as a bundled asset: a Yu-Gi-Oh!
/// attribute or spell/trap kind from the card template, a monster type
/// from Master Duel's icons. `null` for a value with none, which falls
/// back on [valueIcon].
String? valueImage(Game game, String key, String value) {
  if (game != Game.ygo) return null;
  final field = key.startsWith(cardFieldPrefix) ? key.substring(cardFieldPrefix.length) : key;
  final word = value.trim().toLowerCase();
  return switch (field) {
    'attribute' when _ygoAttributeImages.contains(word) => 'assets/ygo_template/attribute-$word.png',
    'race' || 'subtypes' when _ygoTypeImages.contains(word.replaceAll(RegExp('[^a-z]'), '')) =>
      'assets/ygo_types/${word.replaceAll(RegExp('[^a-z]'), '')}.png',
    'race' || 'subtypes' when _ygoSpellImages.contains(word) => 'assets/ygo_template/icon-$word.png',
    _ => null,
  };
}

const _ygoAttributeImages = {'dark', 'divine', 'earth', 'fire', 'light', 'water', 'wind'};
const _ygoSpellImages = {'continuous', 'counter', 'equip', 'field', 'quick-play', 'ritual'};
const _ygoTypeImages = {
  'aqua', 'beast', 'beastwarrior', 'creatorgod', 'cyberse', 'dinosaur', 'divinebeast', 'dragon', 'fairy', 'fiend',
  'fish', 'illusion', 'insect', 'machine', 'plant', 'psychic', 'pyro', 'reptile', 'rock', 'seaserpent',
  'spellcaster', 'thunder', 'warrior', 'wingedbeast', 'wyrm', 'zombie',
};

/// The picture or icon of a value ([valueImage], else [valueIcon]) as a
/// widget [size] wide; `null` when the value has neither.
Widget? valueIconWidget(Game game, String fieldKey, String value, {double size = 18, Key? key}) {
  if (valueImage(game, fieldKey, value) case final asset?) {
    return Image.asset(asset, key: key, width: size, height: size, filterQuality: FilterQuality.medium);
  }
  return switch (valueIcon(game, fieldKey, value)) {
    null => null,
    (:final icon, :final color) => Icon(icon, key: key, size: size, color: color),
  };
}

/// [valueIconWidget] drawn, or an empty box of its size.
class ValueIcon extends StatelessWidget {
  const ValueIcon(this.game, this.fieldKey, this.value, {super.key, this.size = 18});

  final Game game;
  final String fieldKey;
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) =>
      valueIconWidget(game, fieldKey, value, size: size) ?? SizedBox(width: size, height: size);
}
