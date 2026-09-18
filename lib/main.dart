import 'package:firebase_core/firebase_core.dart';
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
    // Debug builds only: surface Flutter errors as short prefixed console
    // lines — full dumps get truncated by some console capture pipelines.
    FlutterError.onError = (details) {
      debugPrint('FR-ERR: ${details.exception.toString().split('\n').first}');
      final info = details.informationCollector?.call().join(' | ');
      if (info != null) debugPrint('FR-WGT: $info');
      final stack = details.stack;
      if (stack != null) {
        for (final line in stack.toString().split('\n').take(30)) {
          debugPrint('FR-STK: $line');
        }
      }
      FlutterError.presentError(details);
    };
    return true;
  }());
  await Firebase.initializeApp(options: defaultFirebaseOptions);
  runApp(const ProviderScope(child: FoodRushApp()));
}

class FoodRushApp extends ConsumerWidget {
  const FoodRushApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Hold the router until the auth profile resolves — mounting it earlier
    // made the router redirect deep links (/admin/users etc.) to /login
    // during the loading window, silently dropping the destination.
    final auth = ref.watch(authControllerProvider);
    if (auth.loading) {
      // Must use the SAME theme as the full app below: MaterialApp keeps an
      // internal AnimatedTheme, so swapping branches would animate every
      // widget from the default theme to ours — and TextStyle.lerp throws
      // 'different inherit values' mid-animation (blank/broken pages).
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildFrTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildFrTheme(),
      routerConfig: router,
    );
  }
}
