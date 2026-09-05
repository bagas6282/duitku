import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/formatters.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'features/auth/lock_screen.dart';
import 'features/shell/home_shell.dart';

Future<void> main() async {
  // Surface startup failures in the UI instead of letting them become an
  // unhandled exception: bootstrap walks the database and the preference
  // store, either of which can fail on a device with a full disk or a
  // database left behind by an older build.
  ErrorWidget.builder = (details) => StartupErrorScreen(
        details: details,
        embedApp: false,
      );

  WidgetsFlutterBinding.ensureInitialized();
  // Locale data must be loaded before any Indonesian date is formatted.
  await Formatters.init();

  try {
    final state = await AppState.bootstrap();
    runApp(DuitkuApp(state: state));
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StartupErrorScreen(error: error),
      ),
    );
  }
}

/// Shown when the app cannot reach a usable state at startup.
///
/// The alternative — a blank screen or an instant close — gives the user
/// nothing to act on and nothing to report. [embedApp] is false when this
/// widget is used as `ErrorWidget.builder`, because that already renders
/// inside a MaterialApp and nesting another one would throw.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    super.key,
    this.error,
    this.details,
    this.embedApp = true,
  });

  final Object? error;
  final FlutterErrorDetails? details;
  final bool embedApp;

  @override
  Widget build(BuildContext context) {
    final message = error ?? details?.exception ?? 'Unknown error';

    final content = Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Duitku failed to start',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your data is still on the device. Reopening the app '
                    'usually fixes this; if it keeps happening, the '
                    'database may need to be restored from a backup.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '$message',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!embedApp) return content;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: content,
    );
  }
}

class DuitkuApp extends StatelessWidget {
  const DuitkuApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, s, _) {
          final language = AppLanguage.fromCode(s.localeCode);
          // LanguageScope sits *inside* the Consumer so a change in Settings
          // rebuilds every label, and outside MaterialApp so pushed routes
          // (which build under the Navigator) can read it too.
          return LanguageScope(
            language: language,
            child: MaterialApp(
              title: 'Duitku',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: s.themeMode,
              locale: Locale(language.code),
              builder: (context, child) {
                // Cap text scaling so the layout survives large accessibility
                // settings without blowing up cards.
                final scale = MediaQuery.textScalerOf(context).clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.25,
                );
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scale),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: s.locked ? const LockScreen() : const HomeShell(),
            ),
          );
        },
      ),
    );
  }
}
