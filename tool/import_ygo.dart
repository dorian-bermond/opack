// Imports French Yu-Gi-Oh! products from the Yu-Gi-Oh! Wiki (Fandom, English
// edition), plus every card text version, into:
//   assets/sets/ygo/<CODE>.json     one file per product sold in random packs
//   assets/cards/ygo_texts.json     name/text versions per card and language
//
//   dart run tool/import_ygo.dart                  # every French set list
//   dart run tool/import_ygo.dart "Circuit Break"  # only these sets
//
// Sources, per set: "Set Card Lists:<Set> (TCG-FR)" (French codes and
// rarities) and the set page (French name, product type, release date,
// cards per pack). Per card: its page (names and current text in every
// language) and "Card Errata:<Card>" (every printed version, per language,
// with the printings that carry it).
//
// The wiki gives cards per pack, not pull rates, so booster formulas are
// derived from the rarities present and marked approximate.
// Wiki text is licensed CC BY-SA 3.0; each set file keeps attribution.

import 'dart:convert';
import 'dart:io';

import 'src/common.dart';

const _api = 'https://yugioh.fandom.com/api.php';

/// Text languages kept (wiki field prefix -> app language).
const _languages = {'en': 'en', 'fr': 'fr'};

/// Errata section headings per app language, first match wins
/// ("Asian-English" is a separate print run and is not used).
const _errataSections = {
  'en': ['English', 'North American English', 'European English'],
  'fr': ['French'],
};

/// Set page `type` values sold in random packs. Run with `--types` to list them.
const _packTypes = {
  'Booster Pack',
  'Duelist Pack',
  'Mega Pack',
  'Premium Pack',
  'Battle Pack',
  'Hidden Arsenal',
  'Special Booster',
  'Mini Booster',
};

final _notPacks = RegExp(
    r'promotional|participation|prize|deck|starter|calendar|\btin\b|demo|event pack',
    caseSensitive: false);

const _minCards = 20;

/// Relative odds for the "best card" slot. TCG core boosters from 2014:
/// Ultra about 1 in 6 packs, Secret about 1 in 12.
const _topSlotWeights = {'rare': 12, 'superRare': 9, 'ultraRare': 2, 'secretRare': 1};

/// Pre-2014 9-card boosters: one rare-or-better card per pack
/// (Super about 1 in 6, Ultra 1 in 12, Secret 1 in 24).
const _classicTopSlotWeights = {'rare': 17, 'superRare': 4, 'ultraRare': 2, 'secretRare': 1};

const _months = {
  'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6,
  'July': 7, 'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12,
};

final _http = CachedHttp('.cache/ygo-en', delay: const Duration(milliseconds: 250));

