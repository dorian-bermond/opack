/// Quick ways to fill a pool's copy counts.
enum PoolPreset {
  /// Every card unlimited, like a booster print run.
  open,

  /// Every card a set number of times, like a cube.
  closed,
}

/// How many copies of each card a pool holds: [copies] times each listed
/// card, except the cards in [overrides]. `null` means unlimited.
class PoolConfig {
  const PoolConfig({this.copies, this.overrides = const {}});

  const PoolConfig.open() : this();

  const PoolConfig.closed([int copies = 1]) : this(copies: copies);

  factory PoolConfig.fromJson(Map<String, dynamic> json) => PoolConfig(
        copies: _fromJson(json['copies']),
        overrides: {
          for (final MapEntry(:key, :value)
              in (json['overrides'] as Map<String, dynamic>? ?? {}).entries)
            key: _fromJson(value),
        },
      );

  Map<String, Object?> toJson() => {
        'copies': copies ?? -1,
        'overrides': {
          for (final MapEntry(:key, :value) in overrides.entries) key: value ?? -1,
        },
      };

  /// Copies of each listed card without an override; `null` is unlimited.
  final int? copies;

  /// Copies of single cards by id; `null` is unlimited, `0` leaves it out.
  final Map<String, int?> overrides;

  /// The preset this config matches, or `null` once single cards differ.
  PoolPreset? get preset => overrides.isNotEmpty
      ? null
      : copies == null
          ? PoolPreset.open
          : PoolPreset.closed;

  /// Copies of card [id], listed [listed] times in its set or cube.
  int? copiesOf(String id, {int listed = 1}) {
    if (overrides.containsKey(id)) return overrides[id];
    final copies = this.copies;
    return copies == null ? null : copies * listed;
  }

  PoolConfig withCopies(int? copies) => PoolConfig(copies: copies, overrides: overrides);

  PoolConfig withoutOverrides() => PoolConfig(copies: copies);

  /// Sets card [id] to [copies]; equal to the default it drops the override.
  PoolConfig withCard(String id, int? copies, {int listed = 1}) {
    final overrides = {...this.overrides}..remove(id);
    final byDefault = PoolConfig(copies: this.copies).copiesOf(id, listed: listed);
    if (copies != byDefault) overrides[id] = copies;
    return PoolConfig(copies: this.copies, overrides: overrides);
  }

  static int? _fromJson(Object? value) =>
      value == null || value == -1 ? null : value as int;
}
