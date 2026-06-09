// firebase_options.dart — Aligned to abhishek-international-hrm (project_number: 577255859755)
// Package: com.abhishekattendance.attend
//
// BOTH web (admin portal) and android (employee app) point to the SAME project.
// Cloud Functions, Firestore data, and FCM tokens all live in this one project.

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
        return ios;
      default:
        return web;
    }
  }

  // ── WEB — admin portal (abhishek-international-hrm) ──────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyDdl0m1eZnJvpq-dJJ9GJ0Kvws_8fXyH2M',
    appId:             '1:577255859755:web:f2d2a5b2365f87d8432c6e',
    messagingSenderId: '577255859755',
    projectId:         'abhishek-international-hrm',
    authDomain:        'abhishek-international-hrm.firebaseapp.com',
    storageBucket:     'abhishek-international-hrm.firebasestorage.app',
  );

  // ── ANDROID — employee app (abhishek-international-hrm) ──────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDdl0m1eZnJvpq-dJJ9GJ0Kvws_8fXyH2M',
    appId:             '1:577255859755:android:f9b5a1ca3962ef8e432c6e',
    messagingSenderId: '577255859755',
    projectId:         'abhishek-international-hrm',
    storageBucket:     'abhishek-international-hrm.firebasestorage.app',
  );

  // ── iOS — fill in when building for iPhone ────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyDdl0m1eZnJvpq-dJJ9GJ0Kvws_8fXyH2M',
    appId:             '1:577255859755:ios:placeholder',
    messagingSenderId: '577255859755',
    projectId:         'abhishek-international-hrm',
    storageBucket:     'abhishek-international-hrm.firebasestorage.app',
    iosBundleId:       'com.abhishekattendance.attend',
  );
}
