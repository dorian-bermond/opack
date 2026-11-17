// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Opack';

  @override
  String get chooseGame => 'Choisissez un jeu';

  @override
  String get chooseSet => 'Choisissez une extension';

  @override
  String get gameMtg => 'Magic: The Gathering';

  @override
  String get gameYgo => 'Yu-Gi-Oh!';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get pictureLanguage => 'Langue des images de cartes';

  @override
  String get dataLanguage => 'Langue des noms et textes de cartes';

  @override
  String get modeOpen => 'Ouvrir un booster';

  @override
  String get modeSealed => 'Scellé';

  @override
  String get modeDraft => 'Draft';

  @override
  String get tapToOpen => 'Touchez le booster pour l\'ouvrir';

  @override
  String get revealAll => 'Tout révéler';

  @override
  String get openAnother => 'Ouvrir un autre';

  @override
  String get openingModeSetting => 'Ouverture des boosters';

  @override
  String get openingGrid => 'Grille : touchez chaque carte';

  @override
  String get openingSwipe => 'Pile : glissez carte par carte';

  @override
  String get swipeToReveal =>
      'Touchez ou glissez la carte pour voir la suivante';

  @override
  String cardsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes restantes',
      one: '1 carte restante',
    );
    return '$_temp0';
  }

  @override
  String get dealAgain => 'Redistribuer';

  @override
  String get newPool => 'Nouveau pool';

  @override
  String get sealedPool => 'Pool scellé';

  @override
  String cardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes',
      one: '1 carte',
    );
    return '$_temp0';
  }

  @override
  String packsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boosters',
      one: '1 booster',
    );
    return '$_temp0';
  }

  @override
  String draftHeader(int round, int rounds, int pick) {
    return 'Ronde $round/$rounds · Choix $pick';
  }

  @override
  String get draftDone => 'Draft terminé';

  @override
  String get yourPool => 'Votre pool';

  @override
  String get restart => 'Recommencer';

  @override
  String get rarityCommon => 'Commune';

  @override
  String get rarityUncommon => 'Peu commune';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityMythic => 'Rare mythique';

  @override
  String get raritySuperRare => 'Super rare';

  @override
  String get rarityUltraRare => 'Ultra rare';

  @override
  String get raritySecretRare => 'Secret rare';

  @override
  String get raritySpecial => 'Spéciale';

  @override
  String get foil => 'Premium';

  @override
  String get searchSets => 'Rechercher une extension';

  @override
  String get boosterPlay => 'Booster de jeu';

  @override
  String get boosterDraft => 'Booster de draft';

  @override
  String get boosterStandard => 'Booster';

  @override
  String get boosterSet => 'Booster d\'extension';

  @override
  String get boosterCollector => 'Booster collector';

  @override
  String get tabSets => 'Extensions';

  @override
  String get tabCubes => 'Cubes';

  @override
  String get importCubeCobra => 'Importer depuis CubeCobra';

  @override
  String get importCubeFile => 'Importer une liste';

  @override
  String get cubeCobraIdLabel => 'ID ou lien du cube CubeCobra';

  @override
  String get noCubesMtg =>
      'Aucun cube. Importez-en un depuis CubeCobra avec son ID (ex. « vintage ») ; il est ensuite enregistré sur cet appareil et jouable hors ligne.';

  @override
  String get noCubesYgo =>
      'Aucun cube. Importez un fichier .ydk ou un fichier texte avec un nom de carte par ligne (français ou anglais).';

  @override
  String cubeImported(String name, int count) {
    return 'Cube « $name » importé : $count cartes';
  }

  @override
  String unresolvedCards(int count, String examples) {
    return '$count lignes non reconnues : $examples';
  }

  @override
  String importFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String poolTooSmall(int packs, int packSize, int needed) {
    return 'Ce pool peut fournir $packs boosters de $packSize cartes ; ce mode en demande $needed. Donnez plus d\'exemplaires aux cartes limitées, ou rendez-en certaines illimitées.';
  }

  @override
  String get poolOpen => 'Ouvert';

  @override
  String get poolClosed => 'Fermé';

  @override
  String get poolCustom => 'Personnalisé';

  @override
  String get poolOpenDescription =>
      'Préréglage : toutes les cartes en illimité, comme dans des boosters';

  @override
  String get poolClosedDescription =>
      'Préréglage : chaque carte un nombre fixe de fois, comme dans un cube. Chaque emplacement pioche dans les exemplaires restants, donc le plus rare limite le nombre de boosters';

  @override
  String copiesPerCard(int count) {
    return '$count × chaque carte';
  }

  @override
  String get editPool => 'Modifier';

  @override
  String get tabPools => 'Pools';

  @override
  String get createPool => 'Créer un pool';

  @override
  String get noPools =>
      'Aucun pool pour l\'instant. Un pool est la liste de cartes dont on ouvre les boosters et avec laquelle on joue en scellé et en draft : créez-en un vide, à partir d\'une extension ou d\'un cube, puis ajustez-le dans son éditeur.';

  @override
  String get poolEmpty => 'Pool vide';

  @override
  String get poolFromSet => 'À partir d\'une extension';

  @override
  String get poolFromCube => 'À partir d\'un cube';

  @override
  String get poolNoSources => 'Aucune carte pour l\'instant';

  @override
  String get poolEmptyHint =>
      'Ce pool n\'a pas encore de cartes. Modifiez-le pour ajouter une extension ou un cube.';

  @override
  String packsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boosters restants',
      one: '1 booster restant',
    );
    return '$_temp0';
  }

  @override
  String get duplicatePool => 'Dupliquer';

  @override
  String get deletePool => 'Supprimer le pool';

  @override
  String copyOf(String name) {
    return '$name (copie)';
  }

  @override
  String get renamePool => 'Renommer';

  @override
  String get apply => 'Appliquer';

  @override
  String get addSource => 'Ajouter une extension ou un cube';

  @override
  String get poolSources => 'Cartes de';

  @override
  String get packLayout => 'Composition des boosters';

  @override
  String get poolCopies => 'Exemplaires';

  @override
  String get randomPacks => 'Boosters aléatoires';

  @override
  String cardsPerPack(int count) {
    return '$count cartes par booster';
  }

  @override
  String cardsUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes ne correspondent à aucun emplacement',
      one: '1 carte ne correspond à aucun emplacement',
    );
    return '$_temp0';
  }

  @override
  String presetDropsChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ce préréglage annule les $count cartes que vous avez modifiées.',
      one: 'Ce préréglage annule la carte que vous avez modifiée.',
    );
    return '$_temp0';
  }

  @override
  String get resetCards => 'Remettre toutes les cartes au préréglage';

  @override
  String get packsUnlimited => 'Boosters illimités';

  @override
  String packsAvailable(int count, int packSize) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boosters',
      one: '1 booster',
    );
    return '$_temp0 de $packSize cartes disponibles';
  }

  @override
  String cardsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes modifiées',
      one: '1 carte modifiée',
    );
    return '$_temp0';
  }

  @override
  String get searchCards => 'Rechercher des cartes';

  @override
  String listedTimes(int count) {
    return 'listée $count ×';
  }

  @override
  String get unlimitedCopies => 'Exemplaires illimités';

  @override
  String copiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exemplaires',
      one: '1 exemplaire',
      zero: 'Exclue',
    );
    return '$_temp0';
  }

  @override
  String get deleteCube => 'Supprimer le cube';

  @override
  String get cancel => 'Annuler';

  @override
  String get import => 'Importer';

  @override
  String get settings => 'Paramètres';

  @override
  String get cardImagesSetting => 'Images des cartes';

  @override
  String get cardImagesOnline => 'Télécharger en ligne';

  @override
  String get sortBy => 'Trier par';

  @override
  String get sortName => 'Nom';

  @override
  String get sortRarity => 'Rareté';

  @override
  String get sortManaValue => 'Valeur de mana';

  @override
  String get sortColor => 'Couleur';

  @override
  String get sortType => 'Type';

  @override
  String get sortPower => 'Force';

  @override
  String get sortToughness => 'Endurance';

  @override
  String get sortCollector => 'Numéro de collection';

  @override
  String get sortLevel => 'Niveau / Rang';

  @override
  String get sortAtk => 'ATK';

  @override
  String get sortDef => 'DEF';

  @override
  String get sortAttribute => 'Attribut';

  @override
  String get sortRace => 'Type de monstre';

  @override
  String get sortArchetype => 'Archétype';

  @override
  String get filters => 'Filtres';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get poolStats => 'Statistiques';

  @override
  String cardsShown(int shown, int total) {
    return '$shown cartes sur $total';
  }

  @override
  String cardDataMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes sans détails',
      one: '1 carte sans détails',
    );
    return '$_temp0';
  }

  @override
  String get fetchCardData => 'Télécharger les détails des cartes';

  @override
  String get fetchingCardData => 'Téléchargement des détails…';

  @override
  String get fetchCardDataFailed =>
      'Téléchargement impossible. Vérifiez la connexion et réessayez.';

  @override
  String averageValue(String value) {
    return 'Moyenne $value';
  }

  @override
  String highestValue(String value) {
    return 'Maximum $value';
  }

  @override
  String knownOf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes avec une valeur',
      one: '1 carte avec une valeur',
    );
    return '$_temp0';
  }

  @override
  String get facetRarity => 'Rareté';

  @override
  String get facetColor => 'Couleur';

  @override
  String get facetColorIdentity => 'Identité de couleur';

  @override
  String get facetType => 'Type';

  @override
  String get facetSubtype => 'Sous-type';

  @override
  String get facetKeyword => 'Mot-clé';

  @override
  String get facetManaValue => 'Valeur de mana';

  @override
  String get facetSet => 'Extension';

  @override
  String get facetKind => 'Genre de carte';

  @override
  String get facetCategory => 'Catégorie de monstre';

  @override
  String get facetAttribute => 'Attribut';

  @override
  String get facetRace => 'Type de monstre';

  @override
  String get facetProperty => 'Propriété Magie / Piège';

  @override
  String get facetArchetype => 'Archétype';

  @override
  String get facetLevel => 'Niveau / Rang';

  @override
  String get facetLinkRating => 'Classification Lien';

  @override
  String get facetAtk => 'ATK';

  @override
  String get facetDef => 'DEF';

  @override
  String get metricManaCurve => 'Courbe de mana';

  @override
  String get metricColors => 'Couleurs';

  @override
  String get metricColorIdentity => 'Identité de couleur';

  @override
  String get metricColorCount => 'Mono, multi, incolore';

  @override
  String get metricDevotion => 'Dévotion (symboles de mana colorés)';

  @override
  String get metricTypes => 'Types de carte';

  @override
  String get metricSubtypes => 'Sous-types principaux';

  @override
  String get metricKeywords => 'Mots-clés principaux';

  @override
  String get metricCreatureSize => 'Tailles des créatures (force/endurance)';

  @override
  String get metricRarity => 'Rareté';

  @override
  String get metricFoil => 'Premium';

  @override
  String get metricSets => 'Extensions';

  @override
  String get metricKind => 'Monstres, Magies, Pièges';

  @override
  String get metricCategories => 'Catégories de monstres';

  @override
  String get metricLevels => 'Niveaux';

  @override
  String get metricRanks => 'Rangs';

  @override
  String get metricLinkRatings => 'Classifications Lien';

  @override
  String get metricAttributes => 'Attributs';

  @override
  String get metricRaces => 'Types de monstres';

  @override
  String get metricAtk => 'ATK';

  @override
  String get metricDef => 'DEF';

  @override
  String get metricArchetypes => 'Archétypes principaux';

  @override
  String get metricProperties => 'Propriétés des Magies et Pièges';

  @override
  String get colorWhite => 'Blanc';

  @override
  String get colorBlue => 'Bleu';

  @override
  String get colorBlack => 'Noir';

  @override
  String get colorRed => 'Rouge';

  @override
  String get colorGreen => 'Vert';

  @override
  String get colorless => 'Incolore';

  @override
  String get monoColored => 'Monocolore';

  @override
  String get multiColored => 'Multicolore';

  @override
  String get kindMonster => 'Monstre';

  @override
  String get kindSpell => 'Magie';

  @override
  String get kindTrap => 'Piège';

  @override
  String get noArchetype => 'Sans archétype';

  @override
  String get nonFoil => 'Non premium';

  @override
  String get advancedSearch => 'Recherche avancée';

  @override
  String pickedCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes choisies',
      one: '1 carte choisie',
    );
    return '$_temp0';
  }

  @override
  String get searchOnline => 'Rechercher des cartes en ligne';

  @override
  String get searchHint => 'Nom ou texte';

  @override
  String get searchButton => 'Rechercher';

  @override
  String get noResults => 'Aucune carte trouvée.';

  @override
  String get moreResults =>
      'Il y a d\'autres résultats : affinez la recherche.';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnées',
      one: '1 sélectionnée',
      zero: 'Aucune sélection',
    );
    return '$_temp0';
  }

  @override
  String get addSelected => 'Ajouter au pool';

  @override
  String searchFailed(String error) {
    return 'Recherche impossible : $error';
  }

  @override
  String get rarityColorsSetting => 'Couleurs des raretés';

  @override
  String get rarityColorsHint =>
      'La couleur de la marque et du tier de chaque rareté. Touchez-en une pour la changer.';

  @override
  String get colorDefault => 'Par défaut';

  @override
  String get colorReset => 'Revenir à la couleur par défaut';

  @override
  String get gameOpc => 'One Piece Card Game';

  @override
  String get rarityLeader => 'Leader';

  @override
  String get noCubesOpc =>
      'Aucun cube. Importez un fichier texte avec une carte par ligne, par nom ou par code (ex. « OP01-001 »).';

  @override
  String get facetCost => 'Coût';

  @override
  String get facetCounter => 'Contre';

  @override
  String get metricCostCurve => 'Courbe de coût';

  @override
  String get metricPower => 'Puissance';

  @override
  String get metricCounters => 'Contres';

  @override
  String get metricLife => 'Vie des leaders';

  @override
  String get groupWhichQuality => 'Grouper selon quelle qualité ?';

  @override
  String get allQualities => 'Toutes les qualités';

  @override
  String get noQualityGroup => 'Sans valeur de qualité';

  @override
  String get valueCopies => 'Exemplaires de chaque carte portant cette valeur';

  @override
  String get valueCopiesHint =>
      '× fixe le nombre d\'exemplaires de chaque carte portant cette valeur (— : le nombre du pool, ∞ : illimité). Le nombre propre à une carte l\'emporte.';

  @override
  String get batchImport => 'Import en lot';

  @override
  String get batchImportHint =>
      'Collez une liste, une carte par ligne (« 1 Nom » ou juste « Nom »). Chaque ligne est cherchée en ligne ; la carte nommée exactement comme elle l\'emporte, sinon la première trouvée.';

  @override
  String get batchLookUp => 'Chercher';

  @override
  String batchFound(int found, int unknown) {
    String _temp0 = intl.Intl.pluralLogic(
      found,
      locale: localeName,
      other: '$found cartes trouvées',
      one: '1 carte trouvée',
      zero: 'Aucune carte trouvée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      unknown,
      locale: localeName,
      other: '$unknown lignes inconnues',
      one: '1 ligne inconnue',
      zero: 'toutes les lignes reconnues',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get batchTags => 'Tags pour tout le lot';

  @override
  String get batchTagsHint =>
      'Chaque carte importée reçoit chaque tag coché ; saisissez un nom pour en créer un.';

  @override
  String get batchAdd => 'Ajouter au pool';

  @override
  String get cardSpacing => 'Espacement des cartes';

  @override
  String get editQualityTitle => 'Modifier la qualité';

  @override
  String get deleteQuality => 'Supprimer la qualité';

  @override
  String deleteQualityTitle(String quality) {
    return 'Supprimer la qualité $quality ?';
  }

  @override
  String get deleteQualityAffects =>
      'Toutes ses valeurs disparaissent, et les cartes les perdent. Les emplacements de booster qui en tiraient perdent cette option.';

  @override
  String get deleteValue => 'Supprimer la valeur';

  @override
  String get qualityValuesHintAscending =>
      'La plus basse en premier, dans l\'ordre où elles s\'afficheront.';

  @override
  String get qualityOrder => 'Ordre des valeurs';

  @override
  String get orderDescending => 'Meilleure en premier';

  @override
  String get orderAscending => 'Plus basse en premier';

  @override
  String get rarityMarkerSetting => 'Marque de rareté';

  @override
  String get rarityMarkerBorder => 'Bordure colorée';

  @override
  String get rarityMarkerDot => 'Petit point en bas';

  @override
  String get tagsHint =>
      'Un tag est un trait oui/non, comme porter la barbe : une carte porte autant de tags qu\'elle veut.';

  @override
  String get qualitiesTitle => 'Qualités';

  @override
  String get qualitiesHint =>
      'Une qualité est un trait à une valeur parmi plusieurs, comme la couleur des cheveux : une carte en porte une valeur, ou aucune. Les valeurs sont classées, la meilleure en premier, chacune avec une couleur.';

  @override
  String get addValue => 'Ajouter une valeur';

  @override
  String get valueName => 'Valeur';

  @override
  String get valueColor => 'Couleur';

  @override
  String get cardHoverPreview => 'Grand aperçu au survol d\'une carte';

  @override
  String get collapse => 'Replier';

  @override
  String get expand => 'Déplier';

  @override
  String get cardSize => 'Taille des cartes';

  @override
  String get newQualityTitle => 'Ajouter une qualité';

  @override
  String get newQualityHint =>
      'Une qualité est un ensemble de valeurs exclusives dont une carte porte une seule, comme une rareté. Ses valeurs sont classées, la meilleure en premier.';

  @override
  String get qualityName => 'Nom de la qualité';

  @override
  String get qualityValues => 'Valeurs';

  @override
  String get qualityValuesHint => 'Une par ligne, la meilleure en premier.';

  @override
  String get tierlist => 'Tierlist';

  @override
  String get tierlistQuality => 'Qualité';

  @override
  String get tierlistGroup => 'Cartes';

  @override
  String get allCards => 'Toutes les cartes';

  @override
  String get newQuality => 'Nouvelle qualité…';

  @override
  String get noQualityYet => 'aucune';

  @override
  String get tierlistNoQuality =>
      'Choisissez la qualité selon laquelle trier les cartes, ou créez-en une : chacune de ses valeurs devient un tier.';

  @override
  String get addTier => 'Ajouter un tier';

  @override
  String get tierlistFeedHint =>
      'Glissez une carte vers un tier pour lui donner cette valeur ; déposez-la ici pour la lui retirer. Ctrl+Z annule.';

  @override
  String get tagQuality => 'Qualité (facultatif)';

  @override
  String get tagQualityHint =>
      'Les tags d\'une qualité sont exclusifs : une carte n\'en porte qu\'un, comme une rareté.';

  @override
  String get qualityHint =>
      'Les tags d\'une qualité sont exclusifs : en donner un à une carte lui retire les autres.';

  @override
  String get plainTags => 'Autres tags';

  @override
  String get tagBaskets => 'Paniers de tags';

  @override
  String get basketsHint =>
      'Glissez une carte sur un panier pour lui donner ce tag. Ctrl+Z annule le dernier dépôt.';

  @override
  String get undo => 'Annuler';

  @override
  String get cardsPerRow => 'Par ligne';

  @override
  String get columnsAuto => 'auto';

  @override
  String get fewerPerRow => 'Moins de cartes par ligne';

  @override
  String get morePerRow => 'Plus de cartes par ligne';

  @override
  String get poolDetails => 'Détails du pool';

  @override
  String get tagChipHint =>
      'Touchez un tag pour choisir ses cartes dans l\'éditeur.';

  @override
  String get searchPanel => 'Chercher des cartes à ajouter';

  @override
  String get searchPanelHint =>
      'Touchez une carte pour l\'ajouter au pool ; touchez-la encore pour la retirer.';

  @override
  String get cardInPool => 'Dans le pool';

  @override
  String get cardFromSource => 'Issue d\'une extension ou d\'un cube du pool';

  @override
  String get viewList => 'Liste';

  @override
  String get viewGallery => 'Galerie';

  @override
  String get viewStacks => 'Piles';

  @override
  String get viewSpoiler => 'Spoiler';

  @override
  String get facetTag => 'Étiquette';

  @override
  String get metricTags => 'Étiquettes';

  @override
  String get boosterComposition => 'Composition du booster';

  @override
  String slotRow(int count, String tag) {
    return '$count × $tag';
  }

  @override
  String slotCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes',
      one: '1 carte',
      zero: 'aucune carte',
    );
    return '$_temp0';
  }

  @override
  String get slotLocked => 'Emplacement de l\'extension';

  @override
  String get addSlot => 'Ajouter un emplacement';

  @override
  String get slotPullsFrom => 'Tirer parmi';

  @override
  String get slotCount => 'Cartes par booster';

  @override
  String get poolTags => 'Étiquettes';

  @override
  String get newTag => 'Nouvelle étiquette';

  @override
  String get tagName => 'Nom de l\'étiquette';

  @override
  String get deleteTag => 'Supprimer l\'étiquette';

  @override
  String get tagCardsAction => 'Étiqueter des cartes';

  @override
  String taggingTitle(String tag) {
    return 'Étiquetage : $tag';
  }

  @override
  String get taggingHint =>
      'Touchez les cartes pour ajouter ou retirer l\'étiquette. Vert : ajoutée, rouge : retirée, bleu : conservée, gris : sans étiquette.';

  @override
  String get cardTags => 'Étiquettes de cette carte';

  @override
  String get noTags =>
      'Aucune étiquette pour l\'instant. Les étiquettes regroupent des cartes pour vos propres emplacements de booster.';

  @override
  String get userSlots => 'Vos emplacements';

  @override
  String get noUserSlots =>
      'Aucun emplacement à vous pour l\'instant. Un emplacement tire des cartes d\'une ou plusieurs étiquettes, chacune avec sa probabilité.';

  @override
  String get editSlot => 'Modifier l\'emplacement';

  @override
  String get deleteSlot => 'Supprimer l\'emplacement';

  @override
  String get slotOptions => 'Tirer parmi (au hasard)';

  @override
  String get addOption => 'Ajouter une option';

  @override
  String get editComposition => 'Modifier la composition';

  @override
  String get groupBy => 'Grouper par';

  @override
  String get groupNone => 'Sans regroupement';

  @override
  String get thenBy => 'Puis par';

  @override
  String get setTags => 'Étiquettes de l\'extension';

  @override
  String get resetTag => 'Rétablir l\'extension';

  @override
  String get noTagGroup => 'Sans étiquette';

  @override
  String deleteTagTitle(String tag) {
    return 'Supprimer l\'étiquette $tag ?';
  }

  @override
  String get deleteTagAffects =>
      'Ces emplacements de booster en tirent des cartes et vont changer :';

  @override
  String get prefillFrom => 'Préremplir à nouveau';

  @override
  String get prefillHint =>
      'Remplace toutes les étiquettes et tous les emplacements par le booster d\'une extension ou des boosters aléatoires. Vos étiquettes et emplacements sont perdus.';

  @override
  String get prefillTitle => 'Remplacer les étiquettes et emplacements ?';

  @override
  String prefillWarning(int slots, int tags) {
    return 'Le pool reçoit $slots emplacements et $tags étiquettes de ce préremplissage ; les actuels sont abandonnés.';
  }

  @override
  String get formats => 'Formats';

  @override
  String get editFormats => 'Formats';

  @override
  String get newFormat => 'Nouveau format';

  @override
  String get formatName => 'Nom du format';

  @override
  String get formatKind => 'Joué en';

  @override
  String get deleteFormat => 'Supprimer le format';

  @override
  String get chooseFormat => 'Choisissez un format';

  @override
  String get rounds => 'Boosters, dans l\'ordre';

  @override
  String get addRound => 'Ajouter un booster';

  @override
  String roundNumber(int number) {
    return 'Booster $number';
  }

  @override
  String get picksPerPass => 'Cartes prises par passage';

  @override
  String get burnPerPass => 'Cartes brûlées par passage';

  @override
  String get seats => 'Joueurs';

  @override
  String get boosterKind => 'Booster';

  @override
  String get boosterKinds => 'Boosters';

  @override
  String get newBooster => 'Nouveau booster';

  @override
  String get boosterName => 'Nom du booster';

  @override
  String get deleteBooster => 'Supprimer le booster';

  @override
  String pickPhase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Prenez $count cartes',
      one: 'Prenez 1 carte',
    );
    return '$_temp0';
  }

  @override
  String burnPhase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Brûlez $count cartes',
      one: 'Brûlez 1 carte',
    );
    return '$_temp0';
  }

  @override
  String formatSummary(String kind, int packs) {
    String _temp0 = intl.Intl.pluralLogic(
      packs,
      locale: localeName,
      other: '$packs boosters',
      one: '1 booster',
    );
    return '$kind · $_temp0';
  }

  @override
  String get cardTextSetting => 'Texte des cartes';

  @override
  String get textModePrinted => 'Tel qu\'imprimé dans l\'extension';

  @override
  String get textModeLatest => 'Dernière version (errata)';

  @override
  String get noCardText => 'Aucun texte disponible pour cette carte.';

  @override
  String textVersionsCount(int count) {
    return '$count versions — touchez-en une pour l\'utiliser pour cette carte';
  }

  @override
  String textVersionNumber(int number) {
    return 'Version $number';
  }

  @override
  String get textVersionLatest => 'Dernière';

  @override
  String get useDefaultVersion => 'Par défaut';

  @override
  String get swapArtwork => 'Changer l\'illustration';

  @override
  String get artworkOwn => 'Illustration d\'origine';

  @override
  String get artworkChosen => 'Choisie';

  @override
  String get noOtherArtwork =>
      'Aucune autre illustration trouvée pour cette carte.';

  @override
  String artworkLoadFailed(String error) {
    return 'Impossible de charger les illustrations : $error';
  }
}
