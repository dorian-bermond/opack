import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../core/settings/locale_controller.dart';
import '../../features/card_text/data/card_text_repository.dart';
import '../../features/card_text/domain/card_text.dart';
import '../../features/packs/presentation/opening_mode.dart';
import '../../features/catalog/domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../features/pools/presentation/pool_widgets.dart';
import '../images/card_image_cache.dart';
import 'card_tile.dart';

/// The settings, one section per setting: UI language, card picture and
/// card data languages, default card text version, pack opening mode,
/// online pictures, the hover preview and the rarity marker.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(localeProvider)?.languageCode ?? '';
    final mode = ref.watch(textPreferencesProvider).mode;
    final images = ref.watch(cardImagesEnabledProvider);
    final hoverPreview = ref.watch(cardHoverPreviewProvider);
    final marker = ref.watch(rarityMarkerProvider);
    final opening = ref.watch(openingModeProvider);
    final rarityColors = ref.watch(rarityColorsProvider);
    final cardLanguages = ref.watch(cardLanguagesProvider);
    final languagesSetting = ref.read(cardLanguagesProvider.notifier);
    final languageChoices = [(null, l10n.languageSystem), ('en', l10n.languageEnglish), ('fr', l10n.languageFrench)];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Choice<String?>(
            title: l10n.language,
            value: language.isEmpty ? null : language,
            choices: languageChoices,
            onChanged: (code) => ref.read(localeProvider.notifier).select(code == null ? null : Locale(code)),
          ),
          _Choice<String?>(
            title: l10n.pictureLanguage,
            value: cardLanguages.picture,
            choices: languageChoices,
            onChanged: languagesSetting.selectPicture,
          ),
          _Choice<String?>(
            title: l10n.dataLanguage,
            value: cardLanguages.data,
            choices: languageChoices,
            onChanged: languagesSetting.selectData,
          ),
          _Choice<TextVersionMode>(
            title: l10n.cardTextSetting,
            value: mode,
            choices: [
              (TextVersionMode.printed, l10n.textModePrinted),
              (TextVersionMode.latest, l10n.textModeLatest),
            ],
            onChanged: (m) => ref.read(textPreferencesProvider.notifier).setMode(m!),
          ),
          _Choice<OpeningMode>(
            title: l10n.openingModeSetting,
            value: opening,
            choices: [(OpeningMode.grid, l10n.openingGrid), (OpeningMode.swipe, l10n.openingSwipe)],
            onChanged: (m) => ref.read(openingModeProvider.notifier).select(m!),
          ),
          _Section(
            title: l10n.cardImagesSetting,
            children: [
              SwitchListTile(
                key: const Key('settingImages'),
                title: Text(l10n.cardImagesOnline),
                value: images,
                onChanged: ref.read(cardImagesEnabledProvider.notifier).set,
              ),
              SwitchListTile(
                key: const Key('settingHoverPreview'),
                title: Text(l10n.cardHoverPreview),
                value: hoverPreview,
                onChanged: ref.read(cardHoverPreviewProvider.notifier).set,
              ),
            ],
          ),
          _Choice<RarityMarker>(
            title: l10n.rarityMarkerSetting,
            value: marker,
            choices: [(RarityMarker.border, l10n.rarityMarkerBorder), (RarityMarker.dot, l10n.rarityMarkerDot)],
            onChanged: (m) => ref.read(rarityMarkerProvider.notifier).select(m!),
          ),
          _Section(
            title: l10n.rarityColorsSetting,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(l10n.rarityColorsHint, style: Theme.of(context).textTheme.bodySmall),
              ),
              for (final rarity in Rarity.values)
                ListTile(
                  key: ValueKey('rarityColor-${rarity.name}'),
                  leading: ColorDot(rarity.color, size: 20),
                  title: Text(rarity.label(l10n)),
                  subtitle: rarityColors.containsKey(rarity) ? null : Text(l10n.colorDefault),
                  trailing: rarityColors.containsKey(rarity)
                      ? IconButton(
                          key: ValueKey('rarityColorReset-${rarity.name}'),
                          tooltip: l10n.colorReset,
                          icon: const Icon(Icons.restart_alt),
                          onPressed: () => ref.read(rarityColorsProvider.notifier).set(rarity, null),
                        )
                      : null,
                  onTap: () async {
                    final chosen = await showModalBottomSheet<Color>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rarity.label(l10n), style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              ColorPicker(value: rarity.color, onChanged: (c) => Navigator.pop(context, c)),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (chosen != null) ref.read(rarityColorsProvider.notifier).set(rarity, chosen);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled group of tiles.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          ...children,
        ],
      );
}

/// One setting with a single value among [choices], as radio tiles.
class _Choice<T> extends StatelessWidget {
  const _Choice({required this.title, required this.value, required this.choices, required this.onChanged});

  final String title;
  final T value;
  final List<(T, String)> choices;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => _Section(
        title: title,
        children: [
          RadioGroup<T>(
            groupValue: value,
            onChanged: onChanged,
            child: Column(
              children: [
                for (final (choice, label) in choices)
                  RadioListTile<T>(
                    key: ValueKey('setting-$title-$choice'),
                    dense: true,
                    value: choice,
                    title: Text(label),
                  ),
              ],
            ),
          ),
        ],
      );
}
