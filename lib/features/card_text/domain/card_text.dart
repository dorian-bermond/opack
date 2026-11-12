/// One printed wording of a card in one language.
class TextVersion {
  const TextVersion({required this.text, this.name, this.typeLine, this.printings = const []});

  factory TextVersion.fromJson(Map<String, dynamic> json) => TextVersion(
        name: json['n'] as String?,
        text: json['t'] as String? ?? '',
        typeLine: json['k'] as String?,
        printings: (json['p'] as List? ?? const []).cast<String>(),
      );

  final String? name;
  final String text;

  /// Type line when the errata recorded it, e.g. `[Spellcaster/Normal]`.
  final String? typeLine;

  /// Print codes carrying this wording (empty for today's text when no
  /// errata page lists it).
  final List<String> printings;
}

/// Every version of a card, oldest first, per language code.
typedef CardTexts = Map<String, List<TextVersion>>;

/// Which version to show when the user has not picked one for a card.
enum TextVersionMode {
  /// The wording printed on this very card (its set code), else the latest.
  printed,

  /// Today's official text.
  latest,
}

/// Index of the version to show: the user's pick, else the [mode] default.
int chooseVersion(
  List<TextVersion> versions, {
  required String printCode,
  required TextVersionMode mode,
  int? override,
}) {
  if (override != null && override >= 0 && override < versions.length) return override;
  if (mode == TextVersionMode.printed) {
    final printed = versions.indexWhere((v) => v.printings.contains(printCode));
    if (printed >= 0) return printed;
  }
  return versions.length - 1;
}
