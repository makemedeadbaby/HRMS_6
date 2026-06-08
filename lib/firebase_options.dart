// firebase_options.dart — FINAL with REAL credentials (Android + Web)
// Project:       abhishek-international-hrms
// Project Number:664539478420
// Android App ID:1:664539478420:android:4ae779119e9371fba77781
// Web App ID:    1:664539478420:web:143d62f21cd2d679a77781
// Package:       com.abhishekattendance.attend
// DO NOT commit this file to public repositories.

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

  // ── WEB (REAL CREDENTIALS) ────────────────────────────────────────────────
  // Registered Web App: Project Settings → Your apps → Web app
  // App ID: 1:664539478420:web:143d62f21cd2d679a77781
  // Measurement ID: G-G071XD101Y
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyB0dRYUzgJ0ENoUsCgzFgFomr1y8kWw2ow',
    appId:             '1:664539478420:web:143d62f21cd2d679a77781',
    messagingSenderId: '664539478420',
    projectId:         'abhishek-international-hrms',
    authDomain:        'abhishek-international-hrms.firebaseapp.com',
    storageBucket:     'abhishek-international-hrms.firebasestorage.app',
    databaseURL:       'https://abhishek-international-hrms-default-rtdb.firebaseio.com',
    measurementId:     'G-G071XD101Y',
  );

  // ── ANDROID (REAL CREDENTIALS) ───────────────────────────────────────────
  // Registered Android App: com.abhishekattendance.attend
  // App ID: 1:664539478420:android:4ae779119e9371fba77781
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBLK5gGyHAPn-vqlxNfsl0U31wNOfiUz2Y',
    appId:             '1:664539478420:android:4ae779119e9371fba77781',
    messagingSenderId: '664539478420',
    projectId:         'abhishek-international-hrms',
    storageBucket:     'abhishek-international-hrms.firebasestorage.app',
    databaseURL:       'https://abhishek-international-hrms-default-rtdb.firebaseio.com',
  );

  // ── iOS (placeholder — fill if building for iPhone) ──────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyB0dRYUzgJ0ENoUsCgzFgFomr1y8kWw2ow',
    appId:             '1:664539478420:ios:0000000000000000',
    messagingSenderId: '664539478420',
    projectId:         'abhishek-international-hrms',
    storageBucket:     'abhishek-international-hrms.firebasestorage.app',
    iosBundleId:       'com.abhishekattendance.attend',
  );
}