Future<void> main(List<String> arguments) async {
  final args = [...arguments];
  final listTypes = args.remove('--types');
  try {
    final lists = args.isNotEmpty
        ? [for (final set in args) 'Set Card Lists:$set (TCG-FR)']
        : await _frenchSetLists();
    final listPages = await _pages(lists.toSet());
    final setPages = await _pages({for (final list in lists) _setTitle(list)});

    if (listTypes) {
      final counts = <String, int>{};
      for (final list in lists) {
        final type = _clean(_templateFields(setPages[_setTitle(list)] ?? '', 'Infobox set')['type'] ?? '');
        counts[type] = (counts[type] ?? 0) + 1;
      }
      for (final e in counts.entries.toList()..sort((a, b) => b.value - a.value)) {
        stdout.writeln('${e.value.toString().padLeft(4)}  ${e.key}');
      }
      final untyped = lists.where((l) =>
          _clean(_templateFields(setPages[_setTitle(l)] ?? '', 'Infobox set')['type'] ?? '').isEmpty);
      stdout.writeln('No type: ${untyped.map(_setTitle).join(' | ')}');
      return;
    }

    // Every card printed in French gets its texts, even outside pack products,
    // so imported cubes can show them too.
    final allRows = <String, List<_Row>>{
      for (final list in lists) list: _manifestRows(listPages[list] ?? ''),
    };
    // Page title -> printed name ("Fiend Reflection 2" -> "Fiend Reflection #2").
    final cardTitles = {
      for (final rows in allRows.values)
        for (final row in rows) _pageTitle(row.card): row.card,
    };
    stdout.writeln('${lists.length} French lists, ${cardTitles.length} cards');
    final cardPages = await _pages(cardTitles.keys.toSet());
    final errataPages = await _pages({for (final t in cardTitles.keys) 'Card Errata:$t'});

    final texts = <String, Object?>{};
    final keys = <String, String>{};
    for (final MapEntry(key: title, value: printed) in cardTitles.entries) {
      final card = _templateFields(cardPages[title] ?? '', 'CardTable2');
      if (card.isEmpty) continue;
      final key = _nonEmpty(_clean(card['passcode'] ?? '')) ?? title;
      keys[title] = key;
      texts[key] = _versions(printed, card, errataPages['Card Errata:$title']);
    }

    final usedCodes = <String>{};
    var written = 0;
    for (final list in lists) {
      final set = _setTitle(list);
      try {
        if (await _importSet(set, allRows[list]!, setPages[set] ?? '', cardPages, keys, usedCodes,
            force: args.isNotEmpty)) {
          written++;
        }
      } catch (e) {
        stderr.writeln('$set: failed ($e)');
      }
    }

    // A run limited to some sets adds to the existing texts instead of replacing them.
    final textFile = File('assets/cards/ygo_texts.json');
    if (args.isNotEmpty && await textFile.exists()) {
      final previous = jsonDecode(await textFile.readAsString()) as Map<String, dynamic>;
      texts.addAll({...previous, ...texts});
    }
    await textFile.parent.create(recursive: true);
    await textFile.writeAsString(jsonEncode(texts));
    stdout.writeln('Wrote $written sets; texts for ${texts.length} cards '
        '(${(await textFile.length()) ~/ 1024} KB)');
    await rebuildIndex();
  } finally {
    _http.close();
  }
}

Future<bool> _importSet(
  String set,
  List<_Row> rows,
  String setPage,
  Map<String, String> cardPages,
  Map<String, String> keys,
  Set<String> usedCodes, {
  required bool force,
}) async {
  final infobox = _templateFields(setPage, 'Infobox set');
  final type = _clean(infobox['type'] ?? '');
  // Some booster pages leave `type` empty; keep them unless the title says
  // promo, deck, tin...
  final packProduct = _packTypes.contains(type) || (type.isEmpty && !_notPacks.hasMatch(set));
  if (!force && !packProduct) return false;
  if (rows.length < _minCards) {
    stdout.writeln('$set: ${rows.length} cards listed, skipped');
    return false;
  }

  var code = rows.first.id.split('-').first;
  for (var n = 2; usedCodes.contains(code); n++) {
    code = '${rows.first.id.split('-').first}$n';
  }
  usedCodes.add(code);

  final cards = [
    for (final row in rows)
      {
        'id': row.id,
        'names': {
          'en': _displayName(row.card),
          'fr': ?_nonEmpty(_cleanLore(
              _templateFields(cardPages[_pageTitle(row.card)] ?? '', 'CardTable2')['fr_name'] ?? '')),
        },
        'rarity': _rarity(row.rarity),
        'passcode': ?keys[_pageTitle(row.card)],
      },
  ];
  final releaseDate = _isoDate(_clean(infobox['fr_release_date'] ??
      infobox['fr/de/it/sp_release_date'] ??
      infobox['eu_release_date'] ??
      ''));
  final perPack = _cardsPerPack(setPage, type, cards);

  // 25th Anniversary reprints share the original's French name and codes.
  var frName = _nonEmpty(_clean(infobox['fr_name'] ?? ''));
  if (frName != null && set.contains('25th Anniversary Edition') && !frName.contains('25')) {
    frName = '$frName (25e anniversaire)';
  }

  await writeSet({
    'code': code,
    'prefix': rows.first.id.split('-').first,
    'game': 'ygo',
    'names': {'en': set, 'fr': ?frName},
    'releaseDate': releaseDate,
    'source': 'https://yugioh.fandom.com/wiki/${Uri.encodeComponent(set.replaceAll(' ', '_'))}',
    'license': 'Yu-Gi-Oh! Wiki (Fandom), CC BY-SA 3.0. '
        'Yu-Gi-Oh! est © Kazuki Takahashi / Konami.',
    'boosters': {'standard': _formula(cards, perPack, releaseDate)},
    'cards': cards,
  });
  final missingFr = cards.where((c) => !(c['names'] as Map).containsKey('fr')).length;
  stdout.writeln('$set: $code, ${cards.length} cards, $perPack per pack'
      '${missingFr > 0 ? ', $missingFr without French name' : ''}');
  return true;
}

