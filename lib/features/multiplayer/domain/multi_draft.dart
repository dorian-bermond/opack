import 'dart:math';

import '../../catalog/domain/models.dart';
import '../../draft/domain/draft_session.dart';

/// A booster draft where any seat may be a person ([humans]) and the
/// others are bots. Each person picks from their own pack at their own
/// pace; once every person is done with the pass, the bots take their
/// cards and the packs move on. Packs pass left on odd rounds and right
/// on even ones, as in [DraftSession].
class MultiDraft {
  MultiDraft(this.rounds, {required this.seats, required this.humans, Random? random})
      : _random = random ?? Random(),
        assert(humans.every((s) => s >= 0 && s < seats)) {
    pools = List.generate(seats, (_) => <CardData>[]);
    _startRound();
  }

  final List<DraftRound> rounds;
  final int seats;
  final Set<int> humans;
  final Random _random;

  late final List<List<CardData>> pools;
  late List<List<CardData>> _packs;
  int round = 1;
  int pick = 1;

  /// Cards each person took or burned from the pack in hand this pass.
  final _picked = <int, int>{};
  final _burned = <int, int>{};

  bool get isFinished => round > rounds.length;

  DraftRound get currentRound => rounds[round - 1];

  List<CardData> packFor(int seat) => isFinished ? const [] : _packs[seat];

  int _picksDue(int seat) => min(currentRound.picks, _packs[seat].length + (_picked[seat] ?? 0));
  int _burnsDue(int seat) => min(currentRound.burn, _packs[seat].length + (_burned[seat] ?? 0));

  DraftPhase phaseFor(int seat) => (_picked[seat] ?? 0) < _picksDue(seat) ? DraftPhase.pick : DraftPhase.burn;

  /// Cards [seat] still has to pick (or burn) this pass; `0` once done.
  int remainingFor(int seat) {
    if (isFinished) return 0;
    return phaseFor(seat) == DraftPhase.pick
        ? _picksDue(seat) - (_picked[seat] ?? 0)
        : _burnsDue(seat) - (_burned[seat] ?? 0);
  }

  bool doneFor(int seat) => remainingFor(seat) == 0;

  /// The people the pass still waits on.
  Set<int> get waitingOn => isFinished ? const {} : {for (final seat in humans) if (!doneFor(seat)) seat};

  /// [seat] takes (or burns) the card [cardId] from the pack in hand.
  /// Answers whether something happened: nothing while the seat is done
  /// for the pass or the card is not in hand.
  bool pickFor(int seat, String cardId) {
    if (isFinished || !humans.contains(seat) || doneFor(seat)) return false;
    final card = _packs[seat].where((c) => c.id == cardId).firstOrNull;
    if (card == null) return false;
    if (phaseFor(seat) == DraftPhase.pick) {
      _take(seat, card);
      _picked[seat] = (_picked[seat] ?? 0) + 1;
    } else {
      _packs[seat].remove(card);
      _burned[seat] = (_burned[seat] ?? 0) + 1;
    }
    if (waitingOn.isEmpty) _endPass();
    return true;
  }

  void _endPass() {
    for (var seat = 0; seat < seats; seat++) {
      if (humans.contains(seat)) continue;
      for (var n = 0; n < currentRound.picks && _packs[seat].isNotEmpty; n++) {
        _take(seat, _botChoice(_packs[seat], best: true));
      }
      for (var n = 0; n < currentRound.burn && _packs[seat].isNotEmpty; n++) {
        _packs[seat].remove(_botChoice(_packs[seat], best: false));
      }
    }
    _pass();
    pick++;
    _picked.clear();
    _burned.clear();
    if (_packs.every((p) => p.isEmpty)) {
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
