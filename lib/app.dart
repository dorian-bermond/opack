import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/settings/locale_controller.dart';
import 'l10n/app_localizations.dart';

class OpackApp extends ConsumerWidget {
  const OpackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AppShortcuts(child: child!),
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        ),
      );
}

/// The shortcuts that hold everywhere, whatever has the focus: Ctrl+,
/// opens the settings, Alt+Left (or the browser-back key) goes back.
/// Screens add their own with [CallbackShortcuts].
class AppShortcuts extends StatefulWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends State<AppShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handle);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handle);
    super.dispose();
  }

  bool _handle(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keys = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.comma && (keys.isControlPressed || keys.isMetaPressed)) {
      if (router.state.uri.path != '/settings') router.push('/settings');
      return true;
    }
    final back = event.logicalKey == LogicalKeyboardKey.browserBack ||
        (event.logicalKey == LogicalKeyboardKey.arrowLeft && keys.isAltPressed);
    if (back && router.canPop()) {
      router.pop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
