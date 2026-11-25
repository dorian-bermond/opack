// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Opack';

  @override
  String get chooseGame => 'Choose a game';

  @override
  String get chooseSet => 'Choose a set';

  @override
  String get gameMtg => 'Magic: The Gathering';

  @override
  String get gameYgo => 'Yu-Gi-Oh!';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get pictureLanguage => 'Card pictures language';

  @override
  String get dataLanguage => 'Card names and texts language';

  @override
  String get modeOpen => 'Open a pack';

  @override
  String get modeSealed => 'Sealed';

  @override
  String get modeDraft => 'Draft';

  @override
  String get tapToOpen => 'Tap the pack, or slash across it, to open it';

  @override
  String get revealAll => 'Reveal all';

  @override
  String get openAnother => 'Open another';

  @override
  String get openingModeSetting => 'Pack opening';

  @override
  String get openingGrid => 'Grid: tap each card';

  @override
  String get openingSwipe => 'Stack: swipe card by card';

  @override
  String get swipeToReveal => 'Tap or swipe the card away to see the next one';

  @override
  String cardsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards left',
      one: '1 card left',
    );
    return '$_temp0';
  }

  @override
  String get dealAgain => 'Deal again';

  @override
  String get sealedOrder => 'Reveal order';

  @override
  String get sealedByBooster => 'Booster after booster';

  @override
  String get sealedBySlot => 'Slot after slot';

  @override
  String get sealedByQuality => 'Best cards first';

  @override
  String get newPool => 'New pool';

  @override
  String get sealedPool => 'Sealed pool';

  @override
  String cardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String packsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '1 pack',
    );
    return '$_temp0';
  }

  @override
  String draftHeader(int round, int rounds, int pick) {
    return 'Round $round/$rounds · Pick $pick';
  }

  @override
  String get draftDone => 'Draft complete';

  @override
  String get yourPool => 'Your pool';

  @override
  String get restart => 'Restart';

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityUncommon => 'Uncommon';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityMythic => 'Mythic rare';

  @override
  String get raritySuperRare => 'Super rare';

  @override
  String get rarityUltraRare => 'Ultra rare';

  @override
  String get raritySecretRare => 'Secret rare';

  @override
  String get raritySpecial => 'Special';

  @override
  String get foil => 'Foil';

  @override
  String get searchSets => 'Search a set';

  @override
  String get boosterPlay => 'Play Booster';

  @override
  String get boosterDraft => 'Draft Booster';

  @override
  String get boosterStandard => 'Booster';

  @override
  String get boosterSet => 'Set Booster';

  @override
  String get boosterCollector => 'Collector Booster';

  @override
  String get tabSets => 'Sets';

  @override
  String get tabCubes => 'Cubes';

  @override
  String get importCubeCobra => 'Import from CubeCobra';

  @override
  String get importCubeFile => 'Import a list';

  @override
  String get cubeCobraIdLabel => 'CubeCobra cube ID or link';

  @override
  String get noCubesMtg =>
      'No cube yet. Import one from CubeCobra with its ID (e.g. \"vintage\"); it is then stored on this device and playable offline.';

  @override
  String get noCubesYgo =>
      'No cube yet. Import a .ydk file or a text file with one card name per line (French or English).';

  @override
  String cubeImported(String name, int count) {
    return 'Cube \"$name\" imported: $count cards';
  }

  @override
  String unresolvedCards(int count, String examples) {
    return '$count lines not recognized: $examples';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String poolTooSmall(int packs, int packSize, int needed) {
    return 'This pool can deal $packs packs of $packSize cards; this mode needs $needed. Give the limited cards more copies, or make some unlimited.';
  }

  @override
  String get poolOpen => 'Open';

  @override
  String get poolClosed => 'Closed';

  @override
  String get poolCustom => 'Custom';

  @override
  String get poolOpenDescription =>
      'Preset: every card unlimited, as in sealed boosters';

  @override
  String get poolClosedDescription =>
      'Preset: every card a set number of times, as in a cube. Each slot draws from the copies left, so the scarcest slot limits the packs';

  @override
  String copiesPerCard(int count) {
    return '$count × each card';
  }

  @override
  String get editPool => 'Edit';

  @override
  String get tabPools => 'Pools';

  @override
  String get createPool => 'Create a pool';

  @override
  String get noPools =>
      'No pool yet. A pool is the card list you open packs, play sealed and draft from: start one empty, from a set or from a cube, then shape it in its editor.';

  @override
  String get poolEmpty => 'Empty pool';

  @override
  String get poolFromSet => 'From a set';

  @override
  String get poolFromCube => 'From a cube';

  @override
  String get poolNoSources => 'No cards yet';

  @override
  String get poolEmptyHint =>
      'This pool has no cards yet. Edit it to add a set or a cube.';

  @override
  String packsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs left',
      one: '1 pack left',
    );
    return '$_temp0';
  }

  @override
  String get duplicatePool => 'Duplicate';

  @override
  String get deletePool => 'Delete pool';

  @override
  String copyOf(String name) {
    return '$name (copy)';
  }

  @override
  String get renamePool => 'Rename';

  @override
  String get apply => 'Apply';

  @override
  String get addSource => 'Add a set or cube';

  @override
  String get poolSources => 'Cards from';

  @override
  String get packLayout => 'Pack layout';

  @override
  String get poolCopies => 'Copies';

  @override
  String get randomPacks => 'Random packs';

  @override
  String cardsPerPack(int count) {
    return '$count cards per pack';
  }

  @override
  String cardsUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards fit no slot',
      one: '1 card fits no slot',
    );
    return '$_temp0';
  }

  @override
  String presetDropsChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This preset resets the $count cards you changed.',
      one: 'This preset resets the card you changed.',
    );
    return '$_temp0';
  }

  @override
  String get resetCards => 'Reset every card to the preset';

  @override
  String get packsUnlimited => 'Unlimited packs';

  @override
  String packsAvailable(int count, int packSize) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count packs',
      one: '1 pack',
    );
    return '$_temp0 of $packSize cards available';
  }

  @override
  String cardsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards changed',
      one: '1 card changed',
    );
    return '$_temp0';
  }

  @override
  String get searchCards => 'Search cards';

  @override
  String listedTimes(int count) {
    return 'listed $count ×';
  }

  @override
  String get unlimitedCopies => 'Unlimited copies';

  @override
  String copiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: '1 copy',
      zero: 'Left out',
    );
    return '$_temp0';
  }

  @override
  String get deleteCube => 'Delete cube';

  @override
  String get cancel => 'Cancel';

  @override
  String get import => 'Import';

  @override
  String get settings => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsCards => 'Cards';

  @override
  String get settingsOpening => 'Opening';

  @override
  String get ygoKindsSection => 'Frames';

  @override
  String get ygoNormalEffectSetting => 'Tell monster frames apart';

  @override
  String get ygoNormalEffectHint =>
      'When sorting, grouping or filtering by frame, monsters split into normal, effect, ritual, fusion, synchro, xyz and link monsters.';

  @override
  String get kindRitual => 'Ritual monster';

  @override
  String get kindFusion => 'Fusion monster';

  @override
  String get kindSynchro => 'Synchro monster';

  @override
  String get kindXyz => 'Xyz monster';

  @override
  String get kindLink => 'Link monster';

  @override
  String get kindNormal => 'Normal monster';

  @override
  String get kindEffect => 'Effect monster';

  @override
  String get languagesSection => 'Languages';

  @override
  String get cardImagesSetting => 'Card pictures';

  @override
  String get cardImagesOnline => 'Download when online';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortName => 'Name';

  @override
  String get sortRarity => 'Rarity';

  @override
  String get sortManaValue => 'Mana value';

  @override
  String get sortColor => 'Color';

  @override
  String get sortType => 'Type';

  @override
  String get sortPower => 'Power';

  @override
  String get sortToughness => 'Toughness';

  @override
  String get sortCollector => 'Collector number';

  @override
  String get sortLevel => 'Level / Rank';

  @override
  String get sortAtk => 'ATK';

  @override
  String get sortDef => 'DEF';

  @override
  String get sortAttribute => 'Attribute';

  @override
  String get sortRace => 'Type';

  @override
  String get sortFrame => 'Frame';

  @override
  String get sortArchetype => 'Archetype';

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get poolStats => 'Statistics';

  @override
  String cardsShown(int shown, int total) {
    return '$shown of $total cards';
  }

  @override
  String cardDataMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards without details',
      one: '1 card without details',
    );
    return '$_temp0';
  }

  @override
  String get fetchCardData => 'Download card details';

  @override
  String get fetchingCardData => 'Downloading card details…';

  @override
  String get fetchCardDataFailed =>
      'Download failed. Check the connection and try again.';

  @override
  String averageValue(String value) {
    return 'Average $value';
  }

  @override
  String highestValue(String value) {
    return 'Highest $value';
  }

  @override
  String knownOf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards with a value',
      one: '1 card with a value',
    );
    return '$_temp0';
  }

  @override
  String get facetRarity => 'Rarity';

  @override
  String get facetColor => 'Color';

  @override
  String get facetColorIdentity => 'Color identity';

  @override
  String get facetType => 'Type';

  @override
  String get facetSubtype => 'Subtype';

  @override
  String get facetKeyword => 'Keyword';

  @override
  String get facetManaValue => 'Mana value';

  @override
  String get facetSet => 'Set';

  @override
  String get facetKind => 'Frame';

  @override
  String get facetCategory => 'Monster category';

  @override
  String get facetAttribute => 'Attribute';

  @override
  String get facetRace => 'Type';

  @override
  String get facetProperty => 'Spell / Trap property';

  @override
  String get facetArchetype => 'Archetype';

  @override
  String get facetLevel => 'Level / Rank';

  @override
  String get facetLinkRating => 'Link rating';

  @override
  String get facetAtk => 'ATK';

  @override
  String get facetDef => 'DEF';

  @override
  String get metricManaCurve => 'Mana curve';

  @override
  String get metricColors => 'Colors';

  @override
  String get metricColorIdentity => 'Color identity';

  @override
  String get metricColorCount => 'Mono, multi, colorless';

  @override
  String get metricDevotion => 'Devotion (colored mana symbols)';

  @override
  String get metricTypes => 'Card types';

  @override
  String get metricSubtypes => 'Top subtypes';

  @override
  String get metricKeywords => 'Top keywords';

  @override
  String get metricCreatureSize => 'Creature sizes (power/toughness)';

  @override
  String get metricRarity => 'Rarity';

  @override
  String get metricFoil => 'Foil';

  @override
  String get metricSets => 'Sets';

  @override
  String get metricKind => 'Frames';

  @override
  String get metricCategories => 'Monster categories';

  @override
  String get metricLevels => 'Levels';

  @override
  String get metricRanks => 'Ranks';

  @override
  String get metricLinkRatings => 'Link ratings';

  @override
  String get metricAttributes => 'Attributes';

  @override
  String get metricRaces => 'Types';

  @override
  String get metricAtk => 'ATK';

  @override
  String get metricDef => 'DEF';

  @override
  String get metricArchetypes => 'Top archetypes';

  @override
  String get metricProperties => 'Spell and Trap properties';

  @override
  String get colorWhite => 'White';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorRed => 'Red';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorless => 'Colorless';

  @override
  String get monoColored => 'Monocolored';

  @override
  String get multiColored => 'Multicolored';

  @override
  String get kindMonster => 'Monster';

  @override
  String get kindSpell => 'Spell';

  @override
  String get kindTrap => 'Trap';

  @override
  String get noArchetype => 'No archetype';

  @override
  String get nonFoil => 'Non-foil';

  @override
  String get advancedSearch => 'Advanced search';

  @override
  String pickedCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count picked cards',
      one: '1 picked card',
    );
    return '$_temp0';
  }

  @override
  String get searchOnline => 'Search cards online';

  @override
  String get searchHint => 'Name or text';

  @override
  String get searchButton => 'Search';

  @override
  String get noResults => 'No card found.';

  @override
  String get moreResults => 'More results exist: refine the search.';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'Nothing selected',
    );
    return '$_temp0';
  }

  @override
  String get addSelected => 'Add to the pool';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get slotName => 'Slot name (optional)';

  @override
  String get boosterPicture => 'Booster picture';

  @override
  String get oddPictureTitle => 'Not shaped like a pack';

  @override
  String get oddPictureBody =>
      'This picture does not have the usual proportions of a booster pack. Use it as it is, or print it on a plain pack under the pool\'s name?';

  @override
  String get useAnyway => 'Use it anyway';

  @override
  String get printOnPack => 'Print it on a pack';

  @override
  String get tabPool => 'Pool';

  @override
  String get tabBooster => 'Booster';

  @override
  String get tabTransfer => 'Import / export';

  @override
  String get editCard => 'Edit the card';

  @override
  String get editCardHint =>
      'Change any field for this pool; the original stays and comes back on demand.';

  @override
  String get customField => 'Custom';

  @override
  String revertField(String value) {
    return 'Back to the original: $value';
  }

  @override
  String get fieldEmpty => '(none)';

  @override
  String noTextInLanguage(String wanted, String shown) {
    return 'No $wanted text: the $shown one is shown.';
  }

  @override
  String get markerQualitySetting => 'Card marker colored by';

  @override
  String get exportPool => 'Export to a file';

  @override
  String get exportPoolHint =>
      'Saves the pool\'s sources, tags, boosters, formats, copies and chosen artworks to a file to bring elsewhere. A picture of your own stays on this device.';

  @override
  String get exportPoolDone => 'Pool exported';

  @override
  String get importPool => 'Import from a file';

  @override
  String get importPoolHint =>
      'Replaces this pool with the file\'s content, its name included. The pool keeps its place in the list.';

  @override
  String importPoolConfirm(String name) {
    return 'Replace this pool with \"$name\"?';
  }

  @override
  String importPoolWrongGame(String game) {
    return 'This file holds a $game pool.';
  }

  @override
  String get importPoolInvalid => 'This is not an Opack pool file.';

  @override
  String get boosterPictureHint =>
      'The pack shown when opening: the set\'s own picture, or one of yours.';

  @override
  String get choosePicture => 'Choose a picture';

  @override
  String get removePicture => 'Back to the set\'s picture';

  @override
  String get rarityColorsSetting => 'Rarity colors';

  @override
  String get rarityColorsHint =>
      'The color of each rarity\'s marker and tier. Tap one to change it.';

  @override
  String get colorDefault => 'Default';

  @override
  String get colorReset => 'Back to the default color';

  @override
  String get gameOpc => 'One Piece Card Game';

  @override
  String get rarityLeader => 'Leader';

  @override
  String get rarityParallel => 'Parallel art';

  @override
  String get rarityManga => 'Manga art';

  @override
  String get rarityTreasure => 'Treasure rare';

  @override
  String get facetPrintedRarity => 'Printed rarity';

  @override
  String get noCubesOpc =>
      'No cube yet. Import a text file with one card per line, by name or by code (e.g. \"OP01-001\").';

  @override
  String get facetCost => 'Cost';

  @override
  String get facetCounter => 'Counter';

  @override
  String get metricCostCurve => 'Cost curve';

  @override
  String get metricPower => 'Power';

  @override
  String get metricCounters => 'Counters';

  @override
  String get metricLife => 'Leader life';

  @override
  String get groupWhichQuality => 'Group by which quality?';

  @override
  String get allQualities => 'Every quality';

  @override
  String get noQualityGroup => 'Without quality value';

  @override
  String get valueCopies => 'Copies of each card holding this value';

  @override
  String get valueCopiesHint =>
      '× sets how many copies of each card with that value the pool holds (—: the pool\'s own count, ∞: unlimited). A card\'s own count still wins.';

  @override
  String get batchImport => 'Batch import';

  @override
  String get batchImportHint =>
      'Paste a list, one card per line (\"1 Name\" or just \"Name\"). Each line is looked up online; the card named exactly like it wins, else the first match.';

  @override
  String get batchLookUp => 'Look up';

  @override
  String batchFound(int found, int unknown) {
    String _temp0 = intl.Intl.pluralLogic(
      found,
      locale: localeName,
      other: '$found cards found',
      one: '1 card found',
      zero: 'No card found',
    );
    String _temp1 = intl.Intl.pluralLogic(
      unknown,
      locale: localeName,
      other: '$unknown lines unmatched',
      one: '1 line unmatched',
      zero: 'every line matched',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get batchTags => 'Tags for the whole batch';

  @override
  String get batchTagsHint =>
      'Every imported card gets each tag ticked; type a name to make a new one.';

  @override
  String get batchAdd => 'Add to the pool';

  @override
  String get cardSpacing => 'Card spacing';

  @override
  String get editQualityTitle => 'Edit the quality';

  @override
  String get deleteQuality => 'Delete the quality';

  @override
  String deleteQualityTitle(String quality) {
    return 'Delete the quality $quality?';
  }

  @override
  String get deleteQualityAffects =>
      'Every value goes, and the cards lose them. Booster slots pulling from a value lose that option.';

  @override
  String get deleteValue => 'Delete the value';

  @override
  String get qualityValuesHintAscending =>
      'Lowest first, the order they will show in.';

  @override
  String get qualityOrder => 'Value order';

  @override
  String get orderDescending => 'Best first';

  @override
  String get orderAscending => 'Lowest first';

  @override
  String get rarityMarkerSetting => 'Rarity marker';

  @override
  String get rarityMarkerNone => 'None';

  @override
  String get rarityMarkerBorder => 'Colored border';

  @override
  String get rarityMarkerDot => 'Small dot at the bottom';

  @override
  String get tagsHint =>
      'A tag is a yes/no trait, like having facial hair: a card carries any number of tags.';

  @override
  String get qualitiesTitle => 'Qualities';

  @override
  String get qualitiesHint =>
      'A quality is a trait with one value among several, like hair color: a card holds one value of it, or none. Values are ranked, best first, each with a color.';

  @override
  String get addValue => 'Add a value';

  @override
  String get valueName => 'Value';

  @override
  String get valueColor => 'Color';

  @override
  String get hoverPreviewSizeSetting => 'Card hover preview';

  @override
  String get hoverPreviewNone => 'No preview';

  @override
  String get copiesBadgeSetting => 'Copies badge on card pictures';

  @override
  String get copiesBadgeNone => 'Never';

  @override
  String get copiesBadgeChanged => 'Only on cards set apart from the preset';

  @override
  String get copiesBadgeAlways => 'Always';

  @override
  String get hoverPreviewNormal => 'Beside the pointer';

  @override
  String get hoverPreviewLarge => 'Beside the pointer, larger';

  @override
  String get hoverPreviewFullscreen => 'Full window';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get cardSize => 'Card size';

  @override
  String get newQualityTitle => 'Add a quality';

  @override
  String get newQualityHint =>
      'A quality is a set of exclusive values a card can hold one of, like a rarity. Its values are ranked, best first.';

  @override
  String get qualityName => 'Quality name';

  @override
  String get qualityValues => 'Values';

  @override
  String get qualityValuesHint => 'One per line, best first.';

  @override
  String get tierlist => 'Tierlist';

  @override
  String get tierlistQuality => 'Quality';

  @override
  String get tierlistGroup => 'Cards';

  @override
  String get allCards => 'All cards';

  @override
  String get newQuality => 'New quality…';

  @override
  String get noQualityYet => 'none';

  @override
  String get tierlistNoQuality =>
      'Pick a quality to sort the cards by, or create one: each of its values becomes a tier.';

  @override
  String get addTier => 'Add a tier';

  @override
  String get tierlistFeedHint =>
      'Drag a card to a tier to give it that value; drop it here to take the value away. Ctrl+Z undoes.';

  @override
  String get tagQuality => 'Quality (optional)';

  @override
  String get tagQualityHint =>
      'Tags of one quality are exclusive: a card holds only one, like a rarity.';

  @override
  String get qualityHint =>
      'Tags of one quality are exclusive: giving a card one takes the others away.';

  @override
  String get plainTags => 'Other tags';

  @override
  String get tagBaskets => 'Tag baskets';

  @override
  String get basketsHint =>
      'Drag a card onto a basket to give it that tag. Ctrl+Z undoes the last drop.';

  @override
  String get undo => 'Undo';

  @override
  String get cardsPerRow => 'Per row';

  @override
  String get columnsAuto => 'auto';

  @override
  String get fewerPerRow => 'Fewer cards per row';

  @override
  String get morePerRow => 'More cards per row';

  @override
  String get poolDetails => 'Pool details';

  @override
  String get tagChipHint => 'Tap a tag to pick its cards in the editor.';

  @override
  String get searchPanel => 'Search cards to add';

  @override
  String get searchPanelHint =>
      'Tap a card to add it to the pool; tap it again to take it out.';

  @override
  String get cardInPool => 'In the pool';

  @override
  String get cardFromSource => 'From a set or cube of the pool';

  @override
  String get viewList => 'List';

  @override
  String get viewGallery => 'Gallery';

  @override
  String get viewStacks => 'Stacks';

  @override
  String get viewSpoiler => 'Spoiler';

  @override
  String get facetTag => 'Tag';

  @override
  String get metricTags => 'Tags';

  @override
  String get boosterComposition => 'Booster composition';

  @override
  String get bestVersions => 'Deal the most valuable versions';

  @override
  String get bestVersionsHint =>
      'Every card pulled is replaced by the rarest version of the same card in the pool';

  @override
  String slotRow(int count, String tag) {
    return '$count × $tag';
  }

  @override
  String slotCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
      zero: 'no card',
    );
    return '$_temp0';
  }

  @override
  String get slotLocked => 'Set slot';

  @override
  String get addSlot => 'Add a slot';

  @override
  String get slotPullsFrom => 'Pull from';

  @override
  String get slotCount => 'Cards per pack';

  @override
  String get poolTags => 'Tags';

  @override
  String get newTag => 'New tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String get tagCardsAction => 'Tag cards';

  @override
  String taggingTitle(String tag) {
    return 'Tagging: $tag';
  }

  @override
  String get taggingHint =>
      'Tap cards to toggle the tag. Green: added, red: removed, blue: kept, grey: not tagged.';

  @override
  String get cardTags => 'Tags of this card';

  @override
  String get noTags =>
      'No tag yet. Tags group cards for your own booster slots.';

  @override
  String get userSlots => 'Your slots';

  @override
  String get noUserSlots =>
      'No slot of yours yet. A slot pulls cards from one or more tags, each with its chance.';

  @override
  String get editSlot => 'Edit slot';

  @override
  String get deleteSlot => 'Delete slot';

  @override
  String get slotOptions => 'Pull from (by chance)';

  @override
  String get addOption => 'Add an option';

  @override
  String get editComposition => 'Edit composition';

  @override
  String get groupBy => 'Group by';

  @override
  String get viewOptions => 'Sort, grouping and filters';

  @override
  String get sizeOptions => 'Card size and spacing';

  @override
  String filtersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters',
      one: '1 filter',
    );
    return '$_temp0';
  }

  @override
  String get close => 'Close';

  @override
  String get groupNone => 'No grouping';

  @override
  String get thenBy => 'Then by';

  @override
  String get setTags => 'Layout tags';

  @override
  String get resetTag => 'Reset to the layout';

  @override
  String get noTagGroup => 'Without tag';

  @override
  String deleteTagTitle(String tag) {
    return 'Delete the tag $tag?';
  }

  @override
  String get deleteTagAffects =>
      'These booster slots pull from it and will change:';

  @override
  String get prefillFrom => 'Prefill again';

  @override
  String get prefillHint =>
      'Replaces every tag and slot with a set\'s booster or random packs. Your own tags and slots are lost.';

  @override
  String get prefillTitle => 'Replace tags and slots?';

  @override
  String prefillWarning(int slots, int tags) {
    return 'The pool gets $slots slots and $tags tags from this prefill; the current ones are discarded.';
  }

  @override
  String get formats => 'Formats';

  @override
  String get editFormats => 'Formats';

  @override
  String get newFormat => 'New format';

  @override
  String get formatName => 'Format name';

  @override
  String get formatKind => 'Played as';

  @override
  String get deleteFormat => 'Delete format';

  @override
  String get chooseFormat => 'Choose a format';

  @override
  String get rounds => 'Packs, in order';

  @override
  String get addRound => 'Add a pack';

  @override
  String roundNumber(int number) {
    return 'Pack $number';
  }

  @override
  String get picksPerPass => 'Picks per pass';

  @override
  String get burnPerPass => 'Burn per pass';

  @override
  String get seats => 'Players';

  @override
  String get boosterKind => 'Booster';

  @override
  String get boosterKinds => 'Boosters';

  @override
  String get newBooster => 'New booster';

  @override
  String get boosterName => 'Booster name';

  @override
  String get deleteBooster => 'Delete booster';

  @override
  String pickPhase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pick $count cards',
      one: 'Pick 1 card',
    );
    return '$_temp0';
  }

  @override
  String burnPhase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Burn $count cards',
      one: 'Burn 1 card',
    );
    return '$_temp0';
  }

  @override
  String formatSummary(String kind, int packs) {
    String _temp0 = intl.Intl.pluralLogic(
      packs,
      locale: localeName,
      other: '$packs packs',
      one: '1 pack',
    );
    return '$kind · $_temp0';
  }

  @override
  String get cardTextSetting => 'Card text';

  @override
  String get textModePrinted => 'As printed in the set';

  @override
  String get textModeLatest => 'Latest version (errata)';

  @override
  String get noCardText => 'No card text available.';

  @override
  String textVersionsCount(int count) {
    return '$count versions — tap one to use it for this card';
  }

  @override
  String textVersionNumber(int number) {
    return 'Version $number';
  }

  @override
  String get textVersionLatest => 'Latest';

  @override
  String get useDefaultVersion => 'Use default';

  @override
  String get swapArtwork => 'Swap artwork';

  @override
  String get artworkOwn => 'Own artwork';

  @override
  String get artworkChosen => 'Chosen';

  @override
  String get noOtherArtwork => 'No other artwork found for this card.';

  @override
  String artworkLoadFailed(String error) {
    return 'Could not load the artworks: $error';
  }

  @override
  String get selectionCopies => 'Set the copies…';

  @override
  String get selectionTags => 'Edit the tags…';

  @override
  String get selectionDetails => 'Card details';

  @override
  String get selectionAll => 'Select every card shown';

  @override
  String get selectionClear => 'Clear the selection';

  @override
  String get batchTabList => 'List';

  @override
  String get batchTabOptions => 'Options';

  @override
  String get batchQualities => 'Qualities for the whole batch';

  @override
  String get batchQualitiesHint =>
      'Every imported card takes the value picked for a quality, in place of the one it had; none picked leaves the quality alone.';

  @override
  String get batchRarities => 'Import the rarities';

  @override
  String get batchRaritiesHint =>
      'Each card joins the tag of its rarity, so the boosters built on rarities deal it. Off, the cards come in with only the tags and values above.';

  @override
  String get updatesSection => 'Updates';

  @override
  String updateCurrentVersion(String version) {
    return 'Opack $version';
  }

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateUpToDate => 'This is the latest version';

  @override
  String get updateDebugBuild =>
      'A debug build: updates are only looked for by release builds';

  @override
  String get updateChecking => 'Checking…';

  @override
  String updateCheckFailed(String error) {
    return 'Could not check for updates: $error';
  }

  @override
  String get updateCheckNow => 'Check now';

  @override
  String get updateCheckAtLaunch => 'Check for updates when the app starts';

  @override
  String get updateDownload => 'Download';

  @override
  String get updateSkip => 'Skip this version';

  @override
  String updateOpenFailed(String url) {
    return 'Could not open $url';
  }

  @override
  String get updateInstall => 'Install and restart';

  @override
  String updateInstalling(String version) {
    return 'Updating to $version';
  }

  @override
  String get updateDownloading => 'Downloading the update…';

  @override
  String get updateRestarting => 'Restarting the app…';

  @override
  String updateInstallFailed(String error) {
    return 'The update could not be installed: $error. You can download it and replace the app by hand.';
  }
}
