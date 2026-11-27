import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/pools/domain/text_diff.dart';

void main() {
  test('a word diff keeps what both texts have, bars the old, marks the new', () {
    final parts = wordDiff('Add 1 Zombie monster from your Deck to your hand.', 'Add 1 Zombie monster from your GY to your hand.');
    expect(parts.map((p) => (p.text, p.kind)).toList(), [
      ('Add 1 Zombie monster from your ', DiffKind.same),
      ('Deck ', DiffKind.removed),
      ('GY ', DiffKind.added),
      ('to your hand.', DiffKind.same),
    ]);
    // The parts join back into either text.
    expect([for (final p in parts) if (p.kind != DiffKind.added) p.text].join(), 'Add 1 Zombie monster from your Deck to your hand.');
    expect([for (final p in parts) if (p.kind != DiffKind.removed) p.text].join(), 'Add 1 Zombie monster from your GY to your hand.');
  });

  test('a word diff of unrelated texts is all removed then all added; equal texts are all the same', () {
    expect(wordDiff('a b', 'c d'), [(text: 'a b', kind: DiffKind.removed), (text: 'c d', kind: DiffKind.added)]);
    expect(wordDiff('one two', 'one two'), [(text: 'one two', kind: DiffKind.same)]);
    expect(wordDiff('', ''), isEmpty);
    expect(wordDiff('', 'new'), [(text: 'new', kind: DiffKind.added)]);
  });
}