// ---------------------------------------------------------------------------
// Card text versions

/// `{lang: [{n: name, t: text, p: [printings]}...]}`, oldest first. Cards
/// without errata get one version per language from their card page.
Map<String, Object?> _versions(String title, Map<String, String> card, String? errataPage) {
  String? current(String field) => _nonEmpty(_cleanLore(card[field] ?? ''));
  final result = <String, Object?>{};
  final errata = errataPage == null ? const <String, List<Map<String, Object?>>>{} : _errata(errataPage);

  for (final MapEntry(key: prefix, value: lang) in _languages.entries) {
    final name = prefix == 'en' ? _displayName(title) : current('${prefix}_name');
    final loreField = prefix == 'en' ? 'lore' : '${prefix}_lore';
    final pendulumField = prefix == 'en' ? 'pendulum_effect' : '${prefix}_pendulum_effect';
    final text = [current(pendulumField), current(loreField)].nonNulls.join('\n\n');

    final versions = errata[lang];
    if (versions != null && versions.isNotEmpty) {
      // A version only lists what changed (name, type line or text); the
      // rest carries over. Before the first listed value, use the earliest
      // one listed, else today's card page.
      for (final field in ['n', 't', 'k']) {
        final fallback = {'n': name, 't': text, 'k': null}[field];
        Object? last = versions.map((v) => v[field]).nonNulls.firstOrNull ?? fallback;
        for (final v in versions) {
          last = v[field] ?? last;
          if (last != null) v[field] = last;
        }
      }
      // The card page holds today's official text, which errata pages do not
      // always list yet.
      if (text.isNotEmpty && versions.last['t'] != text) {
        versions.add({'n': ?name, 't': text, 'p': const <String>[]});
      }
      result[lang] = versions;
    } else if (text.isNotEmpty || name != null) {
      result[lang] = [
        {'n': ?name, 't': text, 'p': const <String>[]},
      ];
    }
  }
  return result;
}

/// Parses each language section of a "Card Errata:" page.
Map<String, List<Map<String, Object?>>> _errata(String wikitext) {
  final bodies = <String, String>{};
  final sections = RegExp(r'^==\s*([^=]+?)\s*==\s*$', multiLine: true).allMatches(wikitext).toList();
  for (var i = 0; i < sections.length; i++) {
    bodies[sections[i].group(1)!] = wikitext.substring(
        sections[i].end, i + 1 < sections.length ? sections[i + 1].start : wikitext.length);
  }

  final result = <String, List<Map<String, Object?>>>{};
  for (final MapEntry(key: lang, value: headings) in _errataSections.entries) {
    final body = headings.map((h) => bodies[h]).nonNulls.firstOrNull;
    if (body == null) continue;
    final fields = _templateFields(body, 'Errata table');
    String? edited(String key) =>
        fields[key] == null ? null : _nonEmpty(_cleanLore(_applyEdits(fields[key]!)));
    final versions = result[lang] = [];
    for (var n = 0; fields.keys.any((k) => RegExp('^[a-z_]+$n\$').hasMatch(k)); n++) {
      final lore = [edited('pendulum_effect$n'), edited('lore$n')].nonNulls;
      versions.add({
        'n': ?edited('name$n'),
        'k': ?edited('card_type$n'),
        't': ?(lore.isEmpty ? null : lore.join('\n\n')),
        'p': [
          for (final m in RegExp(r'\[\[([A-Z0-9]+-[A-Z0-9]+)(?:\|[^\]]*)?\]\]')
              .allMatches(fields['cap$n'] ?? ''))
            m.group(1)!,
        ],
      });
    }
  }
  return result;
}

