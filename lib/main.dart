import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/firebase_options.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_controller.dart';

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
  await Firebase.initializeApp(options: defaultFirebaseOptions);
  runApp(const ProviderScope(child: FoodRushApp()));
}

/// Built once: a fresh ThemeData per build makes MaterialApp's AnimatedTheme
/// see a "new" theme and lerp between identical values.
final ThemeData _theme = buildFrTheme();

class FoodRushApp extends ConsumerWidget {
  const FoodRushApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      theme: _theme,
      routerConfig: router,
      builder: (context, child) => loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : child!,
    );
  }
}
