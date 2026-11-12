import '../../catalog/domain/models.dart';

/// A user-imported cube: a card list played as a closed pool by default.
class Cube {
  const Cube({
    required this.id,
    required this.game,
    required this.name,
    required this.source,
    required this.importedAt,
    required this.cards,
  });

  factory Cube.fromJson(Map<String, dynamic> json) => Cube(
        id: json['id'] as String,
        game: Game.values.byName(json['game'] as String),
        name: json['name'] as String,
        source: json['source'] as String,
        importedAt: DateTime.parse(json['importedAt'] as String),
        cards: [
          for (final card in json['cards'] as List)
            CardData.fromJson(card as Map<String, dynamic>),
        ],
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'game': game.name,
        'name': name,
        'source': source,
        'importedAt': importedAt.toIso8601String(),
        'cards': [for (final card in cards) card.toJson()],
      };

  final String id;
  final Game game;
  final String name;

  /// Where it came from: a CubeCobra ID or an imported file name.
  final String source;
  final DateTime importedAt;
  final List<CardData> cards;

  static const packSize = 15;
}
