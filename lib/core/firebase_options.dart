import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'constants.dart';

/// Hand-rolled web FirebaseOptions (equivalent to what `flutterfire configure`
/// generates) so no CLI step is required. Values come from --dart-define.
const FirebaseOptions defaultFirebaseOptions = FirebaseOptions(
  apiKey: kFirebaseApiKey,
  appId: kFirebaseAppId,
  messagingSenderId: kFirebaseMessagingSenderId,
  projectId: kFirebaseProjectId,
  authDomain: kFirebaseAuthDomain,
  storageBucket: kFirebaseStorageBucket,
);
