// Pure helpers reading onepiece.limitlesstcg.com pages, which list every
// print of a card with its product and its TCGplayer listing name; the
// latter spells out what the print is (`…-manga`, `…-alternate-art`,
// `…-sp`), which onepiece.gg's version numbers do not.

/// One print of a card as a limitless card page lists it.
typedef LimitlessPrint = ({String set, String label, String product});

/// The prints of a card page, in the page's order (the card's own print
/// first, then the others oldest first): the product's name, limitless's
/// short label (`aa`, `manga`, `wanted` or empty) and the TCGplayer
/// listing slug (empty when there is none).
List<LimitlessPrint> limitlessPrints(String html) {
  final rows = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(html);
  final prints = <LimitlessPrint>[];
  for (final row in rows) {
    final body = row.group(1)!;
    final cell = RegExp(r'<a[^>]*>\s*([^<]*?)\s*<span class="prints-table-card-number">([^<]*)</span>').firstMatch(body);
    if (cell == null) continue;
    final product = RegExp(r'tcgplayer\.com%2Fproduct%2F\d+%2F([^"&]+)').firstMatch(body)?.group(1) ?? '';
    prints.add((set: cell.group(1)!.trim(), label: cell.group(2)!.trim(), product: product));
  }
  return prints;
}

/// Set codes by name from the limitless set index (`OP18` for
/// `The Dominance of God`).
Map<String, String> limitlessSetCodes(String html) {
  final codes = <String, String>{};
  for (final row in RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(html)) {
    final cells = RegExp(r'<td[^>]*>\s*<a href="/cards/[^"]*">\s*([^<]*?)\s*</a>').allMatches(row.group(1)!).toList();
    if (cells.length < 2) continue;
    final code = cells[0].group(1)!;
    if (RegExp(r'^(OP|EB|PRB)\d+$').hasMatch(code)) codes[cells[1].group(1)!] = code;
  }
  return codes;
}

/// Whether a limitless print is a manga art: its listing says so (the
/// short label alone also calls some special leaders manga).
bool limitlessIsManga(LimitlessPrint print) =>
    print.product.isEmpty ? print.label == 'manga' : RegExp(r'(^|-)manga($|-)').hasMatch(print.product);

/// What a limitless print of a card is, in the set the card is [own] to
/// or in another product: `manga` a manga art; `parallel` an alternate
/// art (`aa`) of the set's own card; `base` an unlabeled print of the
/// set's own card, a plain rare printed in several panels; `special`
/// everything else: another product's card in a new or plain art, a
/// serial or gold-stamped print, a wanted poster.
String limitlessKind(LimitlessPrint print, {required bool own}) {
  if (limitlessIsManga(print)) return 'manga';
  if (!own) return 'special';
  return switch (print.label) {
    'aa' => 'parallel',
    '' => 'base',
    _ => 'special',
  };
}

/// What each of a card's prints pulled from [product] is (onepiece.gg
/// ids, base first then by version), matched against the limitless
/// prints of the same product in order (see [limitlessKind]); empty
/// when the counts differ, leaving the guess to the version numbers.
Map<String, String> opcPrintKinds({
  required String product,
  required List<String> ids,
  required List<LimitlessPrint> prints,
  required Map<String, String> setCodes,
}) {
  final here = prints.where((p) => setCodes[p.set] == product).toList();
  if (ids.isEmpty || here.length != ids.length) return const {};
  final own = ids.first.startsWith('$product-');
  return {for (final (i, p) in here.indexed) ids[i]: limitlessKind(p, own: own)};
}
