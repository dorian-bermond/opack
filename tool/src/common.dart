// Shared helpers for the data importers. Run them from the project root.

import 'dart:convert';
import 'dart:io';

const userAgent = 'OpackImporter/0.1 (offline booster simulator)';

/// HTTP GET with an on-disk cache under `.cache/` and a pause between
/// network calls, so re-runs are cheap and sources are not hammered.
class CachedHttp {
  CachedHttp(this.cacheDir, {this.delay = const Duration(milliseconds: 120)});

  final String cacheDir;
  final Duration delay;
  final _client = HttpClient()
    ..userAgent = userAgent
    ..autoUncompress = true;

  /// Returns the body, or `null` on 404.
  Future<String?> get(Uri uri, {Map<String, String> headers = const {}}) async {
    final key = base64Url.encode(utf8.encode(uri.toString()));
    final file = File('$cacheDir/${key.length > 200 ? key.hashCode : key}');
    if (await file.exists()) {
      final cached = await file.readAsString();
      return cached.isEmpty ? null : cached;
    }

    await Future<void>.delayed(delay);
    final (response, bytes) = await _fetch(uri, headers);

    await file.create(recursive: true);
    if (response.statusCode == 404) {
      await file.writeAsString('');
      return null;
    }
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $uri');
    }
    final body = uri.path.endsWith('.gz')
        ? utf8.decode(gzip.decode(bytes))
        : utf8.decode(bytes);
    await file.writeAsString(body);
    return body;
  }

  /// Retries network failures and 429/5xx answers with a growing pause.
  Future<(HttpClientResponse, List<int>)> _fetch(Uri uri, Map<String, String> headers) async {
    for (var attempt = 1;; attempt++) {
      try {
        final request = await _client.getUrl(uri);
        headers.forEach(request.headers.set);
        final response = await request.close();
        final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
        final retryable = response.statusCode == 429 || response.statusCode >= 500;
        if (!retryable || attempt == 5) return (response, bytes);
      } on IOException {
        if (attempt == 5) rethrow;
      }
      await Future<void>.delayed(Duration(seconds: 2 * attempt * attempt));
    }
  }

  void close() => _client.close();
}

/// Windows cannot create files named after devices (CON, NUL, ...).
String assetFileName(String code) =>
    RegExp(r'^(CON|PRN|AUX|NUL|COM\d|LPT\d)$', caseSensitive: false).hasMatch(code)
        ? '${code}_'
        : code;

Future<void> writeSet(Map<String, Object?> set) async {
  final file = File('assets/sets/${set['game']}/${assetFileName(set['code'] as String)}.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(set));
}

/// Rewrites `assets/sets/index.json` from every bundled set file.
Future<void> rebuildIndex() async {
  final entries = <Map<String, Object?>>[];
  final files = Directory('assets/sets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'));
  for (final file in files) {
    final set = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    entries.add({
      'code': set['code'],
      'prefix': ?set['prefix'],
      'game': set['game'],
      'names': set['names'],
      'releaseDate': set['releaseDate'],
      'icon': ?set['icon'],
      'boosterTypes': (set['boosters'] as Map).keys.toList(),
      'cardCount': (set['cards'] as List).length,
      'path': file.path.replaceAll(r'\', '/'),
    });
  }
  entries.sort((a, b) => '${a['game']}/${a['code']}'.compareTo('${b['game']}/${b['code']}'));
  await File('assets/sets/index.json')
      .writeAsString(const JsonEncoder.withIndent(' ').convert(entries));
  stdout.writeln('Index: ${entries.length} sets');
}