/// Errata tables annotate each version against its neighbours: `<ins>` is
/// new in this version, `<del>` is removed in the next one. Both are
/// printed on this version, so only the tags go.
String _applyEdits(String text) =>
    text.replaceAll(RegExp(r'</?(?:ins|del)>'), '').replaceAll(RegExp(r' {2,}'), ' ');

// ---------------------------------------------------------------------------
// Sets and formulas

class _Row {
  _Row(this.id, this.card, this.rarity);
  final String id, card, rarity;
}

final _printCode = RegExp(r'^[A-Z0-9]+-[A-Z]{1,2}\w*$');

/// Set lists come as `{{Set manifest|...}}` lines (`CODE; Card; Rarity[, Rarity]`)
/// or, on older pages, a wikitable (code | card | French name | rarity | category).
/// The card is kept as its page title ("Name (card)" when disambiguated).
List<_Row> _manifestRows(String wikitext) {
  final rows = <_Row>[];
  for (final line in wikitext.split('\n')) {
    final parts = line.split(';').map((p) => p.trim()).toList();
    if (parts.length < 3 || !_printCode.hasMatch(parts[0]) || parts[1].isEmpty) continue;
    rows.add(_Row(parts[0], parts[1], parts[2].split(',').first.trim()));
  }
  return rows.isNotEmpty ? rows : _tableRows(wikitext);
}

List<_Row> _tableRows(String wikitext) {
  final rows = <_Row>[];
  var cells = <String>[];
  void flush() {
    if (cells.length >= 3) {
      final code = _clean(cells[0]);
      final card = RegExp(r'\[\[([^\]|]+)').firstMatch(cells[1])?.group(1)?.trim();
      final rarity = cells.length >= 5 ? cells[3] : cells[2];
      if (_printCode.hasMatch(code) && card != null) {
        rows.add(_Row(code, card, _clean(rarity.split(RegExp(r'<br\s*/?>')).first)));
      }
    }
    cells = [];
  }

  for (final line in wikitext.split('\n').map((l) => l.trimLeft())) {
    if (line.startsWith('|-') || line.startsWith('|}')) {
      flush();
    } else if (line.startsWith('|')) {
      cells.addAll(line.substring(1).split('||').map((c) => c.trim()));
    }
  }
  flush();
  return rows;
}

/// Keyword mapping, so new foil names do not stop the import.
String _rarity(String wiki) {
  final r = wiki.toLowerCase();
  if (r.contains('secret') || r.contains('starlight') || r.contains('collector') ||
      r.contains('quarter century') || r.contains('premium gold')) {
    return 'secretRare';
  }
  if (r.contains('ultra') || r.contains('ultimate') || r.contains('ghost') ||
      r.contains('holographic') || r.contains('platinum') || r.contains('gold')) {
    return 'ultraRare';
  }
  if (r.contains('super') || r.contains('mosaic')) return 'superRare';
  if (r.contains('common') || r.contains('short print') || r.contains('normal')) return 'common';
  return 'rare';
}

