// lib/firebase_options.dart
//
// PLACEHOLDER — regenerate me:
//   dart run flutterfire configure
// The command creates this file with the real values of your Firebase project
// (API key, project id, sender id) for every platform you picked.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'run `dart run flutterfire configure` and add the platform you need',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    appId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    projectId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    appId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    projectId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    iosBundleId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    appId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    projectId: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
  );
}
