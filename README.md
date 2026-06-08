# HRMS_6

Abhishek International Group — Attendance & HRMS app.

- **Flutter** mobile app (Android) for employees
- **Flutter Web** admin panel (Dashboard, Employees, Attendance, Tickets, Notifications)
- **Firebase Firestore** for real-time data sync

## Run locally

```bash
# Employee app (Android)
flutter run -d android

# Admin panel (Web)
flutter run -d chrome

# Optional API server
python3 api_server.py
```

## Deploy admin panel (Firebase Hosting)

```bash
./deploy_web.sh
```

## Admin login

- Username: `admin`
- Password: `Admin@123`
