import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/images/card_image_cache.dart';
import '../../catalog/domain/models.dart';

/// The printed wording of an MtG card as Scryfall records it: name, type
/// line, rules text and flavor text, one entry per face.
class ScryfallText {
  const ScryfallText({required this.faces, this.lang = 'en'});

  factory ScryfallText.fromJson(Map<String, dynamic> json) {
    final faces = (json['card_faces'] as List?)?.cast<Map<String, dynamic>>() ?? [json];
    return ScryfallText(
      faces: [for (final face in faces) ScryfallFace.fromJson(face)],
      lang: json['lang'] as String? ?? 'en',
    );
  }

  final List<ScryfallFace> faces;

  /// The language the texts are in: the one asked for, or English when
  /// the print was never made in it.
  final String lang;
}

class ScryfallFace {
  const ScryfallFace({required this.name, this.typeLine, this.manaCost, this.text, this.flavor});

  factory ScryfallFace.fromJson(Map<String, dynamic> json) => ScryfallFace(
        name: json['printed_name'] as String? ?? json['name'] as String? ?? '',
        typeLine: json['printed_type_line'] as String? ?? json['type_line'] as String?,
        manaCost: json['mana_cost'] as String?,
        text: json['printed_text'] as String? ?? json['oracle_text'] as String?,
        flavor: json['flavor_text'] as String?,
      );

  final String name;
  final String? typeLine;
  final String? manaCost;
  final String? text;
  final String? flavor;
}

/// Scryfall's record of this print in [language], falling back to the
/// English print; `null` for cards without a Scryfall id.
ImageSource? scryfallTextSource(CardData card, {String language = 'en'}) {
  final id = card.scryfallId;
  if (id == null) return null;
  final english = ImageSource('text-scryfall-$id', Uri.https('api.scryfall.com', '/cards/$id'));
  if (language == 'en') return english;
  final [set, ...number] = card.id.split('-');
  return ImageSource(
    'text-scryfall-$id-$language',
    Uri.https('api.scryfall.com', '/cards/${set.toLowerCase()}/${number.join('-')}/$language'),
    fallback: english,
  );
}

/// The wording of an MtG card, downloaded once like its picture; `null` when
/// pictures are disabled, offline or for cards without a Scryfall id.
final scryfallTextProvider = FutureProvider.family<ScryfallText?, ImageSource>((ref, source) async {
  final cache = ref.watch(cardImageCacheProvider);
  if (cache == null || !ref.watch(cardImagesEnabledProvider)) return null;
  final file = await cache.fetch(source.key, source.url,
      fallback: source.fallback, pick: source.pick, extension: 'json');
  if (file == null) return null;
  try {
    return ScryfallText.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  } on FormatException {
    return null;
  }
});