/// Approximate formula: commons fill the pack, then one "best card" slot.
/// 9-card core boosters from 2014 on also guarantee a rare next to a foil
/// ([_topSlotWeights]); earlier ones had a single rare-or-better slot
/// ([_classicTopSlotWeights]).
Map<String, Object?> _formula(List<Map<String, Object?>> cards, int perPack, String? releaseDate) {
  final modern = releaseDate == null || releaseDate.compareTo('2014') >= 0;
  final byRarity = <String, List<int>>{};
  for (var i = 0; i < cards.length; i++) {
    (byRarity[cards[i]['rarity'] as String] ??= []).add(i);
  }
  final present = _topSlotWeights.keys.where(byRarity.containsKey).toList();
  final sheets = <String, Object?>{
    for (final MapEntry(key: rarity, value: indexes) in byRarity.entries)
      rarity: {'cards': [for (final i in indexes) [i, 1]]},
  };

  Map<String, Object?> variant(int weight, Map<String, int> contents) => {
        'weight': weight,
        'contents': {
          for (final MapEntry(:key, :value) in contents.entries)
            if (value > 0) key: value,
        },
      };

  final List<Map<String, Object?>> variants;
  if (!byRarity.containsKey('common')) {
    // All-foil product: the lowest rarity fills, one slot rolls higher.
    final base = present.first;
    final higher = present.skip(1).toList();
    variants = higher.isEmpty
        ? [variant(1, {base: perPack})]
        : [for (final top in higher) variant(_topSlotWeights[top]!, {base: perPack - 1, top: 1})];
  } else {
    final foils = present.where((r) => r != 'rare').toList();
    final rareSlot = modern && perPack >= 9 && byRarity.containsKey('rare') && foils.isNotEmpty;
    final top = rareSlot ? foils : present;
    final weights = !modern && perPack >= 9 ? _classicTopSlotWeights : _topSlotWeights;
    variants = top.isEmpty
        ? [variant(1, {'common': perPack})]
        : [
            for (final rarity in top)
              variant(weights[rarity]!, {
                'common': perPack - (rareSlot ? 2 : 1),
                if (rareSlot) 'rare': 1,
                rarity: 1,
              }),
          ];
  }
  return {'approximate': true, 'variants': variants, 'sheets': sheets};
}

int _cardsPerPack(String setPage, String type, List<Map<String, Object?>> cards) {
  // "In the ''[[TCG]]'', there are 9 cards per pack" / "Each ''[[TCG]]'' ... pack contained 9 cards".
  for (final sentence in setPage.split(RegExp(r'(?<=\.)\s|\n'))) {
    if (!sentence.contains('TCG')) continue;
    final match = RegExp(r'(\d+) cards per pack|pack contain(?:s|ed) (\d+) cards').firstMatch(sentence);
    if (match != null) return int.parse(match.group(1) ?? match.group(2)!);
  }
  if (type == 'Mega Pack') return 16;
  final rarities = cards.map((c) => c['rarity']).toSet();
  final coreLike = type == 'Booster Pack' && cards.length >= 80 &&
      rarities.containsAll(['common', 'rare']) && rarities.length >= 3;
  return coreLike ? 9 : 5;
}

// ---------------------------------------------------------------------------
// Wiki access

String _setTitle(String listTitle) =>
    listTitle.replaceFirst('Set Card Lists:', '').replaceFirst(RegExp(r' \(TCG-FR\)$'), '');

/// Every "Set Card Lists:... (TCG-FR)" page.
Future<List<String>> _frenchSetLists() async {
  final titles = <String>[];
  String? next;
  do {
    final json = await _get({
      'action': 'query',
      'list': 'allpages',
      'apnamespace': '122',
      'aplimit': '500',
      'apcontinue': ?next,
    });
    titles.addAll([
      for (final page in json['query']['allpages'] as List)
        if ((page['title'] as String).endsWith('(TCG-FR)')) page['title'] as String,
    ]);
    next = json['continue']?['apcontinue'] as String?;
  } while (next != null);
  return titles;
}

