import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/card_languages.dart';
import '../../core/settings/locale_controller.dart';
import '../../features/card_text/data/card_text_repository.dart';
import '../../features/card_text/domain/card_text.dart';
import '../../l10n/app_localizations.dart';
import '../../features/packs/presentation/opening_mode.dart';
import '../images/card_image_cache.dart';

/// App bar menu: UI language, card picture and card data languages, default
/// card text version, pack opening mode and online pictures.
class SettingsMenu extends ConsumerWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(localeProvider)?.languageCode ?? '';
    final mode = ref.watch(textPreferencesProvider).mode;
    final images = ref.watch(cardImagesEnabledProvider);
    final opening = ref.watch(openingModeProvider);
    final cardLanguages = ref.watch(cardLanguagesProvider);
    final languagesSetting = ref.read(cardLanguagesProvider.notifier);

    PopupMenuItem<VoidCallback> option(String label, bool checked, VoidCallback select) =>
        CheckedPopupMenuItem(value: select, checked: checked, child: Text(label));

    void selectLanguage(String code) =>
        ref.read(localeProvider.notifier).select(code.isEmpty ? null : Locale(code));
    void selectMode(TextVersionMode mode) =>
        ref.read(textPreferencesProvider.notifier).setMode(mode);

    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.settings),
      tooltip: l10n.settings,
      onSelected: (select) => select(),
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text(l10n.language)),
        option(l10n.languageSystem, language.isEmpty, () => selectLanguage('')),
        option(l10n.languageEnglish, language == 'en', () => selectLanguage('en')),
        option(l10n.languageFrench, language == 'fr', () => selectLanguage('fr')),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text(l10n.pictureLanguage)),
        for (final (code, label) in [(null, l10n.languageSystem), ('en', l10n.languageEnglish), ('fr', l10n.languageFrench)])
          option(label, cardLanguages.picture == code, () => languagesSetting.selectPicture(code)),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text(l10n.dataLanguage)),
        for (final (code, label) in [(null, l10n.languageSystem), ('en', l10n.languageEnglish), ('fr', l10n.languageFrench)])
          option(label, cardLanguages.data == code, () => languagesSetting.selectData(code)),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text(l10n.cardTextSetting)),
        option(l10n.textModePrinted, mode == TextVersionMode.printed,
            () => selectMode(TextVersionMode.printed)),
        option(l10n.textModeLatest, mode == TextVersionMode.latest,
            () => selectMode(TextVersionMode.latest)),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text(l10n.openingModeSetting)),
        option(l10n.openingGrid, opening == OpeningMode.grid,
            () => ref.read(openingModeProvider.notifier).select(OpeningMode.grid)),
        option(l10n.openingSwipe, opening == OpeningMode.swipe,
            () => ref.read(openingModeProvider.notifier).select(OpeningMode.swipe)),
        const PopupMenuDivider(),
        PopupMenuItem(enabled: false, child: Text(l10n.cardImagesSetting)),
        option(l10n.cardImagesOnline, images,
            () => ref.read(cardImagesEnabledProvider.notifier).set(!images)),
      ],
    );
  }
}
