// firebase_options.dart — Auto-generated from google-services.json
// Project: abhishek-international-hrms
// Package: com.abhishekattendance.attend

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

  // ── WEB — fill in from Firebase Console > Project Settings > Web app ───────
  // To add web support: Firebase Console → Add app → Web → copy firebaseConfig
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyBLK5gGyHAPn-vqlxNfsl0U31wNOfiUz2Y',
    appId:             '1:664539478420:web:abhishek_hrms_web',
    messagingSenderId: '664539478420',
    projectId:         'abhishek-international-hrms',
    authDomain:        'abhishek-international-hrms.firebaseapp.com',
    storageBucket:     'abhishek-international-hrms.firebasestorage.app',
    databaseURL:       'https://abhishek-international-hrms-default-rtdb.firebaseio.com',
  );

  // ── ANDROID — from google-services.json ───────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBLK5gGyHAPn-vqlxNfsl0U31wNOfiUz2Y',
    appId:             '1:664539478420:android:4ae779119e9371fba77781',
    messagingSenderId: '664539478420',
    projectId:         'abhishek-international-hrms',
    storageBucket:     'abhishek-international-hrms.firebasestorage.app',
    databaseURL:       'https://abhishek-international-hrms-default-rtdb.firebaseio.com',
  );

  // ── iOS — fill in when building for iPhone ────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBLK5gGyHAPn-vqlxNfsl0U31wNOfiUz2Y',
    appId:             '1:664539478420:ios:placeholder',
    messagingSenderId: '664539478420',
    projectId:         'abhishek-international-hrms',
    storageBucket:     'abhishek-international-hrms.firebasestorage.app',
    iosBundleId:       'com.abhishekattendance.attend',
  );
}
