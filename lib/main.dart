import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'screens/employee/auth/splash_screen.dart';

// ─── Global Firebase init status ──────────────────────────────────────────────
// Readable by SyncService / FirestoreService to guard against premature access.
bool firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Initialize Hive (offline cache) ────────────────────────────────────
  await Hive.initFlutter();
  debugPrint('[App] Hive initialized');

  // ── 2. Initialize Firebase ────────────────────────────────────────────────
  //
  // Rules:
  //  • If Firebase.apps is non-empty the app is already initialized (hot
  //    reload / duplicate call) — skip silently.
  //  • Any other exception means credentials are bad or network is down —
  //    log it clearly and continue in HTTP-fallback mode.
  //  • NEVER put firebase.initializeApp() in web/index.html — that causes
  //    [core/duplicate-app] which lands here and silently disables Firestore.
  //
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      // Register FCM background handler immediately after Firebase init
      FcmService.setupBackgroundHandler();
      debugPrint('[Firebase] ✅ Initialized — project: abhishek-international-hrms'
          ' | platform: ${kIsWeb ? "web" : "android"}');
    } on FirebaseException catch (e) {
      firebaseInitialized = false;
      debugPrint('[Firebase] ❌ FirebaseException during init: ${e.code} — ${e.message}');
      debugPrint('[Firebase]    → Falling back to HTTP api_server.py');
    } catch (e) {
      firebaseInitialized = false;
      debugPrint('[Firebase] ❌ Unexpected error during init: $e');
      debugPrint('[Firebase]    → Falling back to HTTP api_server.py');
    }
  } else {
    // Already initialized (e.g., Flutter hot-restart on web)
    firebaseInitialized = true;
    debugPrint('[Firebase] ✅ Already initialized (${Firebase.apps.length} app(s))');
  }

  // ── 3. Lock to portrait on mobile only ────────────────────────────────────
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // ── 4. Status bar styling ──────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF141414),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── 5. Run app ─────────────────────────────────────────────────────────────
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const AbhishekAttendanceApp(),
    ),
  );
}

class AbhishekAttendanceApp extends StatelessWidget {
  const AbhishekAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abhishek Internationals Attendance Register',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
