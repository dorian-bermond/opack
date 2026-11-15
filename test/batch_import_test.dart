import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_info/presentation/batch_import.dart';

void main() {
  test('a pasted list reads counts and names, skipping blanks and lone numbers', () {
    const text = '''
1

Alghoul Mazera
1 Call of the Forgotten

2x Spirit Shield
Kasha x3
  4 X Book of Life
Pyramid Turtle
''';
    expect(parseCardList(text), [
      (count: 1, name: 'Alghoul Mazera'),
      (count: 1, name: 'Call of the Forgotten'),
      (count: 2, name: 'Spirit Shield'),
      (count: 3, name: 'Kasha'),
      (count: 4, name: 'Book of Life'),
      (count: 1, name: 'Pyramid Turtle'),
    ]);
    expect(parseCardList(''), isEmpty);
    expect(parseCardList('0 Zero'), [(count: 1, name: 'Zero')]);
  });
}
