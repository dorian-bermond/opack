import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/core/update/app_update.dart';
import 'package:opack/core/update/update_installer.dart';
import 'package:opack/features/card_text/data/card_text_repository.dart';
import 'package:opack/l10n/app_localizations.dart';
import 'package:opack/shared/widgets/update_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _release(String tag) => jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/dorian-bermond/opack/releases/tag/$tag',
      'assets': [
        for (final name in ['android.apk', 'android.aab', 'windows-x64.zip', 'linux-x64.tar.gz', 'macos-unsigned.zip'])
          {'name': 'opack-$tag-$name', 'browser_download_url': 'https://dl/opack-$tag-$name'},
      ],
    });

UpdateChecker _checker(String latest, {String current = '1.2.0', TargetPlatform platform = TargetPlatform.windows}) =>
    UpdateChecker(
      client: MockClient((request) async {
        expect(request.url.path, '/repos/dorian-bermond/opack/releases/latest');
        return http.Response(_release(latest), 200);
      }),
      currentVersion: () async => current,
      platform: platform,
    );

void main() {
  test('versions compare number by number', () {
    expect(isNewerVersion('1.3.0', '1.2.0'), isTrue);
    expect(isNewerVersion('1.10.0', '1.9.3'), isTrue);
    expect(isNewerVersion('v2.0.0', '1.9.9+12'), isTrue);
    expect(isNewerVersion('1.2.1', '1.2'), isTrue);
    expect(isNewerVersion('1.2.0', '1.2.0+3'), isFalse);
    expect(isNewerVersion('1.1.9', '1.2.0'), isFalse);
  });

  test('a newer release is an update with this platform build; the same or an older one is none', () async {
    final update = (await _checker('v1.3.0').check())!;
    expect(update.version, '1.3.0');
    expect('${update.target}', 'https://dl/opack-v1.3.0-windows-x64.zip');
    expect('${update.page}', 'https://github.com/dorian-bermond/opack/releases/tag/v1.3.0');
    expect('${(await _checker('v1.3.0', platform: TargetPlatform.android).check())!.target}',
        'https://dl/opack-v1.3.0-android.apk');
    final ios = (await _checker('v1.3.0', platform: TargetPlatform.iOS).check())!;
    expect(ios.download, isNull);
    expect(ios.target, ios.page, reason: 'no build to download: the page');
    expect(await _checker('v1.2.0').check(), isNull);
    expect(await _checker('v1.1.0').check(), isNull);
  });

  test('no release yet is no update; a refusal is an error', () async {
    UpdateChecker answering(int status) => UpdateChecker(
          client: MockClient((_) async => http.Response('', status)),
          currentVersion: () async => '1.2.0',
        );
    expect(await answering(404).check(), isNull);
    expect(answering(403).check(), throwsException);
  });

  testWidgets('the banner offers the download, or to skip the version; settings check on demand', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var latest = 'v1.3.0';
    var checks = 0;
    final opened = <Uri>[];
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      updateCheckerProvider.overrideWithValue(UpdateChecker(
        client: MockClient((_) async {
          checks++;
          return http.Response(_release(latest), 200);
        }),
        currentVersion: () async => '1.2.0',
        platform: TargetPlatform.windows,
      )),
      updateInstallerProvider.overrideWithValue(null),
      updateOpenerProvider.overrideWithValue((url) async {
        opened.add(url);
        return true;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Column(children: [UpdateBanner(), UpdateSettings()])),
      ),
    ));
    await tester.pumpAndSettle();

    // Checked at launch: the banner and the settings both tell.
    expect(checks, 1);
    expect(find.byKey(const Key('updateBanner')), findsOneWidget);
    expect(find.text('Version 1.3.0 is available'), findsNWidgets(2));
    expect(find.text('Opack 1.2.0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('updateDownload')));
    await tester.pumpAndSettle();
    expect(opened.map((u) => '$u'), ['https://dl/opack-v1.3.0-windows-x64.zip']);

    // Skipped: the banner goes for that version, the settings still offer it.
    await tester.tap(find.byKey(const Key('updateSkip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('updateBanner')), findsNothing);
    expect(prefs.getString('updateSkippedVersion'), '1.3.0');
    expect(find.byKey(const Key('settingUpdateDownload')), findsOneWidget);
    expect(checks, 1, reason: 'skipping does not check again');

    // A newer one is announced again, found by a check asked for.
    latest = 'v1.4.0';
    await tester.tap(find.byKey(const Key('settingUpdateCheck')));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.byKey(const Key('updateBanner')), findsOneWidget);
    expect(find.text('Version 1.4.0 is available'), findsNWidgets(2));

    // With the check at launch off, no banner; a check asked for still answers.
    await tester.tap(find.byKey(const Key('settingUpdateAtLaunch')));
    await tester.pumpAndSettle();
    expect(prefs.getBool('updateCheckAtLaunch'), isFalse);
    expect(find.byKey(const Key('updateBanner')), findsNothing);
    latest = 'v1.2.0';
    await tester.tap(find.byKey(const Key('settingUpdateCheck')));
    await tester.pumpAndSettle();
    expect(find.text('This is the latest version'), findsOneWidget);
    expect(find.byKey(const Key('settingUpdateDownload')), findsNothing);
  });

  testWidgets('with the check at launch off nothing is asked until the user checks', (tester) async {
    SharedPreferences.setMockInitialValues({'updateCheckAtLaunch': false});
    final prefs = await SharedPreferences.getInstance();
    var checks = 0;
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      updateCheckerProvider.overrideWithValue(UpdateChecker(
        client: MockClient((_) async {
          checks++;
          return http.Response(_release('v9.0.0'), 200);
        }),
        currentVersion: () async => '1.2.0',
        platform: TargetPlatform.windows,
      )),
      updateInstallerProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Column(children: [UpdateBanner(), UpdateSettings()])),
      ),
    ));
    await tester.pumpAndSettle();
    expect(checks, 0);
    expect(find.byKey(const Key('updateBanner')), findsNothing);
    expect(find.textContaining('available'), findsNothing);
    await tester.tap(find.byKey(const Key('settingUpdateCheck')));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(find.text('Version 9.0.0 is available'), findsOneWidget);
  });
}
