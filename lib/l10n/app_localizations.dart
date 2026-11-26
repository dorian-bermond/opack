import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Opack'**
  String get appTitle;

  /// No description provided for @chooseGame.
  ///
  /// In en, this message translates to:
  /// **'Choose a game'**
  String get chooseGame;

  /// No description provided for @chooseSet.
  ///
  /// In en, this message translates to:
  /// **'Choose a set'**
  String get chooseSet;

  /// No description provided for @gameMtg.
  ///
  /// In en, this message translates to:
  /// **'Magic: The Gathering'**
  String get gameMtg;

  /// No description provided for @gameYgo.
  ///
  /// In en, this message translates to:
  /// **'Yu-Gi-Oh!'**
  String get gameYgo;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @pictureLanguage.
  ///
  /// In en, this message translates to:
  /// **'Card pictures language'**
  String get pictureLanguage;

  /// No description provided for @dataLanguage.
  ///
  /// In en, this message translates to:
  /// **'Card names and texts language'**
  String get dataLanguage;

  /// No description provided for @modeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open a pack'**
  String get modeOpen;

  /// No description provided for @modeSealed.
  ///
  /// In en, this message translates to:
  /// **'Sealed'**
  String get modeSealed;

  /// No description provided for @modeDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get modeDraft;

  /// No description provided for @playTogether.
  ///
  /// In en, this message translates to:
  /// **'Play together'**
  String get playTogether;

  /// No description provided for @joinRoom.
  ///
  /// In en, this message translates to:
  /// **'Join a room'**
  String get joinRoom;

  /// No description provided for @joinAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get joinAgain;

  /// No description provided for @joinRoomHint.
  ///
  /// In en, this message translates to:
  /// **'Someone on the same Wi-Fi hosts the game from a pool and gives you an address and a code.'**
  String get joinRoomHint;

  /// No description provided for @hostRoomHint.
  ///
  /// In en, this message translates to:
  /// **'Others on the same Wi-Fi join with the address and the code shown next; you play from this device too.'**
  String get hostRoomHint;

  /// No description provided for @roomOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Give the players the address and the code. Start once everyone is in; the seats left are bots in a draft.'**
  String get roomOpenHint;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @roomAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get roomAddress;

  /// No description provided for @roomCode.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get roomCode;

  /// No description provided for @noAddress.
  ///
  /// In en, this message translates to:
  /// **'No network address found: is Wi-Fi on?'**
  String get noAddress;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get players;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get you;

  /// No description provided for @bot.
  ///
  /// In en, this message translates to:
  /// **'bot'**
  String get bot;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get disconnected;

  /// No description provided for @seats.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get seats;

  /// No description provided for @seatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seats'**
  String seatsCount(int count);

  /// No description provided for @seatsHint.
  ///
  /// In en, this message translates to:
  /// **'Seats no one takes are played by bots.'**
  String get seatsHint;

  /// No description provided for @openRoom.
  ///
  /// In en, this message translates to:
  /// **'Open the room'**
  String get openRoom;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startGame;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveRoom;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start…'**
  String get waitingForHost;

  /// No description provided for @waitingFor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {names}'**
  String waitingFor(String names);

  /// No description provided for @roomClosed.
  ///
  /// In en, this message translates to:
  /// **'The room closed.'**
  String get roomClosed;

  /// No description provided for @roomTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The pool cannot deal enough packs for this many players.'**
  String get roomTooSmall;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join: {error}'**
  String connectionFailed(String error);

  /// No description provided for @wrongRoomCode.
  ///
  /// In en, this message translates to:
  /// **'wrong room code'**
  String get wrongRoomCode;

  /// No description provided for @roomStarted.
  ///
  /// In en, this message translates to:
  /// **'the game already started'**
  String get roomStarted;

  /// No description provided for @tapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap the pack, or slash across it, to open it'**
  String get tapToOpen;

  /// No description provided for @revealAll.
  ///
  /// In en, this message translates to:
  /// **'Reveal all'**
  String get revealAll;

  /// No description provided for @openAnother.
  ///
  /// In en, this message translates to:
  /// **'Open another'**
  String get openAnother;

  /// No description provided for @openingModeSetting.
  ///
  /// In en, this message translates to:
  /// **'Pack opening'**
  String get openingModeSetting;

  /// No description provided for @openingGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid: tap each card'**
  String get openingGrid;

  /// No description provided for @openingSwipe.
  ///
  /// In en, this message translates to:
  /// **'Stack: swipe card by card'**
  String get openingSwipe;

  /// No description provided for @swipeToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap or swipe the card away to see the next one'**
  String get swipeToReveal;

  /// No description provided for @cardsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card left} other{{count} cards left}}'**
  String cardsLeft(int count);

  /// No description provided for @dealAgain.
  ///
  /// In en, this message translates to:
  /// **'Deal again'**
  String get dealAgain;

  /// No description provided for @sealedOrder.
  ///
  /// In en, this message translates to:
  /// **'Reveal order'**
  String get sealedOrder;

  /// No description provided for @sealedByBooster.
  ///
  /// In en, this message translates to:
  /// **'Booster after booster'**
  String get sealedByBooster;

  /// No description provided for @sealedBySlot.
  ///
  /// In en, this message translates to:
  /// **'Slot after slot'**
  String get sealedBySlot;

  /// No description provided for @sealedByQuality.
  ///
  /// In en, this message translates to:
  /// **'Best cards first'**
  String get sealedByQuality;

  /// No description provided for @newPool.
  ///
  /// In en, this message translates to:
  /// **'New pool'**
  String get newPool;

  /// No description provided for @sealedPool.
  ///
  /// In en, this message translates to:
  /// **'Sealed pool'**
  String get sealedPool;

  /// No description provided for @cardsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String cardsCount(int count);

  /// No description provided for @packsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack} other{{count} packs}}'**
  String packsCount(int count);

  /// No description provided for @draftHeader.
  ///
  /// In en, this message translates to:
  /// **'Round {round}/{rounds} · Pick {pick}'**
  String draftHeader(int round, int rounds, int pick);

  /// No description provided for @draftDone.
  ///
  /// In en, this message translates to:
  /// **'Draft complete'**
  String get draftDone;

  /// No description provided for @yourPool.
  ///
  /// In en, this message translates to:
  /// **'Your pool'**
  String get yourPool;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @rarityCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get rarityCommon;

  /// No description provided for @rarityUncommon.
  ///
  /// In en, this message translates to:
  /// **'Uncommon'**
  String get rarityUncommon;

  /// No description provided for @rarityRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rarityRare;

  /// No description provided for @rarityMythic.
  ///
  /// In en, this message translates to:
  /// **'Mythic rare'**
  String get rarityMythic;

  /// No description provided for @raritySuperRare.
  ///
  /// In en, this message translates to:
  /// **'Super rare'**
  String get raritySuperRare;

  /// No description provided for @rarityUltraRare.
  ///
  /// In en, this message translates to:
  /// **'Ultra rare'**
  String get rarityUltraRare;

  /// No description provided for @raritySecretRare.
  ///
  /// In en, this message translates to:
  /// **'Secret rare'**
  String get raritySecretRare;

  /// No description provided for @raritySpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get raritySpecial;

  /// No description provided for @foil.
  ///
  /// In en, this message translates to:
  /// **'Foil'**
  String get foil;

  /// No description provided for @searchSets.
  ///
  /// In en, this message translates to:
  /// **'Search a set'**
  String get searchSets;

  /// No description provided for @boosterPlay.
  ///
  /// In en, this message translates to:
  /// **'Play Booster'**
  String get boosterPlay;

  /// No description provided for @boosterDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft Booster'**
  String get boosterDraft;

  /// No description provided for @boosterStandard.
  ///
  /// In en, this message translates to:
  /// **'Booster'**
  String get boosterStandard;

  /// No description provided for @boosterSet.
  ///
  /// In en, this message translates to:
  /// **'Set Booster'**
  String get boosterSet;

  /// No description provided for @boosterCollector.
  ///
  /// In en, this message translates to:
  /// **'Collector Booster'**
  String get boosterCollector;

  /// No description provided for @tabSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get tabSets;

  /// No description provided for @tabCubes.
  ///
  /// In en, this message translates to:
  /// **'Cubes'**
  String get tabCubes;

  /// No description provided for @importCubeCobra.
  ///
  /// In en, this message translates to:
  /// **'Import from CubeCobra'**
  String get importCubeCobra;

  /// No description provided for @importCubeFile.
  ///
  /// In en, this message translates to:
  /// **'Import a list'**
  String get importCubeFile;

  /// No description provided for @cubeCobraIdLabel.
  ///
  /// In en, this message translates to:
  /// **'CubeCobra cube ID or link'**
  String get cubeCobraIdLabel;

  /// No description provided for @noCubesMtg.
  ///
  /// In en, this message translates to:
  /// **'No cube yet. Import one from CubeCobra with its ID (e.g. \"vintage\"); it is then stored on this device and playable offline.'**
  String get noCubesMtg;

  /// No description provided for @noCubesYgo.
  ///
  /// In en, this message translates to:
  /// **'No cube yet. Import a .ydk file or a text file with one card name per line (French or English).'**
  String get noCubesYgo;

  /// No description provided for @cubeImported.
  ///
  /// In en, this message translates to:
  /// **'Cube \"{name}\" imported: {count} cards'**
  String cubeImported(String name, int count);

  /// No description provided for @unresolvedCards.
  ///
  /// In en, this message translates to:
  /// **'{count} lines not recognized: {examples}'**
  String unresolvedCards(int count, String examples);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @poolTooSmall.
  ///
  /// In en, this message translates to:
  /// **'This pool can deal {packs} packs of {packSize} cards; this mode needs {needed}. Give the limited cards more copies, or make some unlimited.'**
  String poolTooSmall(int packs, int packSize, int needed);

  /// No description provided for @poolOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get poolOpen;

  /// No description provided for @poolClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get poolClosed;

  /// No description provided for @poolCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get poolCustom;

  /// No description provided for @poolOpenDescription.
  ///
  /// In en, this message translates to:
  /// **'Preset: every card unlimited, as in sealed boosters'**
  String get poolOpenDescription;

  /// No description provided for @poolClosedDescription.
  ///
  /// In en, this message translates to:
  /// **'Preset: every card a set number of times, as in a cube. Each slot draws from the copies left, so the scarcest slot limits the packs'**
  String get poolClosedDescription;

  /// No description provided for @copiesPerCard.
  ///
  /// In en, this message translates to:
  /// **'{count} × each card'**
  String copiesPerCard(int count);

  /// No description provided for @editPool.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editPool;

  /// No description provided for @tabPools.
  ///
  /// In en, this message translates to:
  /// **'Pools'**
  String get tabPools;

  /// No description provided for @createPool.
  ///
  /// In en, this message translates to:
  /// **'Create a pool'**
  String get createPool;

  /// No description provided for @noPools.
  ///
  /// In en, this message translates to:
  /// **'No pool yet. A pool is the card list you open packs, play sealed and draft from: start one empty, from a set or from a cube, then shape it in its editor.'**
  String get noPools;

  /// No description provided for @poolEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty pool'**
  String get poolEmpty;

  /// No description provided for @poolFromSet.
  ///
  /// In en, this message translates to:
  /// **'From a set'**
  String get poolFromSet;

  /// No description provided for @poolFromCube.
  ///
  /// In en, this message translates to:
  /// **'From a cube'**
  String get poolFromCube;

  /// No description provided for @poolNoSources.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get poolNoSources;

  /// No description provided for @poolEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'This pool has no cards yet. Edit it to add a set or a cube.'**
  String get poolEmptyHint;

  /// No description provided for @packsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack left} other{{count} packs left}}'**
  String packsLeft(int count);

  /// No description provided for @duplicatePool.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicatePool;

  /// No description provided for @deletePool.
  ///
  /// In en, this message translates to:
  /// **'Delete pool'**
  String get deletePool;

  /// No description provided for @copyOf.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String copyOf(String name);

  /// No description provided for @renamePool.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renamePool;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @addSource.
  ///
  /// In en, this message translates to:
  /// **'Add a set or cube'**
  String get addSource;

  /// No description provided for @poolSources.
  ///
  /// In en, this message translates to:
  /// **'Cards from'**
  String get poolSources;

  /// No description provided for @packLayout.
  ///
  /// In en, this message translates to:
  /// **'Pack layout'**
  String get packLayout;

  /// No description provided for @poolCopies.
  ///
  /// In en, this message translates to:
  /// **'Copies'**
  String get poolCopies;

  /// No description provided for @copiesByCard.
  ///
  /// In en, this message translates to:
  /// **'Card by card…'**
  String get copiesByCard;

  /// No description provided for @copiesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a card to set its copies.'**
  String get copiesHint;

  /// No description provided for @randomPacks.
  ///
  /// In en, this message translates to:
  /// **'Random packs'**
  String get randomPacks;

  /// No description provided for @cardsPerPack.
  ///
  /// In en, this message translates to:
  /// **'{count} cards per pack'**
  String cardsPerPack(int count);

  /// No description provided for @cardsUnplaced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card fits no slot} other{{count} cards fit no slot}}'**
  String cardsUnplaced(int count);

  /// No description provided for @presetDropsChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This preset resets the card you changed.} other{This preset resets the {count} cards you changed.}}'**
  String presetDropsChanges(int count);

  /// No description provided for @resetCards.
  ///
  /// In en, this message translates to:
  /// **'Reset every card to the preset'**
  String get resetCards;

  /// No description provided for @packsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited packs'**
  String get packsUnlimited;

  /// No description provided for @packsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pack} other{{count} packs}} of {packSize} cards available'**
  String packsAvailable(int count, int packSize);

  /// No description provided for @cardsChanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card changed} other{{count} cards changed}}'**
  String cardsChanged(int count);

  /// No description provided for @searchCards.
  ///
  /// In en, this message translates to:
  /// **'Search cards'**
  String get searchCards;

  /// No description provided for @listedTimes.
  ///
  /// In en, this message translates to:
  /// **'listed {count} ×'**
  String listedTimes(int count);

  /// No description provided for @unlimitedCopies.
  ///
  /// In en, this message translates to:
  /// **'Unlimited copies'**
  String get unlimitedCopies;

  /// No description provided for @copiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Left out} =1{1 copy} other{{count} copies}}'**
  String copiesCount(int count);

  /// No description provided for @deleteCube.
  ///
  /// In en, this message translates to:
  /// **'Delete cube'**
  String get deleteCube;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get settingsCards;

  /// No description provided for @settingsOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get settingsOpening;

  /// No description provided for @ygoKindsSection.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get ygoKindsSection;

  /// No description provided for @ygoNormalEffectSetting.
  ///
  /// In en, this message translates to:
  /// **'Tell monster frames apart'**
  String get ygoNormalEffectSetting;

  /// No description provided for @ygoNormalEffectHint.
  ///
  /// In en, this message translates to:
  /// **'When sorting, grouping or filtering by frame, monsters split into normal, effect, ritual, fusion, synchro, xyz and link monsters.'**
  String get ygoNormalEffectHint;

  /// No description provided for @kindRitual.
  ///
  /// In en, this message translates to:
  /// **'Ritual monster'**
  String get kindRitual;

  /// No description provided for @kindFusion.
  ///
  /// In en, this message translates to:
  /// **'Fusion monster'**
  String get kindFusion;

  /// No description provided for @kindSynchro.
  ///
  /// In en, this message translates to:
  /// **'Synchro monster'**
  String get kindSynchro;

  /// No description provided for @kindXyz.
  ///
  /// In en, this message translates to:
  /// **'Xyz monster'**
  String get kindXyz;

  /// No description provided for @kindLink.
  ///
  /// In en, this message translates to:
  /// **'Link monster'**
  String get kindLink;

  /// No description provided for @kindNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal monster'**
  String get kindNormal;

  /// No description provided for @kindEffect.
  ///
  /// In en, this message translates to:
  /// **'Effect monster'**
  String get kindEffect;

  /// No description provided for @languagesSection.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languagesSection;

  /// No description provided for @cardImagesSetting.
  ///
  /// In en, this message translates to:
  /// **'Card pictures'**
  String get cardImagesSetting;

  /// No description provided for @cardImagesOnline.
  ///
  /// In en, this message translates to:
  /// **'Download when online'**
  String get cardImagesOnline;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get sortRarity;

  /// No description provided for @sortManaValue.
  ///
  /// In en, this message translates to:
  /// **'Mana value'**
  String get sortManaValue;

  /// No description provided for @sortColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get sortColor;

  /// No description provided for @sortType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sortType;

  /// No description provided for @sortPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get sortPower;

  /// No description provided for @sortToughness.
  ///
  /// In en, this message translates to:
  /// **'Toughness'**
  String get sortToughness;

  /// No description provided for @sortCollector.
  ///
  /// In en, this message translates to:
  /// **'Collector number'**
  String get sortCollector;

  /// No description provided for @sortLevel.
  ///
  /// In en, this message translates to:
  /// **'Level / Rank'**
  String get sortLevel;

  /// No description provided for @sortAtk.
  ///
  /// In en, this message translates to:
  /// **'ATK'**
  String get sortAtk;

  /// No description provided for @sortDef.
  ///
  /// In en, this message translates to:
  /// **'DEF'**
  String get sortDef;

  /// No description provided for @sortAttribute.
  ///
  /// In en, this message translates to:
  /// **'Attribute'**
  String get sortAttribute;

  /// No description provided for @sortRace.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sortRace;

  /// No description provided for @sortFrame.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get sortFrame;

  /// No description provided for @sortArchetype.
  ///
  /// In en, this message translates to:
  /// **'Archetype'**
  String get sortArchetype;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @poolStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get poolStats;

  /// No description provided for @cardsShown.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} cards'**
  String cardsShown(int shown, int total);

  /// No description provided for @cardDataMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card without details} other{{count} cards without details}}'**
  String cardDataMissing(int count);

  /// No description provided for @fetchCardData.
  ///
  /// In en, this message translates to:
  /// **'Download card details'**
  String get fetchCardData;

  /// No description provided for @fetchingCardData.
  ///
  /// In en, this message translates to:
  /// **'Downloading card details…'**
  String get fetchingCardData;

  /// No description provided for @fetchCardDataFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check the connection and try again.'**
  String get fetchCardDataFailed;

  /// No description provided for @averageValue.
  ///
  /// In en, this message translates to:
  /// **'Average {value}'**
  String averageValue(String value);

  /// No description provided for @highestValue.
  ///
  /// In en, this message translates to:
  /// **'Highest {value}'**
  String highestValue(String value);

  /// No description provided for @knownOf.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card with a value} other{{count} cards with a value}}'**
  String knownOf(int count);

  /// No description provided for @facetRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get facetRarity;

  /// No description provided for @facetColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get facetColor;

  /// No description provided for @facetColorIdentity.
  ///
  /// In en, this message translates to:
  /// **'Color identity'**
  String get facetColorIdentity;

  /// No description provided for @facetType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get facetType;

  /// No description provided for @facetSubtype.
  ///
  /// In en, this message translates to:
  /// **'Subtype'**
  String get facetSubtype;

  /// No description provided for @facetKeyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get facetKeyword;

  /// No description provided for @facetManaValue.
  ///
  /// In en, this message translates to:
  /// **'Mana value'**
  String get facetManaValue;

  /// No description provided for @facetSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get facetSet;

  /// No description provided for @facetKind.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get facetKind;

  /// No description provided for @facetCategory.
  ///
  /// In en, this message translates to:
  /// **'Monster category'**
  String get facetCategory;

  /// No description provided for @facetAttribute.
  ///
  /// In en, this message translates to:
  /// **'Attribute'**
  String get facetAttribute;

  /// No description provided for @facetRace.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get facetRace;

  /// No description provided for @facetProperty.
  ///
  /// In en, this message translates to:
  /// **'Spell / Trap property'**
  String get facetProperty;

  /// No description provided for @facetArchetype.
  ///
  /// In en, this message translates to:
  /// **'Archetype'**
  String get facetArchetype;

  /// No description provided for @facetLevel.
  ///
  /// In en, this message translates to:
  /// **'Level / Rank'**
  String get facetLevel;

  /// No description provided for @facetLinkRating.
  ///
  /// In en, this message translates to:
  /// **'Link rating'**
  String get facetLinkRating;

  /// No description provided for @facetAtk.
  ///
  /// In en, this message translates to:
  /// **'ATK'**
  String get facetAtk;

  /// No description provided for @facetDef.
  ///
  /// In en, this message translates to:
  /// **'DEF'**
  String get facetDef;

  /// No description provided for @metricManaCurve.
  ///
  /// In en, this message translates to:
  /// **'Mana curve'**
  String get metricManaCurve;

  /// No description provided for @metricColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get metricColors;

  /// No description provided for @metricColorIdentity.
  ///
  /// In en, this message translates to:
  /// **'Color identity'**
  String get metricColorIdentity;

  /// No description provided for @metricColorCount.
  ///
  /// In en, this message translates to:
  /// **'Mono, multi, colorless'**
  String get metricColorCount;

  /// No description provided for @metricDevotion.
  ///
  /// In en, this message translates to:
  /// **'Devotion (colored mana symbols)'**
  String get metricDevotion;

  /// No description provided for @metricTypes.
  ///
  /// In en, this message translates to:
  /// **'Card types'**
  String get metricTypes;

  /// No description provided for @metricSubtypes.
  ///
  /// In en, this message translates to:
  /// **'Top subtypes'**
  String get metricSubtypes;

  /// No description provided for @metricKeywords.
  ///
  /// In en, this message translates to:
  /// **'Top keywords'**
  String get metricKeywords;

  /// No description provided for @metricCreatureSize.
  ///
  /// In en, this message translates to:
  /// **'Creature sizes (power/toughness)'**
  String get metricCreatureSize;

  /// No description provided for @metricRarity.
  ///
  /// In en, this message translates to:
  /// **'Rarity'**
  String get metricRarity;

  /// No description provided for @metricFoil.
  ///
  /// In en, this message translates to:
  /// **'Foil'**
  String get metricFoil;

  /// No description provided for @metricSets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get metricSets;

  /// No description provided for @metricKind.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get metricKind;

  /// No description provided for @metricCategories.
  ///
  /// In en, this message translates to:
  /// **'Monster categories'**
  String get metricCategories;

  /// No description provided for @metricLevels.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get metricLevels;

  /// No description provided for @metricRanks.
  ///
  /// In en, this message translates to:
  /// **'Ranks'**
  String get metricRanks;

  /// No description provided for @metricLinkRatings.
  ///
  /// In en, this message translates to:
  /// **'Link ratings'**
  String get metricLinkRatings;

  /// No description provided for @metricAttributes.
  ///
  /// In en, this message translates to:
  /// **'Attributes'**
  String get metricAttributes;

  /// No description provided for @metricRaces.
  ///
  /// In en, this message translates to:
  /// **'Types'**
  String get metricRaces;

  /// No description provided for @metricAtk.
  ///
  /// In en, this message translates to:
  /// **'ATK'**
  String get metricAtk;

  /// No description provided for @metricDef.
  ///
  /// In en, this message translates to:
  /// **'DEF'**
  String get metricDef;

  /// No description provided for @metricArchetypes.
  ///
  /// In en, this message translates to:
  /// **'Top archetypes'**
  String get metricArchetypes;

  /// No description provided for @metricProperties.
  ///
  /// In en, this message translates to:
  /// **'Spell and Trap properties'**
  String get metricProperties;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorless.
  ///
  /// In en, this message translates to:
  /// **'Colorless'**
  String get colorless;

  /// No description provided for @monoColored.
  ///
  /// In en, this message translates to:
  /// **'Monocolored'**
  String get monoColored;

  /// No description provided for @multiColored.
  ///
  /// In en, this message translates to:
  /// **'Multicolored'**
  String get multiColored;

  /// No description provided for @kindMonster.
  ///
  /// In en, this message translates to:
  /// **'Monster'**
  String get kindMonster;

  /// No description provided for @kindSpell.
  ///
  /// In en, this message translates to:
  /// **'Spell'**
  String get kindSpell;

  /// No description provided for @kindTrap.
  ///
  /// In en, this message translates to:
  /// **'Trap'**
  String get kindTrap;

  /// No description provided for @noArchetype.
  ///
  /// In en, this message translates to:
  /// **'No archetype'**
  String get noArchetype;

  /// No description provided for @nonFoil.
  ///
  /// In en, this message translates to:
  /// **'Non-foil'**
  String get nonFoil;

  /// No description provided for @advancedSearch.
  ///
  /// In en, this message translates to:
  /// **'Advanced search'**
  String get advancedSearch;

  /// No description provided for @pickedCards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 picked card} other{{count} picked cards}}'**
  String pickedCards(int count);

  /// No description provided for @searchOnline.
  ///
  /// In en, this message translates to:
  /// **'Search cards online'**
  String get searchOnline;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Name or text'**
  String get searchHint;

  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No card found.'**
  String get noResults;

  /// No description provided for @moreResults.
  ///
  /// In en, this message translates to:
  /// **'More results exist: refine the search.'**
  String get moreResults;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing selected} =1{1 selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @addSelected.
  ///
  /// In en, this message translates to:
  /// **'Add to the pool'**
  String get addSelected;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(String error);

  /// No description provided for @slotName.
  ///
  /// In en, this message translates to:
  /// **'Slot name (optional)'**
  String get slotName;

  /// No description provided for @boosterPicture.
  ///
  /// In en, this message translates to:
  /// **'Booster picture'**
  String get boosterPicture;

  /// No description provided for @oddPictureTitle.
  ///
  /// In en, this message translates to:
  /// **'Not shaped like a pack'**
  String get oddPictureTitle;

  /// No description provided for @oddPictureBody.
  ///
  /// In en, this message translates to:
  /// **'This picture does not have the usual proportions of a booster pack. Use it as it is, or print it on a plain pack under the pool\'s name?'**
  String get oddPictureBody;

  /// No description provided for @useAnyway.
  ///
  /// In en, this message translates to:
  /// **'Use it anyway'**
  String get useAnyway;

  /// No description provided for @printOnPack.
  ///
  /// In en, this message translates to:
  /// **'Print it on a pack'**
  String get printOnPack;

  /// No description provided for @tabPool.
  ///
  /// In en, this message translates to:
  /// **'Pool'**
  String get tabPool;

  /// No description provided for @tabBooster.
  ///
  /// In en, this message translates to:
  /// **'Booster'**
  String get tabBooster;

  /// No description provided for @tabTransfer.
  ///
  /// In en, this message translates to:
  /// **'Import / export'**
  String get tabTransfer;

  /// No description provided for @editCard.
  ///
  /// In en, this message translates to:
  /// **'Edit the card'**
  String get editCard;

  /// No description provided for @editCardHint.
  ///
  /// In en, this message translates to:
  /// **'Change any field for this pool; the original stays and comes back on demand.'**
  String get editCardHint;

  /// No description provided for @customField.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customField;

  /// No description provided for @revertField.
  ///
  /// In en, this message translates to:
  /// **'Back to the original: {value}'**
  String revertField(String value);

  /// No description provided for @fieldEmpty.
  ///
  /// In en, this message translates to:
  /// **'(none)'**
  String get fieldEmpty;

  /// No description provided for @customOption.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get customOption;

  /// No description provided for @addWord.
  ///
  /// In en, this message translates to:
  /// **'Add…'**
  String get addWord;

  /// No description provided for @typeLine.
  ///
  /// In en, this message translates to:
  /// **'Type line'**
  String get typeLine;

  /// No description provided for @customOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'New {field}'**
  String customOptionTitle(String field);

  /// No description provided for @noTextInLanguage.
  ///
  /// In en, this message translates to:
  /// **'No {wanted} text: the {shown} one is shown.'**
  String noTextInLanguage(String wanted, String shown);

  /// No description provided for @markerQualitySetting.
  ///
  /// In en, this message translates to:
  /// **'Card marker colored by'**
  String get markerQualitySetting;

  /// No description provided for @exportPool.
  ///
  /// In en, this message translates to:
  /// **'Export to a file'**
  String get exportPool;

  /// No description provided for @exportPoolHint.
  ///
  /// In en, this message translates to:
  /// **'Saves the pool\'s sources, tags, boosters, formats, copies and chosen artworks to a file to bring elsewhere. A picture of your own stays on this device.'**
  String get exportPoolHint;

  /// No description provided for @exportPoolDone.
  ///
  /// In en, this message translates to:
  /// **'Pool exported'**
  String get exportPoolDone;

  /// No description provided for @importPool.
  ///
  /// In en, this message translates to:
  /// **'Import from a file'**
  String get importPool;

  /// No description provided for @importPoolHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces this pool with the file\'s content, its name included. The pool keeps its place in the list.'**
  String get importPoolHint;

  /// No description provided for @importPoolConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace this pool with \"{name}\"?'**
  String importPoolConfirm(String name);

  /// No description provided for @importPoolWrongGame.
  ///
  /// In en, this message translates to:
  /// **'This file holds a {game} pool.'**
  String importPoolWrongGame(String game);

  /// No description provided for @importPoolInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not an Opack pool file.'**
  String get importPoolInvalid;

  /// No description provided for @boosterPictureHint.
  ///
  /// In en, this message translates to:
  /// **'The pack shown when opening: the set\'s own picture, or one of yours.'**
  String get boosterPictureHint;

  /// No description provided for @choosePicture.
  ///
  /// In en, this message translates to:
  /// **'Choose a picture'**
  String get choosePicture;

  /// No description provided for @removePicture.
  ///
  /// In en, this message translates to:
  /// **'Back to the set\'s picture'**
  String get removePicture;

  /// No description provided for @rarityColorsSetting.
  ///
  /// In en, this message translates to:
  /// **'Rarity colors'**
  String get rarityColorsSetting;

  /// No description provided for @rarityColorsHint.
  ///
  /// In en, this message translates to:
  /// **'The color of each rarity\'s marker and tier. Tap one to change it.'**
  String get rarityColorsHint;

  /// No description provided for @colorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get colorDefault;

  /// No description provided for @colorReset.
  ///
  /// In en, this message translates to:
  /// **'Back to the default color'**
  String get colorReset;

  /// No description provided for @gameOpc.
  ///
  /// In en, this message translates to:
  /// **'One Piece Card Game'**
  String get gameOpc;

  /// No description provided for @rarityLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get rarityLeader;

  /// No description provided for @rarityParallel.
  ///
  /// In en, this message translates to:
  /// **'Parallel art'**
  String get rarityParallel;

  /// No description provided for @rarityManga.
  ///
  /// In en, this message translates to:
  /// **'Manga art'**
  String get rarityManga;

  /// No description provided for @rarityTreasure.
  ///
  /// In en, this message translates to:
  /// **'Treasure rare'**
  String get rarityTreasure;

  /// No description provided for @facetPrintedRarity.
  ///
  /// In en, this message translates to:
  /// **'Printed rarity'**
  String get facetPrintedRarity;

  /// No description provided for @noCubesOpc.
  ///
  /// In en, this message translates to:
  /// **'No cube yet. Import a text file with one card per line, by name or by code (e.g. \"OP01-001\").'**
  String get noCubesOpc;

  /// No description provided for @facetCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get facetCost;

  /// No description provided for @facetCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get facetCounter;

  /// No description provided for @metricCostCurve.
  ///
  /// In en, this message translates to:
  /// **'Cost curve'**
  String get metricCostCurve;

  /// No description provided for @metricPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get metricPower;

  /// No description provided for @metricCounters.
  ///
  /// In en, this message translates to:
  /// **'Counters'**
  String get metricCounters;

  /// No description provided for @metricLife.
  ///
  /// In en, this message translates to:
  /// **'Leader life'**
  String get metricLife;

  /// No description provided for @groupWhichQuality.
  ///
  /// In en, this message translates to:
  /// **'Group by which quality?'**
  String get groupWhichQuality;

  /// No description provided for @allQualities.
  ///
  /// In en, this message translates to:
  /// **'Every quality'**
  String get allQualities;

  /// No description provided for @noQualityGroup.
  ///
  /// In en, this message translates to:
  /// **'Without quality value'**
  String get noQualityGroup;

  /// No description provided for @valueCopies.
  ///
  /// In en, this message translates to:
  /// **'Copies of each card holding this value'**
  String get valueCopies;

  /// No description provided for @valueCopiesHint.
  ///
  /// In en, this message translates to:
  /// **'× sets how many copies of each card with that value the pool holds (—: the pool\'s own count, ∞: unlimited). A card\'s own count still wins.'**
  String get valueCopiesHint;

  /// No description provided for @batchImport.
  ///
  /// In en, this message translates to:
  /// **'Batch import'**
  String get batchImport;

  /// No description provided for @batchImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a list, one card per line (\"1 Name\" or just \"Name\"). Each line is looked up online; the card named exactly like it wins, else the first match.'**
  String get batchImportHint;

  /// No description provided for @batchLookUp.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get batchLookUp;

  /// No description provided for @batchFound.
  ///
  /// In en, this message translates to:
  /// **'{found, plural, =0{No card found} =1{1 card found} other{{found} cards found}} · {unknown, plural, =0{every line matched} =1{1 line unmatched} other{{unknown} lines unmatched}}'**
  String batchFound(int found, int unknown);

  /// No description provided for @batchTags.
  ///
  /// In en, this message translates to:
  /// **'Tags for the whole batch'**
  String get batchTags;

  /// No description provided for @batchTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Every imported card gets each tag ticked; type a name to make a new one.'**
  String get batchTagsHint;

  /// No description provided for @batchAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to the pool'**
  String get batchAdd;

  /// No description provided for @cardSpacing.
  ///
  /// In en, this message translates to:
  /// **'Card spacing'**
  String get cardSpacing;

  /// No description provided for @editQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit the quality'**
  String get editQualityTitle;

  /// No description provided for @deleteQuality.
  ///
  /// In en, this message translates to:
  /// **'Delete the quality'**
  String get deleteQuality;

  /// No description provided for @deleteQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the quality {quality}?'**
  String deleteQualityTitle(String quality);

  /// No description provided for @deleteQualityAffects.
  ///
  /// In en, this message translates to:
  /// **'Every value goes, and the cards lose them. Booster slots pulling from a value lose that option.'**
  String get deleteQualityAffects;

  /// No description provided for @deleteValue.
  ///
  /// In en, this message translates to:
  /// **'Delete the value'**
  String get deleteValue;

  /// No description provided for @qualityValuesHintAscending.
  ///
  /// In en, this message translates to:
  /// **'Lowest first, the order they will show in.'**
  String get qualityValuesHintAscending;

  /// No description provided for @qualityOrder.
  ///
  /// In en, this message translates to:
  /// **'Value order'**
  String get qualityOrder;

  /// No description provided for @orderDescending.
  ///
  /// In en, this message translates to:
  /// **'Best first'**
  String get orderDescending;

  /// No description provided for @orderAscending.
  ///
  /// In en, this message translates to:
  /// **'Lowest first'**
  String get orderAscending;

  /// No description provided for @rarityMarkerSetting.
  ///
  /// In en, this message translates to:
  /// **'Rarity marker'**
  String get rarityMarkerSetting;

  /// No description provided for @rarityMarkerNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get rarityMarkerNone;

  /// No description provided for @rarityMarkerBorder.
  ///
  /// In en, this message translates to:
  /// **'Colored border'**
  String get rarityMarkerBorder;

  /// No description provided for @rarityMarkerDot.
  ///
  /// In en, this message translates to:
  /// **'Small dot at the bottom'**
  String get rarityMarkerDot;

  /// No description provided for @tagsHint.
  ///
  /// In en, this message translates to:
  /// **'A tag is a yes/no trait, like having facial hair: a card carries any number of tags.'**
  String get tagsHint;

  /// No description provided for @qualitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Qualities'**
  String get qualitiesTitle;

  /// No description provided for @qualitiesHint.
  ///
  /// In en, this message translates to:
  /// **'A quality is a trait with one value among several, like hair color: a card holds one value of it, or none. Values are ranked, best first, each with a color.'**
  String get qualitiesHint;

  /// No description provided for @addValue.
  ///
  /// In en, this message translates to:
  /// **'Add a value'**
  String get addValue;

  /// No description provided for @valueName.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueName;

  /// No description provided for @valueColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get valueColor;

  /// No description provided for @hoverPreviewSizeSetting.
  ///
  /// In en, this message translates to:
  /// **'Card hover preview'**
  String get hoverPreviewSizeSetting;

  /// No description provided for @hoverPreviewNone.
  ///
  /// In en, this message translates to:
  /// **'No preview'**
  String get hoverPreviewNone;

  /// No description provided for @copiesBadgeSetting.
  ///
  /// In en, this message translates to:
  /// **'Copies badge on card pictures'**
  String get copiesBadgeSetting;

  /// No description provided for @copiesBadgeNone.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get copiesBadgeNone;

  /// No description provided for @copiesBadgeChanged.
  ///
  /// In en, this message translates to:
  /// **'Only on cards set apart from the preset'**
  String get copiesBadgeChanged;

  /// No description provided for @copiesBadgeAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get copiesBadgeAlways;

  /// No description provided for @hoverPreviewNormal.
  ///
  /// In en, this message translates to:
  /// **'Beside the pointer'**
  String get hoverPreviewNormal;

  /// No description provided for @hoverPreviewLarge.
  ///
  /// In en, this message translates to:
  /// **'Beside the pointer, larger'**
  String get hoverPreviewLarge;

  /// No description provided for @hoverPreviewFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full window'**
  String get hoverPreviewFullscreen;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @cardSize.
  ///
  /// In en, this message translates to:
  /// **'Card size'**
  String get cardSize;

  /// No description provided for @newQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a quality'**
  String get newQualityTitle;

  /// No description provided for @newQualityHint.
  ///
  /// In en, this message translates to:
  /// **'A quality is a set of exclusive values a card can hold one of, like a rarity. Its values are ranked, best first.'**
  String get newQualityHint;

  /// No description provided for @qualityName.
  ///
  /// In en, this message translates to:
  /// **'Quality name'**
  String get qualityName;

  /// No description provided for @qualityValues.
  ///
  /// In en, this message translates to:
  /// **'Values'**
  String get qualityValues;

  /// No description provided for @qualityValuesHint.
  ///
  /// In en, this message translates to:
  /// **'One per line, best first.'**
  String get qualityValuesHint;

  /// No description provided for @tierlist.
  ///
  /// In en, this message translates to:
  /// **'Tierlist'**
  String get tierlist;

  /// No description provided for @tierlistQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get tierlistQuality;

  /// No description provided for @tierlistGroup.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get tierlistGroup;

  /// No description provided for @allCards.
  ///
  /// In en, this message translates to:
  /// **'All cards'**
  String get allCards;

  /// No description provided for @newQuality.
  ///
  /// In en, this message translates to:
  /// **'New quality…'**
  String get newQuality;

  /// No description provided for @noQualityYet.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get noQualityYet;

  /// No description provided for @tierlistNoQuality.
  ///
  /// In en, this message translates to:
  /// **'Pick a quality to sort the cards by, or create one: each of its values becomes a tier.'**
  String get tierlistNoQuality;

  /// No description provided for @addTier.
  ///
  /// In en, this message translates to:
  /// **'Add a tier'**
  String get addTier;

  /// No description provided for @tierlistFeedHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a card to a tier to give it that value; drop it here to take the value away. Ctrl+Z undoes.'**
  String get tierlistFeedHint;

  /// No description provided for @tagQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality (optional)'**
  String get tagQuality;

  /// No description provided for @tagQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Tags of one quality are exclusive: a card holds only one, like a rarity.'**
  String get tagQualityHint;

  /// No description provided for @qualityHint.
  ///
  /// In en, this message translates to:
  /// **'Tags of one quality are exclusive: giving a card one takes the others away.'**
  String get qualityHint;

  /// No description provided for @plainTags.
  ///
  /// In en, this message translates to:
  /// **'Other tags'**
  String get plainTags;

  /// No description provided for @tagBaskets.
  ///
  /// In en, this message translates to:
  /// **'Tag baskets'**
  String get tagBaskets;

  /// No description provided for @basketsHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a card onto a basket to give it that tag. Ctrl+Z undoes the last drop.'**
  String get basketsHint;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @cardsPerRow.
  ///
  /// In en, this message translates to:
  /// **'Per row'**
  String get cardsPerRow;

  /// No description provided for @columnsAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get columnsAuto;

  /// No description provided for @fewerPerRow.
  ///
  /// In en, this message translates to:
  /// **'Fewer cards per row'**
  String get fewerPerRow;

  /// No description provided for @morePerRow.
  ///
  /// In en, this message translates to:
  /// **'More cards per row'**
  String get morePerRow;

  /// No description provided for @poolDetails.
  ///
  /// In en, this message translates to:
  /// **'Pool details'**
  String get poolDetails;

  /// No description provided for @tagChipHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a tag to pick its cards in the editor.'**
  String get tagChipHint;

  /// No description provided for @searchPanel.
  ///
  /// In en, this message translates to:
  /// **'Search cards to add'**
  String get searchPanel;

  /// No description provided for @searchPanelHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a card to add it to the pool; tap it again to take it out.'**
  String get searchPanelHint;

  /// No description provided for @cardInPool.
  ///
  /// In en, this message translates to:
  /// **'In the pool'**
  String get cardInPool;

  /// No description provided for @cardFromSource.
  ///
  /// In en, this message translates to:
  /// **'From a set or cube of the pool'**
  String get cardFromSource;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get viewGallery;

  /// No description provided for @viewStacks.
  ///
  /// In en, this message translates to:
  /// **'Stacks'**
  String get viewStacks;

  /// No description provided for @viewSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get viewSpoiler;

  /// No description provided for @facetTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get facetTag;

  /// No description provided for @metricTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get metricTags;

  /// No description provided for @boosterComposition.
  ///
  /// In en, this message translates to:
  /// **'Booster composition'**
  String get boosterComposition;

  /// No description provided for @bestVersions.
  ///
  /// In en, this message translates to:
  /// **'Deal the most valuable versions'**
  String get bestVersions;

  /// No description provided for @bestVersionsHint.
  ///
  /// In en, this message translates to:
  /// **'Every card pulled is replaced by the rarest version of the same card in the pool'**
  String get bestVersionsHint;

  /// No description provided for @slotRow.
  ///
  /// In en, this message translates to:
  /// **'{count} × {tag}'**
  String slotRow(int count, String tag);

  /// No description provided for @slotCards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no card} =1{1 card} other{{count} cards}}'**
  String slotCards(int count);

  /// No description provided for @slotLocked.
  ///
  /// In en, this message translates to:
  /// **'Set slot'**
  String get slotLocked;

  /// No description provided for @addSlot.
  ///
  /// In en, this message translates to:
  /// **'Add a slot'**
  String get addSlot;

  /// No description provided for @slotPullsFrom.
  ///
  /// In en, this message translates to:
  /// **'Pull from'**
  String get slotPullsFrom;

  /// No description provided for @slotCount.
  ///
  /// In en, this message translates to:
  /// **'Cards per pack'**
  String get slotCount;

  /// No description provided for @poolTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get poolTags;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// No description provided for @deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get deleteTag;

  /// No description provided for @tagCardsAction.
  ///
  /// In en, this message translates to:
  /// **'Tag cards'**
  String get tagCardsAction;

  /// No description provided for @taggingTitle.
  ///
  /// In en, this message translates to:
  /// **'Tagging: {tag}'**
  String taggingTitle(String tag);

  /// No description provided for @taggingHint.
  ///
  /// In en, this message translates to:
  /// **'Tap cards to toggle the tag. Green: added, red: removed, blue: kept, grey: not tagged.'**
  String get taggingHint;

  /// No description provided for @cardTags.
  ///
  /// In en, this message translates to:
  /// **'Tags of this card'**
  String get cardTags;

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tag yet. Tags group cards for your own booster slots.'**
  String get noTags;

  /// No description provided for @userSlots.
  ///
  /// In en, this message translates to:
  /// **'Your slots'**
  String get userSlots;

  /// No description provided for @noUserSlots.
  ///
  /// In en, this message translates to:
  /// **'No slot of yours yet. A slot pulls cards from one or more tags, each with its chance.'**
  String get noUserSlots;

  /// No description provided for @editSlot.
  ///
  /// In en, this message translates to:
  /// **'Edit slot'**
  String get editSlot;

  /// No description provided for @deleteSlot.
  ///
  /// In en, this message translates to:
  /// **'Delete slot'**
  String get deleteSlot;

  /// No description provided for @slotOptions.
  ///
  /// In en, this message translates to:
  /// **'Pull from (by chance)'**
  String get slotOptions;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get addOption;

  /// No description provided for @editComposition.
  ///
  /// In en, this message translates to:
  /// **'Edit composition'**
  String get editComposition;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// No description provided for @viewOptions.
  ///
  /// In en, this message translates to:
  /// **'Sort, grouping and filters'**
  String get viewOptions;

  /// No description provided for @sizeOptions.
  ///
  /// In en, this message translates to:
  /// **'Card size and spacing'**
  String get sizeOptions;

  /// No description provided for @filtersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 filter} other{{count} filters}}'**
  String filtersCount(int count);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @groupNone.
  ///
  /// In en, this message translates to:
  /// **'No grouping'**
  String get groupNone;

  /// No description provided for @thenBy.
  ///
  /// In en, this message translates to:
  /// **'Then by'**
  String get thenBy;

  /// No description provided for @setTags.
  ///
  /// In en, this message translates to:
  /// **'Layout tags'**
  String get setTags;

  /// No description provided for @resetTag.
  ///
  /// In en, this message translates to:
  /// **'Reset to the layout'**
  String get resetTag;

  /// No description provided for @noTagGroup.
  ///
  /// In en, this message translates to:
  /// **'Without tag'**
  String get noTagGroup;

  /// No description provided for @deleteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the tag {tag}?'**
  String deleteTagTitle(String tag);

  /// No description provided for @deleteTagAffects.
  ///
  /// In en, this message translates to:
  /// **'These booster slots pull from it and will change:'**
  String get deleteTagAffects;

  /// No description provided for @prefillFrom.
  ///
  /// In en, this message translates to:
  /// **'Prefill again'**
  String get prefillFrom;

  /// No description provided for @prefillHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces every tag and slot with a set\'s booster or random packs. Your own tags and slots are lost.'**
  String get prefillHint;

  /// No description provided for @prefillTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace tags and slots?'**
  String get prefillTitle;

  /// No description provided for @prefillWarning.
  ///
  /// In en, this message translates to:
  /// **'The pool gets {slots} slots and {tags} tags from this prefill; the current ones are discarded.'**
  String prefillWarning(int slots, int tags);

  /// No description provided for @formats.
  ///
  /// In en, this message translates to:
  /// **'Formats'**
  String get formats;

  /// No description provided for @editFormats.
  ///
  /// In en, this message translates to:
  /// **'Formats'**
  String get editFormats;

  /// No description provided for @newFormat.
  ///
  /// In en, this message translates to:
  /// **'New format'**
  String get newFormat;

  /// No description provided for @formatName.
  ///
  /// In en, this message translates to:
  /// **'Format name'**
  String get formatName;

  /// No description provided for @formatKind.
  ///
  /// In en, this message translates to:
  /// **'Played as'**
  String get formatKind;

  /// No description provided for @deleteFormat.
  ///
  /// In en, this message translates to:
  /// **'Delete format'**
  String get deleteFormat;

  /// No description provided for @chooseFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose a format'**
  String get chooseFormat;

  /// No description provided for @rounds.
  ///
  /// In en, this message translates to:
  /// **'Packs, in order'**
  String get rounds;

  /// No description provided for @addRound.
  ///
  /// In en, this message translates to:
  /// **'Add a pack'**
  String get addRound;

  /// No description provided for @roundNumber.
  ///
  /// In en, this message translates to:
  /// **'Pack {number}'**
  String roundNumber(int number);

  /// No description provided for @picksPerPass.
  ///
  /// In en, this message translates to:
  /// **'Picks per pass'**
  String get picksPerPass;

  /// No description provided for @burnPerPass.
  ///
  /// In en, this message translates to:
  /// **'Burn per pass'**
  String get burnPerPass;

  /// No description provided for @boosterKind.
  ///
  /// In en, this message translates to:
  /// **'Booster'**
  String get boosterKind;

  /// No description provided for @boosterKinds.
  ///
  /// In en, this message translates to:
  /// **'Boosters'**
  String get boosterKinds;

  /// No description provided for @newBooster.
  ///
  /// In en, this message translates to:
  /// **'New booster'**
  String get newBooster;

  /// No description provided for @boosterName.
  ///
  /// In en, this message translates to:
  /// **'Booster name'**
  String get boosterName;

  /// No description provided for @deleteBooster.
  ///
  /// In en, this message translates to:
  /// **'Delete booster'**
  String get deleteBooster;

  /// No description provided for @pickPhase.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Pick 1 card} other{Pick {count} cards}}'**
  String pickPhase(int count);

  /// No description provided for @burnPhase.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Burn 1 card} other{Burn {count} cards}}'**
  String burnPhase(int count);

  /// No description provided for @formatSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {packs, plural, =1{1 pack} other{{packs} packs}}'**
  String formatSummary(String kind, int packs);

  /// No description provided for @cardTextSetting.
  ///
  /// In en, this message translates to:
  /// **'Card text'**
  String get cardTextSetting;

  /// No description provided for @textModePrinted.
  ///
  /// In en, this message translates to:
  /// **'As printed in the set'**
  String get textModePrinted;

  /// No description provided for @textModeLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest version (errata)'**
  String get textModeLatest;

  /// No description provided for @noCardText.
  ///
  /// In en, this message translates to:
  /// **'No card text available.'**
  String get noCardText;

  /// No description provided for @textVersionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} versions — tap one to use it for this card'**
  String textVersionsCount(int count);

  /// No description provided for @textVersionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version {number}'**
  String textVersionNumber(int number);

  /// No description provided for @textVersionLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get textVersionLatest;

  /// No description provided for @useDefaultVersion.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get useDefaultVersion;

  /// No description provided for @swapArtwork.
  ///
  /// In en, this message translates to:
  /// **'Swap artwork'**
  String get swapArtwork;

  /// No description provided for @artworkOwn.
  ///
  /// In en, this message translates to:
  /// **'Own artwork'**
  String get artworkOwn;

  /// No description provided for @artworkChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen'**
  String get artworkChosen;

  /// No description provided for @noOtherArtwork.
  ///
  /// In en, this message translates to:
  /// **'No other artwork found for this card.'**
  String get noOtherArtwork;

  /// No description provided for @artworkLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the artworks: {error}'**
  String artworkLoadFailed(String error);

  /// No description provided for @selectionCopies.
  ///
  /// In en, this message translates to:
  /// **'Set the copies…'**
  String get selectionCopies;

  /// No description provided for @selectionTags.
  ///
  /// In en, this message translates to:
  /// **'Edit the tags…'**
  String get selectionTags;

  /// No description provided for @selectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Card details'**
  String get selectionDetails;

  /// No description provided for @selectionAll.
  ///
  /// In en, this message translates to:
  /// **'Select every card shown'**
  String get selectionAll;

  /// No description provided for @selectionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the selection'**
  String get selectionClear;

  /// No description provided for @batchTabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get batchTabList;

  /// No description provided for @batchTabOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get batchTabOptions;

  /// No description provided for @batchQualities.
  ///
  /// In en, this message translates to:
  /// **'Qualities for the whole batch'**
  String get batchQualities;

  /// No description provided for @batchQualitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Every imported card takes the value picked for a quality, in place of the one it had; none picked leaves the quality alone.'**
  String get batchQualitiesHint;

  /// No description provided for @batchRarities.
  ///
  /// In en, this message translates to:
  /// **'Import the rarities'**
  String get batchRarities;

  /// No description provided for @batchRaritiesHint.
  ///
  /// In en, this message translates to:
  /// **'Each card joins the tag of its rarity, so the boosters built on rarities deal it. Off, the cards come in with only the tags and values above.'**
  String get batchRaritiesHint;

  /// No description provided for @updatesSection.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesSection;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Opack {version}'**
  String updateCurrentVersion(String version);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'This is the latest version'**
  String get updateUpToDate;

  /// No description provided for @updateDebugBuild.
  ///
  /// In en, this message translates to:
  /// **'A debug build: updates are only looked for by release builds'**
  String get updateDebugBuild;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get updateChecking;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @updateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updateCheckNow;

  /// No description provided for @updateCheckAtLaunch.
  ///
  /// In en, this message translates to:
  /// **'Check for updates when the app starts'**
  String get updateCheckAtLaunch;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @updateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkip;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String updateOpenFailed(String url);

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install and restart'**
  String get updateInstall;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Updating to {version}'**
  String updateInstalling(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the update…'**
  String get updateDownloading;

  /// No description provided for @updateRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restarting the app…'**
  String get updateRestarting;

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'The update could not be installed: {error}. You can download it and replace the app by hand.'**
  String updateInstallFailed(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
