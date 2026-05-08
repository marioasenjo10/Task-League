// File generated based on google-services.json + Firebase Console web config.
// To regenerate: flutterfire configure --project=taskfight-c4a80
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'No iOS Firebase config yet — run flutterfire configure to add one.',
        );
      default:
        throw UnsupportedError(
          'Unsupported platform: $defaultTargetPlatform',
        );
    }
  }

  // ── Web ──────────────────────────────────────────────────────────────────
  // Values from: Firebase Console → Project Settings → Your apps → Web app
  // If you have not registered a web app yet:
  //   1. Go to https://console.firebase.google.com/project/taskfight-c4a80/settings/general
  //   2. Click "Add app" → Web
  //   3. Copy apiKey, appId, measurementId here
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCh6gsb3_TCuLJG_s7tyFxkPHCf2XgLBdk',
    appId: '1:553825765711:web:6d049fc67f93ee5cfa5d3a',
    messagingSenderId: '553825765711',
    projectId: 'taskfight-c4a80',
    authDomain: 'taskfight-c4a80.firebaseapp.com',
    databaseURL:
        'https://taskfight-c4a80-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'taskfight-c4a80.firebasestorage.app',
    androidClientId: null,
    iosClientId: null,
    measurementId: null,
  );

  // ── Android ──────────────────────────────────────────────────────────────
  // Values from google-services.json — package: com.masen.taskfight
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbYQRrAIZP_jTYqSwCT1GxuuLCb7Zz92I',
    appId: '1:553825765711:android:752f6ca3142461cffa5d3a',
    messagingSenderId: '553825765711',
    projectId: 'taskfight-c4a80',
    databaseURL:
        'https://taskfight-c4a80-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'taskfight-c4a80.firebasestorage.app',
  );
}
