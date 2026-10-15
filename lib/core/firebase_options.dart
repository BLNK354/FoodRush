import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'constants.dart';

/// Hand-rolled web FirebaseOptions (equivalent to what `flutterfire configure`
/// generates) so no CLI step is required. Values come from constants.dart,
/// overridable with --dart-define.
const FirebaseOptions _liveOptions = FirebaseOptions(
  apiKey: kFirebaseApiKey,
  appId: kFirebaseAppId,
  messagingSenderId: kFirebaseMessagingSenderId,
  projectId: kFirebaseProjectId,
  authDomain: kFirebaseAuthDomain,
  storageBucket: kFirebaseStorageBucket,
);

/// Emulator mode uses a FAKE project and API key on purpose: if anything
/// ever slips past the emulator connection (it once did, via a saved login
/// refreshing against the live servers before the emulator was wired up),
/// Google rejects the fake key instead of writing to the real project.
const FirebaseOptions _emulatorOptions = FirebaseOptions(
  apiKey: 'demo-not-a-real-key',
  appId: '1:000000000000:web:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-foodrush',
  authDomain: 'demo-foodrush.firebaseapp.com',
  storageBucket: 'demo-foodrush.appspot.com',
);

FirebaseOptions get defaultFirebaseOptions =>
    kUseEmulators ? _emulatorOptions : _liveOptions;
