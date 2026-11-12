import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/card_text/domain/card_text.dart';

void main() {
  const versions = [
    TextVersion(name: 'Empereur Dragon du Chaos', text: 'v1', printings: ['TLM-FRSE2']),
    TextVersion(name: 'Dragon Empereur du Chaos', text: 'v2', printings: ['DR2-FR056']),
    TextVersion(name: 'Dragon Empereur du Chaos', text: 'v3', printings: ['IOC-FR000']),
    TextVersion(name: 'Dragon Empereur du Chaos', text: 'today'),
  ];

  test('printed mode uses the version of this print code', () {
    expect(chooseVersion(versions, printCode: 'DR2-FR056', mode: TextVersionMode.printed), 1);
  });

  test('printed mode falls back to the latest when the print is not listed', () {
    expect(chooseVersion(versions, printCode: 'XXX-FR001', mode: TextVersionMode.printed), 3);
  });

  test('latest mode ignores the print code', () {
    expect(chooseVersion(versions, printCode: 'DR2-FR056', mode: TextVersionMode.latest), 3);
  });

  test("the user's pick wins, invalid picks are ignored", () {
    expect(
      chooseVersion(versions, printCode: 'DR2-FR056', mode: TextVersionMode.latest, override: 0),
      0,
    );
    expect(
      chooseVersion(versions, printCode: 'DR2-FR056', mode: TextVersionMode.printed, override: 9),
      1,
    );
  });
}