/// Fetches page wikitext 50 titles at a time, keyed by the requested title.
Future<Map<String, String>> _pages(Set<String> titles) async {
  final result = <String, String>{};
  final list = titles.toList();
  for (var i = 0; i < list.length; i += 50) {
    final batch = list.sublist(i, i + 50 > list.length ? list.length : i + 50);
    final json = await _get({
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'content',
      'rvslots': 'main',
      'redirects': '1',
      'titles': batch.join('|'),
    });
    final query = json['query'] as Map<String, dynamic>;
    final aliases = <String, String>{
      for (final key in ['normalized', 'redirects'])
        for (final m in (query[key] as List? ?? []).cast<Map<String, dynamic>>())
          m['to'] as String: m['from'] as String,
    };
    for (final page in (query['pages'] as List).cast<Map<String, dynamic>>()) {
      final revisions = page['revisions'] as List?;
      if (revisions == null) continue;
      var title = page['title'] as String;
      while (aliases.containsKey(title) && !batch.contains(title)) {
        title = aliases[title]!;
      }
      result[title] = revisions.first['slots']['main']['content'] as String;
    }
  }
  return result;
}

Future<Map<String, dynamic>> _get(Map<String, String?> params) async {
  final uri = Uri.parse(_api).replace(queryParameters: {
    for (final MapEntry(:key, :value) in params.entries) key: ?value,
    'format': 'json',
    'formatversion': '2',
  });
  final body = await _http.get(uri);
  if (body == null) throw HttpException('Not found: $uri');
  return jsonDecode(body) as Map<String, dynamic>;
}

// ---------------------------------------------------------------------------
// Wikitext helpers

/// Reads the top-level `| key = value` fields of [template].
Map<String, String> _templateFields(String wikitext, String template) {
  final start = wikitext.indexOf('{{$template');
  if (start < 0) return {};
  final fields = <String, String>{};
  String? key;
  final value = StringBuffer();
  for (final line in wikitext.substring(start).split('\n').skip(1).map((l) => l.trimLeft())) {
    final match = RegExp(r'^\|\s*([\w/]+)\s*=\s?(.*)$').firstMatch(line);
    if (match != null || line.startsWith('}}')) {
      if (key != null) fields[key] = value.toString().trim();
      if (match == null) break;
      key = match.group(1);
      value
        ..clear()
        ..write(match.group(2));
    } else {
      value.write('\n$line');
    }
  }
  return fields;
}

/// `March 8, 2002` -> `2002-03-08`.
String? _isoDate(String text) {
  final m = RegExp(r'(\w+) (\d{1,2}), (\d{4})').firstMatch(text);
  final month = m == null ? null : _months[m.group(1)];
  if (month == null) return null;
  return '${m!.group(3)}-${month.toString().padLeft(2, '0')}-${m.group(2)!.padLeft(2, '0')}';
}

String? _nonEmpty(String text) => text.isEmpty ? null : text;

String _displayName(String title) => title.replaceFirst(RegExp(r'\s*\(card\)$'), '');

/// MediaWiki titles cannot contain `#`: "Fiend Reflection #2" is "Fiend Reflection 2".
String _pageTitle(String card) => card.replaceAll('#', '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Card text: links keep their label, `{{Ruby|kanji|kana}}` keeps the kanji,
/// emphasis quotes and other tags go, `<br />` becomes a line break.
String _cleanLore(String text) => _clean(text
    .replaceAllMapped(RegExp(r'\{\{Ruby\|([^|}]*)\|[^}]*\}\}', caseSensitive: false), (m) => m.group(1)!));

String _clean(String text) => text
    .replaceAllMapped(
        RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'), (m) => m.group(2) ?? m.group(1)!)
    .replaceAll(RegExp(r'<br\s*/?>'), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r"'{2,}"), '')
    .replaceAll(RegExp(r'\{\{[^}]*\}\}'), '')
    .trim();
