import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'app_update.dart';

/// Why an update could not be installed in place.
class UpdateInstallException implements Exception {
  const UpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The batch script that swaps the app's files once it has quit: it waits
/// for [exe] in [target] to be free (the app closing), copies [source]
/// over [target], starts the app again and removes [work], the folder the
/// update was staged in. When the app never closes or the copy fails, it
/// leaves the installed files alone as far as it got and starts the app
/// again all the same; what it did is appended to [log].
///
/// Paths are passed in quotes; `%` is doubled so the script reads them as
/// they are.
String updateScript({
  required String source,
  required String target,
  required String exe,
  required String work,
  required String log,
}) {
  String q(String path) => '"${path.replaceAll('%', '%%')}"';
  final program = q('$target\\$exe');
  return [
    '@echo off',
    'setlocal',
    'set tries=0',
    ':wait',
    // Opening the program for writing only works once it is closed.
    '2>nul (>>$program (call )) && goto copy',
    'set /a tries+=1',
    'if %tries% geq 60 (',
    '  echo the app did not close>>${q(log)}',
    '  goto start',
    ')',
    'ping -n 2 127.0.0.1 >nul',
    'goto wait',
    ':copy',
    'robocopy ${q(source)} ${q(target)} /E /R:5 /W:1 /NFL /NDL /NJH /NJS /NP >>${q(log)} 2>&1',
    // Robocopy answers 8 or more when files could not be copied.
    'if %errorlevel% geq 8 echo copy failed with %errorlevel%>>${q(log)}',
    ':start',
    'start "" $program',
    // Out of the staging folder before removing it.
    'cd /d ${q(target)}',
    'rmdir /s /q ${q(work)}',
    'endlocal',
    '',
  ].join('\r\n');
}

/// Installs an [AppUpdate] over the running Windows app: downloads the
/// release's zip, unpacks it beside, then hands over to a script that
/// replaces the files once the app has quit and starts it again.
class UpdateInstaller {
  UpdateInstaller({
    http.Client? client,
    Directory? installDirectory,
    String? executable,
    Directory? temporaryDirectory,
    Future<void> Function()? quit,
  })  : _client = client ?? http.Client(),
        installDirectory = installDirectory ?? File(Platform.resolvedExecutable).parent,
        executable = executable ?? Platform.resolvedExecutable.split(RegExp(r'[\\/]')).last,
        _temporary = temporaryDirectory ?? Directory.systemTemp,
        _quit = quit ?? _exit;

  final http.Client _client;

  /// The folder the app runs from, which the update replaces.
  final Directory installDirectory;

  /// The app's program in that folder (`opack.exe`).
  final String executable;
  final Directory _temporary;
  final Future<void> Function() _quit;

  static Future<void> _exit() async {
    // Leave pending writes (a pool being saved) a moment to finish.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    exit(0);
  }

  /// Whether the app's folder can be written without more rights (not
  /// under Program Files, say).
  Future<bool> canWrite() async {
    try {
      final probe = File('${installDirectory.path}\\.update-probe');
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Downloads and unpacks [update], telling the download's progress
  /// through [onProgress] (0 to 1, `null` when the size is unknown), and
  /// answers the staging folder: the unpacked app in `app`, checked to
  /// hold the program. Throws an [UpdateInstallException] otherwise.
  Future<Directory> stage(AppUpdate update, {void Function(double? progress)? onProgress}) async {
    final url = update.download;
    if (url == null) throw const UpdateInstallException('this release has no Windows build');
    if (!await canWrite()) {
      throw UpdateInstallException('the app folder cannot be written: ${installDirectory.path}');
    }
    final work = await _temporary.createTemp('opack-update-');
    try {
      final zip = File('${work.path}\\update.zip');
      final response = await _client.send(http.Request('GET', url)..headers['User-Agent'] = 'Opack');
      if (response.statusCode != 200) {
        throw UpdateInstallException('${url.host} answered ${response.statusCode}');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = zip.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total == null || total <= 0 ? null : received / total);
        }
      } finally {
        await sink.close();
      }
      if (total != null && total > 0 && received != total) {
        throw const UpdateInstallException('the download was cut short');
      }
      final app = Directory('${work.path}\\app');
      await unpack(zip, app);
      if (!await File('${app.path}\\$executable').exists()) {
        throw UpdateInstallException('the download does not hold $executable');
      }
      await zip.delete();
      return work;
    } catch (_) {
      await work.delete(recursive: true).catchError((_) => work);
      rethrow;
    }
  }

  /// Unpacks [zip] into [into] with PowerShell, which every Windows has.
  Future<void> unpack(File zip, Directory into) async {
    String q(String path) => "'${path.replaceAll("'", "''")}'";
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      // Stop on the first error, so a broken zip answers a failure.
      "\$ErrorActionPreference = 'Stop'; "
          'Expand-Archive -LiteralPath ${q(zip.path)} -DestinationPath ${q(into.path)} -Force',
    ]);
    if (result.exitCode != 0) {
      throw UpdateInstallException('could not unpack the update: ${'${result.stderr}'.trim()}');
    }
  }

  /// Starts the script replacing the app with what [staged] holds (see
  /// [stage]) and quits; the script starts the new version.
  Future<void> applyAndRestart(Directory staged) async {
    await startSwap(staged);
    await _quit();
  }

  /// Writes and starts the swap script, on its own so it outlives the app.
  /// The script and its log stay in the temporary folder, outside [staged].
  Future<File> startSwap(Directory staged) async {
    final name = staged.path.split(RegExp(r'[\\/]')).last;
    final script = File('${_temporary.path}\\$name.cmd');
    await script.writeAsString(updateScript(
      source: '${staged.path}\\app',
      target: installDirectory.path,
      exe: executable,
      work: staged.path,
      log: '${_temporary.path}\\$name.log',
    ));
    await Process.start('cmd', ['/c', script.path], mode: ProcessStartMode.detached);
    return script;
  }
}

/// Installs updates in place where that is possible: on Windows. `null`
/// elsewhere, where an update is a download to install by hand.
final updateInstallerProvider = Provider<UpdateInstaller?>(
  (ref) => Platform.isWindows ? UpdateInstaller() : null,
);
