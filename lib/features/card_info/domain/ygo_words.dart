import 'card_info.dart';

/// The words of a Yu-Gi-Oh! card in other languages than English: its
/// attribute (EARTH, TERRE), its type (Zombie, Magicien), its supertype
/// (Monster, Monstre), a spell's or trap's kind (Quick-Play, Jeu-Rapide)
/// and its categories (Tuner, Syntoniseur), by the English word in lower
/// case. The data keeps the English words; these are how they read.
const ygoWords = <String, Map<String, String>>{
  'fr': {
    // Attributes.
    'dark': 'TÉNÈBRES', 'light': 'LUMIÈRE', 'earth': 'TERRE', 'water': 'EAU', 'fire': 'FEU', 'wind': 'VENT',
    'divine': 'DIVIN',
    // Supertypes.
    'monster': 'Monstre', 'spell': 'Magie', 'trap': 'Piège', 'skill': 'Compétence',
    // Spell and trap kinds.
    'continuous': 'Continu', 'counter': 'Contre', 'equip': 'Équipement', 'field': 'Terrain',
    'quick-play': 'Jeu-Rapide',
    // Types.
    'aqua': 'Aqua', 'beast': 'Bête', 'beast-warrior': 'Bête-Guerrier', 'creator-god': 'Dieu Créateur',
    'creator god': 'Dieu Créateur', 'cyberse': 'Cyberse', 'dinosaur': 'Dinosaure', 'divine-beast': 'Bête Divine',
    'dragon': 'Dragon', 'fairy': 'Elfe', 'fiend': 'Démon', 'fish': 'Poisson', 'illusion': 'Illusion',
    'insect': 'Insecte', 'machine': 'Machine', 'plant': 'Plante', 'psychic': 'Psychique', 'pyro': 'Pyro',
    'reptile': 'Reptile', 'rock': 'Rocher', 'sea serpent': 'Serpent de Mer', 'spellcaster': 'Magicien',
    'thunder': 'Tonnerre', 'warrior': 'Guerrier', 'winged beast': 'Bête Ailée', 'wyrm': 'Wyrm', 'zombie': 'Zombie',
    // Categories.
    'fusion': 'Fusion', 'synchro': 'Synchro', 'xyz': 'Xyz', 'ritual': 'Rituel', 'link': 'Lien',
    'pendulum': 'Pendule', 'gemini': 'Gémeau', 'spirit': 'Spirit', 'toon': 'Toon', 'union': 'Union',
    'flip': 'Flip', 'tuner': 'Syntoniseur', 'effect': 'Effet', 'normal': 'Normal', 'token': 'Jeton',
  },
};

/// [value] as it reads in [language]: its word there, else as it is.
String ygoWord(String language, String value) => ygoWords[language]?[value.trim().toLowerCase()] ?? value;

/// The English word behind [typed] in [language] (TERRE gives EARTH), in
/// the case the data keeps; [typed] itself when it is no known word.
String ygoCanonical(String language, String typed) {
  final word = typed.trim().toLowerCase();
  if (word.isEmpty) return typed;
  for (final canonical in _canonicalWords) {
    if (canonical.toLowerCase() == word || ygoWord(language, canonical).toLowerCase() == word) return canonical;
  }
  return typed;
}

/// Every English word the data may hold, in its case.
final _canonicalWords = <String>{
  ...ygoAttributes,
  ...ygoSupertypes,
  ...ygoSpellTrapKinds,
  ...ygoMonsterTypes,
  ...ygoCategories,
};
