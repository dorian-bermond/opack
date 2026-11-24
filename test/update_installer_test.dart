import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opack/core/update/app_update.dart';
import 'package:opack/core/update/update_installer.dart';

void main() {
  test('the swap script waits for the app, copies, restarts and cleans up', () {
    final script = updateScript(
      source: r'C:\Temp\opack-update-1\app',
      target: r'C:\Apps\100% Opack',
      exe: 'opack.exe',
      work: r'C:\Temp\opack-update-1',
      log: r'C:\Temp\opack-update-1.log',
    );
    final lines = script.split('\r\n');
    expect(lines, contains(r'2>nul (>>"C:\Apps\100%% Opack\opack.exe" (call )) && goto copy'));
    expect(
      lines.where((l) => l.startsWith('robocopy')).single,
      startsWith(r'robocopy "C:\Temp\opack-update-1\app" "C:\Apps\100%% Opack" /E '),
    );
    expect(lines, contains(r'start "" "C:\Apps\100%% Opack\opack.exe"'));
    expect(lines, contains(r'rmdir /s /q "C:\Temp\opack-update-1"'));
    expect(lines.indexWhere((l) => l.startsWith('robocopy')), lessThan(lines.indexWhere((l) => l.startsWith('start'))));
  });

  group('on Windows', skip: Platform.isWindows ? null : 'the in-place update is for Windows', () {
    late Directory root;
    late Directory install;
    late Directory temp;

    /// A zip of [files] (name to content), made as the release workflow does.
    Future<List<int>> zipOf(Map<String, String> files) async {
      final source = await Directory('${root.path}\\zip-${files.length}-${files.keys.join().hashCode}').create();
      for (final MapEntry(key: name, value: content) in files.entries) {
        final file = File('${source.path}\\$name');
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
      }
      final zip = File('${source.path}.zip');
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "Compress-Archive -Path '${source.path}\\*' -DestinationPath '${zip.path}'",
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return zip.readAsBytes();
    }

    UpdateInstaller installer(http.Client client) => UpdateInstaller(
          client: client,
          installDirectory: install,
          executable: 'app.cmd',
          temporaryDirectory: temp,
          quit: () async {},
        );

    final update = AppUpdate(
      version: '2.0.0',
      page: Uri.parse('https://example.test/page'),
      download: Uri.parse('https://example.test/opack-v2.0.0-windows-x64.zip'),
    );

    setUp(() async {
      root = await Directory.systemTemp.createTemp('opack-installer-test-');
      install = await Directory('${root.path}\\My App').create();
      temp = await Directory('${root.path}\\temp').create();
      // The "program" tells it ran by writing its version beside itself.
      await File('${install.path}\\app.cmd').writeAsString('@echo v1>"%~dp0started.txt"\r\n');
      await File('${install.path}\\data.txt').writeAsString('old');
      await File('${install.path}\\keep.txt').writeAsString('mine');
    });

    tearDown(() async {
      // The restarted "program" may still hold the folder for a moment.
      for (var i = 0; i < 10; i++) {
        try {
          await root.delete(recursive: true);
          return;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    });

    test('downloads, unpacks, replaces the files and starts the new version', () async {
      final zip = await zipOf({
        'app.cmd': '@echo v2>"%~dp0started.txt"\r\n',
        'data.txt': 'new',
        'data\\flutter_assets\\x.txt': 'asset',
      });
      final progress = <double?>[];
      final subject = installer(MockClient.streaming((request, _) async {
        expect('${request.url}', '${update.download}');
        // In two chunks, with its length: the progress can be told.
        final half = zip.length ~/ 2;
        return http.StreamedResponse(
          Stream.fromIterable([zip.sublist(0, half), zip.sublist(half)]),
          200,
          contentLength: zip.length,
        );
      }));

      final staged = await subject.stage(update, onProgress: progress.add);
      expect(progress.last, 1);
      expect(progress.first, lessThan(1));
      expect(await File('${staged.path}\\app\\app.cmd').exists(), isTrue);
      expect(await File('${staged.path}\\update.zip').exists(), isFalse, reason: 'the zip goes once unpacked');
      expect(await File('${install.path}\\data.txt').readAsString(), 'old', reason: 'nothing installed yet');

      await subject.applyAndRestart(staged);
      // The script runs on its own: wait for the new version to start.
      final started = File('${install.path}\\started.txt');
      for (var i = 0; i < 100 && !await started.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(await started.exists(), isTrue, reason: 'the app was started again');
      expect((await started.readAsString()).trim(), 'v2');
      expect(await File('${install.path}\\data.txt').readAsString(), 'new');
      expect(await File('${install.path}\\data\\flutter_assets\\x.txt').readAsString(), 'asset');
      expect(await File('${install.path}\\keep.txt').readAsString(), 'mine', reason: 'other files are left alone');
      for (var i = 0; i < 50 && await staged.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(await staged.exists(), isFalse, reason: 'the staging folder is removed');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a refused or broken download installs nothing and leaves no staging folder', () async {
      Future<void> fails(http.Client client, Matcher message) async {
        await expectLater(
          installer(client).stage(update),
          throwsA(isA<UpdateInstallException>().having((e) => e.message, 'message', message)),
        );
        expect(temp.listSync(), isEmpty);
        expect(await File('${install.path}\\data.txt').readAsString(), 'old');
      }

      await fails(MockClient((_) async => http.Response('', 404)), contains('404'));
      final other = await zipOf({'readme.txt': 'not the app'});
      await fails(MockClient((_) async => http.Response.bytes(other, 200)), contains('app.cmd'));
      await fails(MockClient((_) async => http.Response.bytes([1, 2, 3], 200)), contains('unpack'));
      await expectLater(
        installer(MockClient((_) async => http.Response('', 200)))
            .stage(AppUpdate(version: '2.0.0', page: update.page)),
        throwsA(isA<UpdateInstallException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
