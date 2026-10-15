import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/firebase_options.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_controller.dart';
import 'providers/theme_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    // Debug builds only: log each DISTINCT framework exception as short
    // prefixed console lines and collapse the repeat spam that follows —
    // repeats are almost always downstream consequences of the first failure.
    final seen = <String>{};
    void handle(String exception, String? info, StackTrace? stack) {
      final sig = exception.split('\n').first.trim();
      if (!seen.add(sig)) return;
      debugPrint('FR-ERR: $sig');
      if (info != null) debugPrint('FR-WGT: $info');
      if (stack != null) {
        for (final line in stack.toString().split('\n').take(30)) {
          debugPrint('FR-STK: $line');
        }
      }
    }

    FlutterError.onError = (details) {
      handle(details.exception.toString(),
          details.informationCollector?.call().join(' | '), details.stack);
      FlutterError.presentError(details);
    };
    // Platform-dispatched exceptions (pointers, focus) bypass FlutterError.
    PlatformDispatcher.instance.onError = (e, st) {
      handle(e.toString(), null, st);
      return false;
    };
    return true;
  }());
  // A build without Firebase config used to be a blank white page (Firebase
  // Auth throws during start-up). Say what's wrong instead.
  final missing = {
    'FIREBASE_API_KEY': kFirebaseApiKey,
    'FIREBASE_PROJECT_ID': kFirebaseProjectId,
    'FIREBASE_APP_ID': kFirebaseAppId,
  }.entries.where((e) => e.value.isEmpty || e.value.startsWith('YOUR-'));
  if (missing.isNotEmpty) {
    runApp(_StartupError(
        'This build has no Firebase configuration '
        '(${missing.map((e) => e.key).join(', ')}).'));
    return;
  }
  try {
    await Firebase.initializeApp(options: defaultFirebaseOptions);
    // Local testing only: `--dart-define=USE_EMULATORS=true` points the app
    // at the Firebase emulators (firebase emulators:start --only auth,firestore)
    // so nothing touches the live project. Never set in real builds.
    if (kUseEmulators) {
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8085);
    }
  } catch (e) {
    runApp(_StartupError('Could not connect to Firebase: $e'));
    return;
  }
  runApp(const ProviderScope(child: FoodRushApp()));
}

/// Shown instead of a blank page when the app can't start at all.
class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: FrColors.primary),
                  const SizedBox(height: 16),
                  const Text('FoodRush can\'t start',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'If you run this site: set the FIREBASE_* environment '
                    'variables for this deployment and redeploy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One cached ThemeData per mode: a fresh instance per build makes
/// MaterialApp see a "new" theme every frame.
final Map<bool, ThemeData> _themes = {};

class FoodRushApp extends ConsumerStatefulWidget {
  const FoodRushApp({super.key});

  @override
  ConsumerState<FoodRushApp> createState() => _FoodRushAppState();
}

class _FoodRushAppState extends ConsumerState<FoodRushApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // "System" mode follows the device switching light/dark while open.
  @override
  void didChangePlatformBrightness() => setState(() {});

  bool _resolveDark(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  /// FrColors' neutrals are read directly by widgets, not through Theme, so
  /// a mode flip must rebuild every element, not just Theme dependents.
  void _rebuildEverything() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      (context as Element).visitChildren(mark);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = _resolveDark(ref.watch(themeModeProvider));
    if (dark != FrColors.dark) {
      FrColors.dark = dark;
      _rebuildEverything();
    }
    final theme = _themes.putIfAbsent(dark, buildFrTheme);
    final router = ref.watch(routerProvider);
    final loading =
        ref.watch(authControllerProvider.select((a) => a.loading));
    // ONE MaterialApp for the whole lifetime. Swapping between a splash
    // MaterialApp and MaterialApp.router tore down the entire tree (theme
    // lerp crashes, disposed screens mid-await). Instead the splash is drawn
    // in place of the router's pages while the cold-start profile loads; the
    // router itself stays mounted and keeps the deep-linked location.
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      // Switch instantly: lerping between the two themes runs the
      // TextStyle.lerp path that has crashed this app before.
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      builder: (context, child) => loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : child!,
    );
  }
}
