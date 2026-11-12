import 'dart:math';

import '../../catalog/domain/models.dart';
import '../../packs/domain/pack_source.dart';

/// One round of a draft: where its packs come from, how many cards each
/// player picks per pass and how many they burn afterwards.
class DraftRound {
  const DraftRound(this.source, {this.picks = 1, this.burn = 0});

  final PackSource source;
  final int picks;
  final int burn;
}

/// What the user is asked to do with the pack in hand.
enum DraftPhase { pick, burn }

/// A booster draft between the user (seat 0) and bot players.
///
/// Packs pass left on odd rounds and right on even rounds. Each pass the
/// user picks the round's number of cards, then burns the round's number
/// (removed from the draft). Bots take the highest-rated cards (cube ELO),
/// else the rarest, and burn the lowest; ties are random. A round ends when
/// the pack reaching the user is empty.
class DraftSession {
  DraftSession.rounds(this._rounds, {this.seats = 8, Random? random}) : _random = random ?? Random() {
    pools = List.generate(seats, (_) => <CardData>[]);
    _startRound();
  }

  /// Every round from [source], one pick and no burn per pass.
  DraftSession(PackSource source, {required int rounds, int seats = 8, Random? random})
      : this.rounds([for (var i = 0; i < rounds; i++) DraftRound(source)], seats: seats, random: random);

  final int seats;
  final Random _random;
  final List<DraftRound> _rounds;

  late final List<List<CardData>> pools;
  late List<List<CardData>> _packs;
  int round = 1;
  int pick = 1;

  /// Cards the user took or burned from the pack in hand this pass.
  int _pickedThisPass = 0;
  int _burnedThisPass = 0;

  int get rounds => _rounds.length;

  bool get isFinished => round > rounds;

  DraftRound get currentRound => _rounds[round - 1];

  List<CardData> get userPool => pools[0];

  List<CardData> get currentPack => isFinished ? const [] : _packs[0];

  /// Whether the user is picking or burning right now.
  DraftPhase get phase => _pickedThisPass < _picksDue ? DraftPhase.pick : DraftPhase.burn;

  /// Cards still to pick (or burn, in that phase) before the pack passes.
  int get remainingInPhase =>
      phase == DraftPhase.pick ? _picksDue - _pickedThisPass : _burnsDue - _burnedThisPass;

  int get _picksDue => min(currentRound.picks, _packs[0].length + _pickedThisPass);
  int get _burnsDue =>
      min(currentRound.burn, _packs[0].length + _burnedThisPass);

  /// Takes [card] (pick phase) or discards it (burn phase), then lets the
  /// bots act and passes the packs once the user is done with theirs.
  void pickCard(CardData card) {
    assert(!isFinished && _packs[0].contains(card));
    if (phase == DraftPhase.pick) {
      _take(0, card);
      _pickedThisPass++;
    } else {
      _packs[0].remove(card);
      _burnedThisPass++;
    }
    if (_pickedThisPass < _picksDue || _burnedThisPass < _burnsDue) return;

    for (var seat = 1; seat < seats; seat++) {
      for (var n = 0; n < currentRound.picks && _packs[seat].isNotEmpty; n++) {
        _take(seat, _botChoice(_packs[seat], best: true));
      }
      for (var n = 0; n < currentRound.burn && _packs[seat].isNotEmpty; n++) {
        _packs[seat].remove(_botChoice(_packs[seat], best: false));
      }
    }
    _pass();
    pick++;
    _pickedThisPass = 0;
    _burnedThisPass = 0;

    if (_packs[0].isEmpty) {
      round++;
      pick = 1;
      if (!isFinished) _startRound();
    }
  }

  void _startRound() => _packs = List.generate(seats, (_) => currentRound.source.nextPack());

  void _take(int seat, CardData card) {
    _packs[seat].remove(card);
    pools[seat].add(card);
  }

  CardData _botChoice(List<CardData> pack, {required bool best}) {
    double value(CardData c) => c.score ?? c.rarity.index.toDouble();
    final target = best ? pack.map(value).reduce(max) : pack.map(value).reduce(min);
    final candidates = pack.where((c) => value(c) == target).toList();
    return candidates[_random.nextInt(candidates.length)];
  }

  void _pass() {
    final left = round.isOdd;
    _packs = List.generate(seats, (seat) {
      final from = left ? seat - 1 : seat + 1;
      return _packs[from % seats];
    });
  }
}
