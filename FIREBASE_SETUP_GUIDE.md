# 🔥 Firebase & Firestore Setup Guide
## Abhishek International Group — Attendance App

This guide explains exactly how to connect the app to your own Firebase/Firestore database.
Once done, all data (employees, attendance, tickets, notifications, audit logs) will be stored
in Firestore and shared in real-time between the Web Admin Panel and Android APK.

---

## ✅ Prerequisites

- A Google account (personal or company)
- Access to [console.firebase.google.com](https://console.firebase.google.com/)
- The project code (this ZIP)

---

## STEP 1 — Create a Firebase Project

1. Go to **https://console.firebase.google.com/**
2. Click **"Add Project"** (or "Create a project")
3. Enter project name: **Abhishek Attendance** (or any name you prefer)
4. Disable Google Analytics (optional — not needed for this app)
5. Click **"Create project"** → wait 30 seconds → click **"Continue"**

---

## STEP 2 — Create Firestore Database

> ⚠️ This step is MANDATORY. Without it, Firebase writes will fail silently.

1. In the left sidebar: **Build → Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in production mode"** (we will update rules in Step 6)
4. Select your region (e.g., **asia-south1** for India, **us-central** for US)
5. Click **"Enable"** — wait ~1 minute for provisioning

---

## STEP 3 — Register Android App

1. On the Firebase Console home page, click the **Android icon** (</> is for Web)
2. Fill in:
   - **Android package name**: `com.abhishekattendance.attend`
   - **App nickname**: `Abhishek Attendance Android`
   - **Debug signing certificate SHA-1**: (optional — skip for now)
3. Click **"Register app"**
4. Click **"Download google-services.json"**
5. **Replace** the file at:
   ```
   android/app/google-services.json
   ```
   with the downloaded file.

---

## STEP 4 — Register Web App

1. On the Firebase Console home page, click the **Web icon** (`</>`)
2. Fill in:
   - **App nickname**: `Abhishek Attendance Web`
   - Check **"Also set up Firebase Hosting"**: NO (leave unchecked)
3. Click **"Register app"**
4. You will see a `firebaseConfig` object like this:
   ```javascript
   const firebaseConfig = {
     apiKey:            "AIzaSyABC...",
     authDomain:        "your-project.firebaseapp.com",
     projectId:         "your-project",
     storageBucket:     "your-project.appspot.com",
     messagingSenderId: "123456789",
     appId:             "1:123456789:web:abc123"
   };
   ```
5. Copy these values into `lib/firebase_options.dart`:

```dart
// lib/firebase_options.dart

static const FirebaseOptions web = FirebaseOptions(
  apiKey:            'AIzaSyABC...',          // ← from firebaseConfig.apiKey
  appId:             '1:123456789:web:abc123', // ← from firebaseConfig.appId
  messagingSenderId: '123456789',              // ← from firebaseConfig.messagingSenderId
  projectId:         'your-project',           // ← from firebaseConfig.projectId
  authDomain:        'your-project.firebaseapp.com',
  storageBucket:     'your-project.appspot.com',
);

static const FirebaseOptions android = FirebaseOptions(
  // Get these from google-services.json you downloaded in Step 3:
  apiKey:            'YOUR_ANDROID_API_KEY',   // client[0].api_key[0].current_key
  appId:             'YOUR_ANDROID_APP_ID',    // client[0].client_info.mobilesdk_app_id
  messagingSenderId: '123456789',              // project_info.project_number
  projectId:         'your-project',           // project_info.project_id
  storageBucket:     'your-project.appspot.com',
);
```

---

## STEP 5 — Update Server URL in sync_service.dart

Open `lib/services/sync_service.dart` and update line ~19:

```dart
static const String _apkBase =
    'https://YOUR_ACTUAL_SERVER_URL_HERE';
```

Replace with whatever URL your `api_server.py` is running on
(used as fallback if Firestore is unreachable). If you're hosting on a VPS
or cloud server, put that URL here.

---

## STEP 6 — Set Firestore Security Rules

1. In Firebase Console: **Firestore Database → Rules**
2. Replace the rules with the following (allows read/write for your app):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Employees — readable by all authenticated users, writable by admin only
    match /employees/{docId} {
      allow read: if true;
      allow write: if true;  // tighten in production
    }

    // Attendance — readable and writable by all
    match /attendance/{docId} {
      allow read, write: if true;
    }

    // Notifications — readable by all, writable by all
    match /notifications/{docId} {
      allow read, write: if true;
    }

    // Tickets — readable and writable by all
    match /tickets/{docId} {
      allow read, write: if true;
    }

    // Audit logs — readable and writable by all
    match /audit_logs/{docId} {
      allow read, write: if true;
    }
  }
}
```

3. Click **"Publish"**

> 🔒 **For production**, you should add proper authentication-based rules.
> The rules above are permissive for initial development/testing.

---

## STEP 7 — Rebuild the App

After completing Steps 3–6, rebuild:

```bash
# Install new Firebase packages
flutter pub get

# Build Android APK
flutter build apk --release

# Build Web Admin Panel
flutter build web --release
```

---

## STEP 8 — Verify Connection

1. Run the app (APK or Web)
2. Check the debug console. You should see:
   ```
   [SyncService] ✅ Firestore connected — using cloud storage
   ```
3. If you see:
   ```
   [SyncService] ⚠️  Firestore not reachable — using local api_server fallback
   ```
   → Double-check Steps 3, 4, and 6.

---

## 📊 Firestore Collections Structure

| Collection     | Documents                    | Key Fields                                              |
|----------------|------------------------------|---------------------------------------------------------|
| `employees`    | One doc per employee (by id) | full_name, login_id, password_hash, company_id, status  |
| `attendance`   | One doc per daily record     | employee_id, date, status, check_in_time, breaks[]      |
| `notifications`| One doc per notification     | title, message, target_type, target_value, is_read      |
| `tickets`      | One doc per ticket           | employee_id, subject, status, admin_reply, messages[]   |
| `audit_logs`   | One doc per change event     | employee_id, previous_status, new_status, updated_by    |

---

## 🆘 Troubleshooting

| Problem | Solution |
|---|---|
| "No Firebase App '[DEFAULT]' has been created" | Firebase.initializeApp() failed — check firebase_options.dart values |
| "Missing or insufficient permissions" | Firestore Security Rules not updated — redo Step 6 |
| "Could not reach Cloud Firestore backend" | Firestore database not created yet — redo Step 2 |
| App works but data not saving | google-services.json still has placeholder values — redo Step 3 |
| Build error "google-services.json not found" | File must be at `android/app/google-services.json` |

---

## 📞 Support

If you need help setting this up, contact your Flutter developer and share:
1. This guide
2. The project ZIP file
3. Access to your Firebase Console project

The developer only needs to complete Steps 1–7 above (approximately 30 minutes of work).
