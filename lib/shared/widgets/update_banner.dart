import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/update/app_update.dart';
import '../../core/update/update_installer.dart';
import '../../l10n/app_localizations.dart';

/// Opens [update]'s download (or its page), telling when nothing could
/// open it.
Future<void> openUpdate(BuildContext context, WidgetRef ref, AppUpdate update) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await ref.read(updateOpenerProvider)(update.target);
  } catch (_) {
    opened = false;
  }
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(l10n.updateOpenFailed('${update.target}'))));
}

/// Installs [update] over the running app (Windows): a dialog shows the
/// download, then the app quits and comes back as the new version. When it
/// cannot be done, the dialog says why and offers the plain download.
Future<void> installUpdate(BuildContext context, WidgetRef ref, AppUpdate update) async {
  final installer = ref.read(updateInstallerProvider);
  if (installer == null) return openUpdate(context, ref, update);
  final download = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _InstallDialog(installer: installer, update: update),
  );
  if (download == true && context.mounted) await openUpdate(context, ref, update);
}

/// The button getting [update]: installing it in place where the app can
/// (and the release has a build for it), else downloading it.
class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key, required this.update, required this.prefix});

  final AppUpdate update;

  /// Tells the banner's button from the settings' one in keys.
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inPlace = update.download != null && ref.watch(updateInstallerProvider) != null;
    return inPlace
        ? FilledButton.tonal(
            key: Key('${prefix}Install'),
            onPressed: () => installUpdate(context, ref, update),
            child: Text(l10n.updateInstall),
          )
        : FilledButton.tonal(
            key: Key('${prefix}Download'),
            onPressed: () => openUpdate(context, ref, update),
            child: Text(l10n.updateDownload),
          );
  }
}

/// Downloads and unpacks the update, then restarts; pops `true` when the
/// user asks for the plain download after a failure.
class _InstallDialog extends StatefulWidget {
  const _InstallDialog({required this.installer, required this.update});

  final UpdateInstaller installer;
  final AppUpdate update;

  @override
  State<_InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<_InstallDialog> {
  double? _progress = 0;
  bool _restarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final staged = await widget.installer.stage(widget.update, onProgress: (progress) {
        // Not on every chunk: a frame's worth of change at most.
        if (mounted && (progress == null || _progress == null || (progress - _progress!).abs() >= 0.01)) {
          setState(() => _progress = progress);
        }
      });
      if (!mounted) return;
      setState(() => _restarting = true);
      await widget.installer.applyAndRestart(staged);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = _error;
    return AlertDialog(
      key: const Key('updateInstallDialog'),
      title: Text(l10n.updateInstalling(widget.update.version)),
      content: SizedBox(
        width: 360,
        child: error != null
            ? Text(l10n.updateInstallFailed(error), style: TextStyle(color: theme.colorScheme.error))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_restarting ? l10n.updateRestarting : l10n.updateDownloading),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _restarting ? null : _progress),
                ],
              ),
      ),
      actions: error == null
          ? null
          : [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              FilledButton(
                key: const Key('updateInstallFallback'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.updateDownload),
              ),
            ],
    );
  }
}

/// A line above the main screen when a newer version is out: get it (see
/// [UpdateButton]), or skip that version. Nothing when the app is up to date, the check at
/// launch is off, the check failed, or the version was skipped.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(updatePreferencesProvider);
    if (!preferences.atLaunch) return const SizedBox.shrink();
    final update = ref.watch(appUpdateProvider).value;
    if (update == null || update.version == preferences.skipped) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      key: const Key('updateBanner'),
      leading: const Icon(Icons.system_update_alt),
      content: Text(l10n.updateAvailable(update.version)),
      actions: [
        TextButton(
          key: const Key('updateSkip'),
          onPressed: () => ref.read(updatePreferencesProvider.notifier).skip(update.version),
          child: Text(l10n.updateSkip),
        ),
        UpdateButton(update: update, prefix: 'update'),
      ],
    );
  }
}

/// The settings' update lines: the version running with a button checking
/// for a newer one and what the check found, and whether to check at launch.
class UpdateSettings extends ConsumerWidget {
  const UpdateSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).value;
    final check = ref.watch(appUpdateProvider);
    final preferences = ref.watch(updatePreferencesProvider);
    // Nothing to tell before a first check.
    final checked = preferences.atLaunch || ref.watch(updateCheckRequestsProvider) > 0;
    final status = switch (check) {
      _ when !checked => '',
      AsyncValue(isLoading: true) => l10n.updateChecking,
      AsyncError(:final error) => l10n.updateCheckFailed('$error'),
      AsyncData(value: final update?) => l10n.updateAvailable(update.version),
      _ => l10n.updateUpToDate,
    };
    final update = check.isLoading ? null : check.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('settingUpdate'),
          title: Text(version == null ? l10n.appTitle : l10n.updateCurrentVersion(version)),
          subtitle: status.isEmpty
              ? null
              : Text(
                  status,
                  style: check.hasError && !check.isLoading ? TextStyle(color: theme.colorScheme.error) : null,
                ),
          trailing: Wrap(
            spacing: 8,
            children: [
              if (update != null)
                UpdateButton(update: update, prefix: 'settingUpdate'),
              OutlinedButton(
                key: const Key('settingUpdateCheck'),
                onPressed: check.isLoading ? null : ref.read(updateCheckRequestsProvider.notifier).checkNow,
                child: Text(l10n.updateCheckNow),
              ),
            ],
          ),
        ),
        SwitchListTile(
          key: const Key('settingUpdateAtLaunch'),
          title: Text(l10n.updateCheckAtLaunch),
          value: preferences.atLaunch,
          onChanged: ref.read(updatePreferencesProvider.notifier).setAtLaunch,
        ),
      ],
    );
  }
}
