import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/card_text/data/card_text_repository.dart';

/// A release of the app newer than the one running: its [version]
/// (`1.3.0`), its page on GitHub and, when the release has a build for
/// this platform, the file to [download].
class AppUpdate {
  const AppUpdate({required this.version, required this.page, this.download});

  final String version;
  final Uri page;
  final Uri? download;

  /// What to open to get the update: this platform's build, else the page.
  Uri get target => download ?? page;
}

/// Whether version [a] is newer than [b], number by number (`1.10.0` is
/// newer than `1.9.3`); a build suffix (`+3`) or a leading `v` is ignored.
bool isNewerVersion(String a, String b) {
  List<int> parts(String v) => [
        for (final part in v.replaceFirst(RegExp('^v'), '').split('+').first.split('.'))
          int.tryParse(RegExp(r'^\d+').firstMatch(part)?.group(0) ?? '') ?? 0,
      ];
  final (x, y) = (parts(a), parts(b));
  for (var i = 0; i < x.length || i < y.length; i++) {
    final (m, n) = (i < x.length ? x[i] : 0, i < y.length ? y[i] : 0);
    if (m != n) return m > n;
  }
  return false;
}

/// How this platform's build is named in a release (see the release
/// workflow): the end of its file name; `null` where none can be installed
/// from a download (iOS).
String? updateAssetSuffix(TargetPlatform platform) => switch (platform) {
      TargetPlatform.windows => '-windows-x64.zip',
      TargetPlatform.android => '-android.apk',
      TargetPlatform.linux => '-linux-x64.tar.gz',
      TargetPlatform.macOS => '-macos-unsigned.zip',
      TargetPlatform.iOS || TargetPlatform.fuchsia => null,
    };

/// Asks GitHub for the app's latest release.
class UpdateChecker {
  UpdateChecker({http.Client? client, Future<String> Function()? currentVersion, TargetPlatform? platform})
      : _client = client ?? http.Client(),
        _currentVersion = currentVersion ?? _installedVersion,
        _platform = platform ?? defaultTargetPlatform;

  final http.Client _client;
  final Future<String> Function() _currentVersion;
  final TargetPlatform _platform;

  static const repository = 'dorian-bermond/opack';
  static final _latest = Uri.https('api.github.com', '/repos/$repository/releases/latest');

  static Future<String> _installedVersion() async => (await PackageInfo.fromPlatform()).version;

  /// The version running.
  Future<String> currentVersion() => _currentVersion();

  /// The latest release when it is newer than the app, else `null`.
  /// Throws when GitHub cannot be reached or refuses.
  Future<AppUpdate?> check() async {
    final current = await _currentVersion();
    final response = await _client.get(_latest, headers: const {
      'User-Agent': 'Opack',
      'Accept': 'application/vnd.github+json',
    });
    // No release published yet.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw HttpException('api.github.com ${response.statusCode}');
    final release = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final tag = release['tag_name'] as String? ?? '';
    final version = tag.replaceFirst(RegExp('^v'), '');
    if (version.isEmpty || !isNewerVersion(version, current)) return null;
    final suffix = updateAssetSuffix(_platform);
    Uri? download;
    for (final asset in (release['assets'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      if ((asset['name'], asset['browser_download_url']) case (final String name, final String url)
          when suffix != null && name.endsWith(suffix)) {
        download = Uri.tryParse(url);
      }
    }
    return AppUpdate(
      version: version,
      page: Uri.tryParse(release['html_url'] as String? ?? '') ??
          Uri.https('github.com', '/$repository/releases/latest'),
      download: download,
    );
  }
}

/// `null` disables update checks (tests).
final updateCheckerProvider = Provider<UpdateChecker?>((ref) => UpdateChecker());

/// Whether this build looks for updates: release builds only. A debug
/// build carries whatever version its runner was last built with (the
/// Windows one keeps an old version resource), so it would take a
/// release of its own code for a newer one. Tests override it.
final updateChecksAllowedProvider = Provider<bool>((ref) => !kDebugMode);

/// Opens an update's file or page outside the app (the browser downloads
/// it); answers whether something opened.
final updateOpenerProvider = Provider<Future<bool> Function(Uri url)>(
  (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// The version running, `null` when it cannot be told.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    return await ref.watch(updateCheckerProvider)?.currentVersion();
  } catch (_) {
    return null;
  }
});

/// How many times the user asked for a check; each one checks again.
final updateCheckRequestsProvider = NotifierProvider<UpdateCheckRequests, int>(UpdateCheckRequests.new);

class UpdateCheckRequests extends Notifier<int> {
  @override
  int build() => 0;

  void checkNow() => state++;
}

/// The update found by the last check: `null` when the app is up to date,
/// when checks are disabled, or when none was made (the check at launch
/// off and none asked for); an error when GitHub could not be asked.
final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  final checker = ref.watch(updateCheckerProvider);
  final asked = ref.watch(updateCheckRequestsProvider) > 0;
  final atLaunch = ref.watch(updatePreferencesProvider.select((p) => p.atLaunch));
  if (checker == null || !ref.watch(updateChecksAllowedProvider) || !(asked || atLaunch)) return null;
  return checker.check();
});

/// What the user chose about updates, saved across launches: whether the
/// app looks for one when it starts (on by default) and the version they
/// asked not to hear about again.
typedef UpdatePreferences = ({bool atLaunch, String? skipped});

final updatePreferencesProvider =
    NotifierProvider<UpdatePreferencesSetting, UpdatePreferences>(UpdatePreferencesSetting.new);

class UpdatePreferencesSetting extends Notifier<UpdatePreferences> {
  static const _atLaunchKey = 'updateCheckAtLaunch';
  static const _skippedKey = 'updateSkippedVersion';

  @override
  UpdatePreferences build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return (atLaunch: prefs.getBool(_atLaunchKey) ?? true, skipped: prefs.getString(_skippedKey));
  }

  void setAtLaunch(bool enabled) {
    ref.read(sharedPreferencesProvider).setBool(_atLaunchKey, enabled);
    state = (atLaunch: enabled, skipped: state.skipped);
  }

  /// Stops announcing [version]; a newer one is announced again.
  void skip(String version) {
    ref.read(sharedPreferencesProvider).setString(_skippedKey, version);
    state = (atLaunch: state.atLaunch, skipped: version);
  }
}
