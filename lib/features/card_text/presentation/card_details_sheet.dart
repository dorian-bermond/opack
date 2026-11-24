import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/card_languages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/images/artwork_picker.dart';
import '../../../shared/images/card_image_cache.dart';
import '../../../shared/widgets/card_tile.dart';
import '../../catalog/domain/models.dart';
import '../data/card_text_repository.dart';
import '../data/scryfall_text.dart';
import '../domain/card_text.dart';

/// Shows [card]'s picture and text; within the pool [poolId], its artwork
/// can be swapped from there.
Future<void> showCardDetails(BuildContext context, CardData card, {String? poolId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: CardDetailsSheet(card: card, poolId: poolId),
      ),
    );

/// The version of [card] shown for [lang], or `null` without texts.
TextVersion? shownVersion(WidgetRef ref, CardData card, String lang) {
  final passcode = card.passcode;
  if (passcode == null) return null;
  final versions = ref.watch(cardTextsProvider).value?[textKey(passcode)]?[lang];
  if (versions == null || versions.isEmpty) return null;
  final prefs = ref.watch(textPreferencesProvider);
  return versions[chooseVersion(
    versions,
    printCode: card.id,
    mode: prefs.mode,
    override: prefs.overrideFor(passcode, lang),
  )];
}

/// The name [card] is shown under for [lang]: its shown text version's, which
/// knows translations the card itself may lack, else the card's own.
String shownName(WidgetRef ref, CardData card, String lang) =>
    shownVersion(ref, card, lang)?.name ?? card.nameFor(lang);

/// The card's picture as tall as the sheet on the left; on the right its
/// name, then its text: every text version per language for Yu-Gi-Oh!
/// (tapping a version makes it this card's text in that language), the
/// printed rules and flavor text from Scryfall for MtG.
class CardDetailsSheet extends ConsumerWidget {
  const CardDetailsSheet({super.key, required this.card, this.poolId});

  final CardData card;

  /// The pool the card is seen in, enabling the artwork swap.
  final String? poolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uiLang = dataLanguage(ref, context);
    final source = cardImageSource(card, language: pictureLanguage(ref, context));
    final image = source == null ? null : ref.watch(cardImageProvider(source)).value;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shownName(ref, card, uiLang),
              style: theme.textTheme.titleLarge),
          Text('${card.id} · ${card.rarity.label(l10n)}${card.foil ? ' · ${l10n.foil}' : ''}',
              style: theme.textTheme.bodySmall),
          if (poolId case final poolId? when source != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.brush_outlined),
                  label: Text(l10n.swapArtwork),
                  onPressed: () async {
                    // The sheet holds the card as it was: once the pool
                    // changed, close it so the screen shows the new picture.
                    final changed = await pickArtwork(context, poolId: poolId, card: card);
                    if (changed && context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight - 16;
      final ratio = cardAspectRatio(card);
      final width = (height * ratio).clamp(0.0, constraints.maxWidth * 0.5);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: width,
              height: width / ratio,
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(width / 22),
                      child: Image.file(image, fit: BoxFit.contain),
                    )
                  : CardTile(card: card),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: card.passcode != null
                      ? _YgoTexts(card: card, uiLang: uiLang)
                      : _MtgText(card: card, uiLang: uiLang),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Rules and flavor text of an MtG card, from Scryfall.
class _MtgText extends ConsumerWidget {
  const _MtgText({required this.card, required this.uiLang});

  final CardData card;
  final String uiLang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final source = scryfallTextSource(card, language: uiLang);
    final texts = source == null ? null : ref.watch(scryfallTextProvider(source));
    if (texts?.isLoading ?? false) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    final faces = texts?.value?.faces;
    if (faces == null || faces.isEmpty) {
      return Padding(padding: const EdgeInsets.only(right: 16), child: Text(l10n.noCardText));
    }
    final lang = texts!.value!.lang;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 24),
      children: [
        // Not printed in the language asked for: English, flagged as such.
        if (lang != uiLang) OtherLanguageNote(lang: lang, wanted: uiLang),
        for (final (i, face) in faces.indexed) ...[
          if (i > 0) const Divider(height: 24),
          if (faces.length > 1)
            Text(face.name, style: theme.textTheme.titleMedium),
          if (face.typeLine case final typeLine?)
            Text(
              [typeLine, ?face.manaCost].join('   '),
              style: theme.textTheme.labelLarge,
            ),
          if (face.text case final text? when text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
          if (face.flavor case final flavor? when flavor.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(flavor, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ],
    );
  }
}

/// Tells the text is not in the language wanted but in [lang], under its
/// flag.
class OtherLanguageNote extends StatelessWidget {
  const OtherLanguageNote({super.key, required this.lang, required this.wanted});

  final String lang;
  final String wanted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: const Key('otherLanguageNote'),
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
      child: Row(
        children: [
          LanguageFlag(lang, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.noTextInLanguage(languageName(l10n, wanted), languageName(l10n, lang)),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every text version of a Yu-Gi-Oh! card, one tab per language.
class _YgoTexts extends ConsumerWidget {
  const _YgoTexts({required this.card, required this.uiLang});

  final CardData card;
  final String uiLang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final passcode = card.passcode!;
    final texts = ref.watch(cardTextsProvider);
    final cardTexts = texts.value?[textKey(passcode)];
    final languages = [
      uiLang,
      ...?cardTexts?.keys.where((lang) => lang != uiLang),
    ].where((lang) => cardTexts?[lang]?.isNotEmpty ?? false).toList();

    if (texts.isLoading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (languages.isEmpty) {
      return Padding(padding: const EdgeInsets.only(right: 16), child: Text(l10n.noCardText));
    }
    return DefaultTabController(
      length: languages.length,
      child: Column(
        children: [
          if (!languages.contains(uiLang)) OtherLanguageNote(lang: languages.first, wanted: uiLang),
          TabBar(tabs: [
            for (final lang in languages)
              Tab(
                icon: lang == uiLang ? null : LanguageFlag(lang, size: 18),
                text: _languageName(l10n, lang),
              ),
          ]),
          Expanded(
            child: TabBarView(
              children: [
                for (final lang in languages)
                  _VersionList(
                    card: card,
                    passcode: passcode,
                    lang: lang,
                    versions: cardTexts![lang]!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _languageName(AppLocalizations l10n, String lang) => switch (lang) {
        'fr' => l10n.languageFrench,
        'en' => l10n.languageEnglish,
        _ => lang.toUpperCase(),
      };
}

class _VersionList extends ConsumerWidget {
  const _VersionList({
    required this.card,
    required this.passcode,
    required this.lang,
    required this.versions,
  });

  final CardData card;
  final String passcode;
  final String lang;
  final List<TextVersion> versions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prefs = ref.watch(textPreferencesProvider);
    final override = prefs.overrideFor(passcode, lang);
    final selected = chooseVersion(versions, printCode: card.id, mode: prefs.mode, override: override);
    final controller = ref.read(textPreferencesProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 24),
      children: [
        if (versions.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.textVersionsCount(versions.length),
                      style: theme.textTheme.labelLarge),
                ),
                if (override != null)
                  TextButton(
                    onPressed: () => controller.choose(passcode, lang, null),
                    child: Text(l10n.useDefaultVersion),
                  ),
              ],
            ),
          ),
        for (var i = versions.length - 1; i >= 0; i--)
          Card(
            color: i == selected ? theme.colorScheme.secondaryContainer : null,
            child: InkWell(
              onTap: versions.length > 1 ? () => controller.choose(passcode, lang, i) : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (versions.length > 1)
                      Row(
                        children: [
                          Icon(i == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                i == versions.length - 1
                                    ? l10n.textVersionLatest
                                    : l10n.textVersionNumber(i + 1),
                                if (versions[i].printings.isNotEmpty) versions[i].printings.join(', '),
                              ].join(' · '),
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    if (versions[i].name case final name? when name != card.nameFor(lang))
                      Text(name, style: theme.textTheme.titleSmall),
                    if (versions[i].typeLine case final typeLine?)
                      Text(typeLine, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(versions[i].text, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
