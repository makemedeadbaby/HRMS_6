# Abhishek International Group — Attendance App
## Complete Functionality Documentation
### Version: 1.0.0 — FINAL (Firebase Integrated — Android + Web)

> **Last Updated:** Real Firebase credentials embedded for both Android and Web platforms.
> **Status:** Production-ready. Both APK and Web Admin Panel use live Firestore.

---

## TABLE OF CONTENTS

1. [App Overview](#1-app-overview)
2. [Technology Stack](#2-technology-stack)
3. [Login Credentials](#3-login-credentials)
4. [App Architecture](#4-app-architecture)
5. [Data Backend — Dual-Mode System](#5-data-backend--dual-mode-system)
6. [Screen-by-Screen Functionality](#6-screen-by-screen-functionality)
   - [6.1 Splash Screen](#61-splash-screen)
   - [6.2 Admin Login](#62-admin-login)
   - [6.3 Employee Login](#63-employee-login)
   - [6.4 Admin Dashboard](#64-admin-dashboard)
   - [6.5 Admin — Employees](#65-admin--employees)
   - [6.6 Admin — Attendance](#66-admin--attendance)
   - [6.7 Admin — Notifications](#67-admin--notifications)
   - [6.8 Admin — Tickets](#68-admin--tickets)
   - [6.9 Admin — Reports](#69-admin--reports)
   - [6.10 Admin — Settings](#610-admin--settings)
   - [6.11 Employee Dashboard](#611-employee-dashboard)
   - [6.12 Employee — Attendance](#612-employee--attendance)
   - [6.13 Employee — Notifications](#613-employee--notifications)
   - [6.14 Employee — Tickets](#614-employee--tickets)
   - [6.15 Employee — Profile](#615-employee--profile)
7. [Complete Data Flow for Each Feature](#7-complete-data-flow-for-each-feature)
8. [Firebase Configuration](#8-firebase-configuration)
9. [Firestore Database Schema](#9-firestore-database-schema)
10. [API Server (Fallback Mode)](#10-api-server-fallback-mode)
11. [File Structure](#11-file-structure)
12. [Build & Deploy Guide](#12-build--deploy-guide)
13. [First-Time Setup Checklist](#13-first-time-setup-checklist)

---

## 1. App Overview

**App Name:** Abhishek Attendance  
**Full Name:** Abhishek International Group Attendance Register  
**Package ID:** `com.abhishekattendance.attend`  
**Platform:** Android (primary) + Web (preview/admin panel)  
**Firebase Project:** `abhishek-international-hrms`

### What This App Does

The Abhishek Attendance app is a complete HR Attendance Management System for Abhishek International Group. It enables:

| Role | Capabilities |
|------|-------------|
| **Admin / Super Admin** | Manage employees, view/mark attendance, send notifications, respond to tickets, generate reports, configure settings |
| **Employee** | Check in/out, track breaks, view attendance history, receive notifications, raise support tickets |

All data is shared in real-time between the Admin web panel and employee Android app through **Firebase Firestore** as the primary backend, with a Python HTTP server as fallback.

---

## 2. Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Flutter | 3.35.4 |
| Language | Dart | 3.9.2 |
| State Management | Provider | 6.1.5+1 |
| Cloud Database | Firebase Firestore | cloud_firestore 5.4.3 |
| Firebase Core | firebase_core | 3.6.0 |
| Local Cache | Hive + hive_flutter | 2.2.3 + 1.1.0 |
| User Prefs | shared_preferences | 2.5.3 |
| HTTP Client | http | 1.5.0 |
| Charts | fl_chart | 0.69.0 |
| Calendar | table_calendar | 3.1.2 |
| Animation | lottie | 3.3.1 |
| Fonts | google_fonts | 6.2.1 |
| UUID gen | uuid | 4.5.1 |
| Fallback Server | Python 3 (ThreadingTCPServer) | — |

---

## 3. Login Credentials

### Admin Credentials (Built-in, no account needed)

| Role | Username / Access | Password | Capabilities |
|------|-------------------|----------|-------------|
| **Super Admin** | Press "Super Admin" on login screen | `Super@123` | Full access: employees, attendance, notifications, tickets, reports, settings, company config |
| **Admin** | Press "Admin Login" on login screen | `Admin@123` | All features except company configuration |

> These passwords are stored in `SharedPreferences` and can be changed from Settings → Change Password.

### Employee Credentials (Configured by Admin)

| Field | Format |
|-------|--------|
| Employee ID | e.g., `EMP001`, `EMP002` (assigned by admin) |
| Password | Default: same as Employee ID. Changed after first login. |

**Demo employees seeded on first run:**

| Employee ID | Name | Company | Shift |
|-------------|------|---------|-------|
| EMP001 | Rajesh Kumar | Abhishek International | Morning |
| EMP002 | Priya Sharma | Abhishek Exports | Evening |
| EMP003 | Amit Patel | Abhishek Logistics | Night |
| EMP004 | Sunita Singh | Abhishek International | Morning |
| EMP005 | Vikram Mehta | Abhishek Exports | Rotational |

---

## 4. App Architecture

```
┌─────────────────────────────────────────────────────┐
│                      UI Layer                        │
│  Admin Screens          Employee Screens             │
│  ┌─────────────┐        ┌──────────────────┐        │
│  │ Dashboard   │        │ Dashboard        │        │
│  │ Employees   │        │ Attendance       │        │
│  │ Attendance  │        │ Notifications    │        │
│  │ Notifications│       │ Tickets          │        │
│  │ Tickets     │        │ Profile          │        │
│  │ Reports     │        └──────────────────┘        │
│  │ Settings    │                                     │
│  └─────────────┘                                     │
└──────────────────────┬──────────────────────────────┘
                       │ Provider (ChangeNotifier)
                       ▼
┌─────────────────────────────────────────────────────┐
│                   AppProvider                        │
│  Single root ChangeNotifier                          │
│  • State for all features                            │
│  • All business logic methods                        │
│  • initFirestore() at startup                        │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                  SyncService (v3.0)                  │
│  Unified data routing layer                          │
│  _firestoreReady flag determines routing:            │
│                                                      │
│  if (_firestoreReady) → FirestoreService             │
│  else                 → HTTP api_server.py           │
└──────┬───────────────────────────┬───────────────────┘
       │                           │
       ▼                           ▼
┌──────────────┐          ┌────────────────────┐
│  Firestore   │          │   api_server.py     │
│  Service     │          │   (Python fallback) │
│              │          │   Port 5060         │
│  5 collections│         │   10 endpoints      │
│  Batch writes│          │   JSON file storage │
│  Transactions│          └────────────────────┘
└──────────────┘
       │
       ▼
┌──────────────────────────────────┐
│         Hive Local Cache         │
│  (employees, attendance,         │
│   notifications, tickets boxes)  │
│  Offline fallback only           │
└──────────────────────────────────┘
```

### State Management: Single Provider

The entire app uses a **single `AppProvider` ChangeNotifier** registered at the root of the widget tree. This means:
- All screens share one state object
- Admin actions (e.g., marking attendance) are instantly reflected in employee screens
- No complex Provider nesting or data synchronization issues

---

## 5. Data Backend — Dual-Mode System

### Mode 1: Firestore (Primary — when Firebase is configured)

When `SyncService._firestoreReady = true`:
- All reads/writes go to Firebase Firestore
- Data is shared in real-time between Admin web panel and Android APK
- Batch writes used for atomic operations (attendance + audit)
- Transactions used for safe read-modify-write (ticket replies)

### Mode 2: Local API Server (Fallback — when Firestore not reachable)

When `SyncService._firestoreReady = false`:
- All reads/writes go to `api_server.py` (Python ThreadingTCPServer on port 5060)
- Data stored in JSON files under `api_data/`
- Atomic file writes using `os.replace()` (write-to-tmp then rename)

### Mode Detection at Startup

```
App Launch
  │
  ├── Hive.initFlutter()
  ├── Firebase.initializeApp()  ← try-catch: never crashes
  │
  ├── AppProvider._init()
  │   ├── SyncService.initFirestore()
  │   │   ├── FirestoreService.isReachable()  ← test Firestore access
  │   │   ├── if OK: _firestoreReady = true   ← use cloud
  │   │   └── if FAIL: _firestoreReady = false ← use local
  │   │
  │   ├── _loadEmployees()    ─┐
  │   ├── _loadAttendance()    │  All use SyncService
  │   ├── _loadNotifications() │  which routes to correct backend
  │   ├── _loadTickets()       │
  │   └── _loadAuditLogs()   ─┘
```

### Load Priority (3-tier cascade)

For every data type, the load order is:
1. **API/Firestore** — real-time shared source
2. **Hive cache** — offline fallback if API unreachable
3. **Demo seed data** — first-run only (employees only)

---

## 6. Screen-by-Screen Functionality

### 6.1 Splash Screen

**File:** `lib/screens/employee/auth/splash_screen.dart`

**What it does:**
- Displays Abhishek International Group logo and app name with animation
- Initializes app state via `AppProvider`
- Restores previous session (if employee/admin was logged in)
- After 2.5 seconds + app ready: navigates to appropriate home screen
  - If admin session restored → Admin Shell
  - If employee session restored → Employee Shell
  - Otherwise → Login screen

---

### 6.2 Admin Login

**File:** `lib/screens/employee/auth/login_screen.dart`

**What it does:**
- Two buttons: **Admin Login** and **Super Admin Login**
- Tap either → password dialog appears
- Enter `Admin@123` (Admin) or `Super@123` (Super Admin)
- On success → navigates to Admin Shell
- On fail → red error snackbar

**Admin vs. Super Admin differences:**
| Feature | Admin | Super Admin |
|---------|-------|-------------|
| View/manage employees | ✅ | ✅ |
| Attendance management | ✅ | ✅ |
| Send notifications | ✅ | ✅ |
| Reply to tickets | ✅ | ✅ |
| Reports | ✅ | ✅ |
| Company settings | ❌ | ✅ |
| Change admin passwords | ❌ | ✅ |

---

### 6.3 Employee Login

**File:** `lib/screens/employee/auth/login_screen.dart`

**What it does:**
- Employee enters their **Employee ID** (e.g., `EMP001`) and **password**
- System looks up employee in `_employees` list (loaded from Firestore/API)
- Validates password using hash comparison
- On success → session saved to `SharedPreferences`, navigates to Employee Shell
- On fail → error message shown

**Session persistence:**
- Employee ID and admin flag stored in `SharedPreferences`
- On app restart, `_restoreSession()` loads the previous session automatically

---

### 6.4 Admin Dashboard

**File:** `lib/screens/admin/dashboard/admin_dashboard_screen.dart`

**What it shows:**
- **Live Today Stats Card:** Total employees, Present count, Absent count, On Break count
- **Attendance Rate:** Percentage donut chart (fl_chart)
- **Recent Activity:** Last 5 attendance check-ins (employee name, time, status badge)
- **Quick Action Buttons:** Mark Attendance, Add Employee, Send Notification, View Reports
- **Company Selector:** Filter all stats by company (Abhishek International, Abhishek Exports, etc.)
- **Pending Tickets Badge:** Red badge showing unresolved support tickets

**Data source:** All counts computed live from `AppProvider` state in real-time.

---

### 6.5 Admin — Employees

**File:** `lib/screens/admin/employees/employees_screen.dart`

**Tabs:**
1. **All Employees** — searchable, filterable list
2. **Add Employee** — form to create new employee

**Employee List Features:**
- Search by name or employee ID
- Filter by company, shift, status (Active/Inactive)
- Each card shows: photo, name, ID, company, shift, status badge
- Tap employee → Employee Detail Modal with full info + action buttons:
  - **Edit** — opens edit form
  - **Delete** — confirms then removes
  - **Reset Password** — sets password back to Employee ID
  - **View Attendance** — opens attendance history for that employee

**Add / Edit Employee Form Fields:**
| Field | Type | Required |
|-------|------|----------|
| Employee ID | Text (auto-generated or manual) | Yes |
| Full Name | Text | Yes |
| Email | Email | No |
| Phone | Phone | No |
| Company | Dropdown | Yes |
| Department | Text | No |
| Designation / Role | Text | No |
| Shift Type | Dropdown (Morning/Evening/Night/Rotational) | Yes |
| Join Date | Date picker | Yes |
| Address | Text | No |
| Profile Photo | Image picker | No |
| Status | Active/Inactive toggle | Yes |

**Data flow:**
1. Form submitted → `AppProvider.addEmployee()` or `updateEmployee()`
2. Provider calls `SyncService.upsertEmployee(emp.toMap())`
3. SyncService routes to Firestore or api_server
4. `_employees` list updated → `notifyListeners()`
5. UI rebuilds instantly

---

### 6.6 Admin — Attendance

**File:** `lib/screens/admin/attendance/admin_attendance_screen.dart`

**Tabs:**
1. **Live Status** — real-time today's attendance
2. **History** — date-filtered attendance records
3. **Manual Mark** — admin override for any employee

#### Tab 1: Live Status

Shows all employees with their current attendance state for today:
- **Green dot = Present** (checked in)
- **Yellow dot = On Break**
- **Blue dot = Checked Out**
- **Red dot = Absent / Not checked in**

Each row shows: employee name, company, check-in time, break count, current status

**Auto-refresh:** Screen calls `refreshAttendance()` on `initState()` for fresh data. Pull-to-refresh also available.

**Filter options:**
- By company
- By status (Present / Absent / On Break / Checked Out)
- Search by name

#### Tab 2: History

- Date picker calendar to select any date
- Shows attendance records for selected date
- Stats bar: Total, Present, Absent, Half Day, Late, Leave
- Employee rows with full time details: check-in, check-out, total hours, breaks

#### Tab 3: Manual Mark

Admin can override any employee's attendance:

| Field | Options |
|-------|---------|
| Select Employee | Dropdown of all active employees |
| Date | Date picker (default: today) |
| Status | Present / Absent / Half Day / Late / Leave |
| Check-in Time | Time picker |
| Check-out Time | Time picker |
| Reason / Note | Free text |

**What happens on submit:**
1. Creates `AttendanceModel` with admin-override fields
2. Creates `AuditLog` entry (who marked, what was changed, timestamp)
3. `AppProvider.adminMarkAttendance()` calls `SyncService.adminMarkAttendance(attendance, audit)`
4. SyncService does atomic **Firestore batch write** (both attendance + audit in single transaction)
5. UI refreshes, confirmation snackbar shown

---

### 6.7 Admin — Notifications

**File:** `lib/screens/admin/notifications/admin_notifications_screen.dart`

**Tabs:**
1. **Compose** — create and send notifications
2. **Sent** — history of sent notifications

#### Compose Tab

| Field | Options |
|-------|---------|
| Title | Text (required) |
| Message | Multi-line text (required) |
| Priority | Normal / Urgent / Critical |
| Target | All Employees / Specific Employee / Specific Company / Specific Shift |

**Targeting logic:**
- **All** → every employee sees it
- **Employee** → only that employee sees it
- **Company** → all employees of that company
- **Shift** → all employees of that shift type

**Send flow:**
1. Validate form → show error if invalid
2. `AppProvider.sendNotification()` creates `NotificationModel`
3. SyncService saves to Firestore or api_server
4. Snackbar: "Notification sent successfully"
5. Auto-switches to Sent tab

#### Sent Tab

- Scrollable list of all sent notifications
- Each card: title, message preview, priority badge (color-coded), target, timestamp
- Priority colors: Normal = blue, Urgent = orange, Critical = red

---

### 6.8 Admin — Tickets

**File:** `lib/screens/admin/tickets/admin_tickets_screen.dart`

**Tabs:**
1. **Open** — unresolved tickets requiring admin attention
2. **All** — complete ticket history

**Auto-refresh:** Screen calls `refreshTickets()` on `initState()` for latest tickets.

**Ticket List:**
- Each card shows: subject, employee name, category, priority badge, status badge, creation time
- Unread/new tickets highlighted

**Ticket Detail (tap any ticket):**
Opens a bottom sheet with:
- Full ticket description
- Conversation thread (employee messages + admin replies, chronological)
- Reply text field
- Status update dropdown: Open → In Progress → Resolved → Closed
- Submit button calls `AppProvider.adminReplyTicket()`

**Reply flow:**
1. Admin types reply + selects new status
2. `AppProvider.adminReplyTicket()` called
3. SyncService uses **Firestore transaction** (read-modify-write) to safely append reply + update status
4. Ticket status badge updates instantly across admin and employee views
5. Employee sees reply in their Tickets screen

**Ticket statuses:**
| Status | Color | Meaning |
|--------|-------|---------|
| Open | Red | New, unread by admin |
| In Progress | Orange | Admin reviewing |
| Resolved | Green | Answer provided |
| Closed | Grey | Ticket closed |

---

### 6.9 Admin — Reports

**File:** `lib/screens/admin/reports/admin_reports_screen.dart`

**Report Types:**

1. **Attendance Summary**
   - Date range selector (start date → end date)
   - Per-employee attendance percentage
   - Total present / absent / late / leave days
   - Bar chart (fl_chart)

2. **Employee Roster**
   - Filter by company / department
   - Exportable table of all employee details

3. **Late Arrivals Report**
   - Lists employees who checked in after their shift start time
   - Date range filter
   - Frequency count

4. **Leave / Absent Report**
   - Employees with most absences
   - Date breakdown

5. **Audit Log**
   - Admin action history (manual marks, password resets, deletions)
   - Who did what and when
   - Filter by date, action type, admin

---

### 6.10 Admin — Settings

**File:** `lib/screens/admin/settings/admin_settings_screen.dart`

**Settings Sections:**

#### Company Management (Super Admin only)
- View all registered companies
- Add new company (name, code, logo)
- Edit company details
- Activate / Deactivate companies

#### Shift Configuration
- View all shift types
- Modify shift start/end times
- Add custom shifts

#### Change Passwords (Super Admin only)
- Change Admin password (current: `Admin@123`)
- Change Super Admin password (current: `Super@123`)
- Passwords stored hashed in `SharedPreferences`

#### App Information
- App version, build info
- Developer credits
- Firebase connection status indicator

---

### 6.11 Employee Dashboard

**File:** `lib/screens/employee/dashboard/employee_dashboard_screen.dart`

**What it shows:**
- **Greeting header:** "Good Morning, [Employee Name]!" (time-aware)
- **Today's Status Card:**
  - Current status badge (Not Checked In / Present / On Break / Checked Out)
  - Check-in time, break count
  - Total hours worked so far
- **Action Buttons (context-aware):**
  - If not checked in → **Check In** button (green)
  - If checked in → **Start Break** + **Check Out** buttons
  - If on break → **End Break** + **Check Out** buttons
  - If checked out → Status complete message
- **Notification Badge:** Bell icon with unread count
- **Weekly Mini Calendar:** This week's attendance mini-view
- **Recent Notifications:** Last 3 notifications preview

**Quick stats row:**
- This month: Present days, Absent days, Late days, Leave days

---

### 6.12 Employee — Attendance

**File:** `lib/screens/employee/attendance/employee_attendance_screen.dart`

**Tabs:**
1. **Today** — live check-in/break/check-out controls
2. **History** — monthly attendance calendar + log

#### Today Tab

**Check In:**
1. Employee taps **Check In** button
2. System records:
   - Current timestamp as `checkInTime`
   - Status = "Present" (or "Late" if after shift start time)
3. Creates `AttendanceModel` with unique ID (UUID)
4. `AppProvider.checkIn()` → `SyncService.upsertAttendance()`
5. Confirmation: Green snackbar "Check-in recorded at HH:MM"

**Start Break:**
1. Employee taps **Start Break**
2. Creates `BreakEntry` with `startTime = now, endTime = null`
3. Appends to `todayAttendance.breaks` list
4. Status updates to show "On Break" with timer

**End Break:**
1. Employee taps **End Break**
2. Finds latest break entry (where `endTime == null`)
3. Sets `endTime = now`
4. Calculates break duration
5. Status returns to "Present"

**Check Out:**
1. Employee taps **Check Out**
2. Confirmation dialog: "Are you sure you want to check out?"
3. Sets `checkOutTime = now`, status = "Checked Out"
4. Calculates total working hours (excluding breaks)
5. Saves to backend

#### History Tab

- Month-view calendar (table_calendar package)
- Days color-coded:
  - 🟢 Green = Present
  - 🔴 Red = Absent
  - 🟡 Yellow = Late
  - 🔵 Blue = Half Day
  - ⚪ Grey = Weekend / No data
- Tap any day → Day Detail Panel showing exact times
- Monthly summary: Total working days, Present, Absent, Late, Leave, Total hours

---

### 6.13 Employee — Notifications

**File:** `lib/screens/employee/notifications/employee_notifications_screen.dart`

**What it shows:**
- All notifications targeted to this employee (based on `targetType` + employee's company/shift)
- **Unread notifications** shown with blue dot and bold text
- Tap notification → marks as read, expands full message
- Priority badge: Normal (blue) / Urgent (orange) / Critical (red with pulse)
- Pull-to-refresh to load latest notifications

**Notification targeting rules:**
- `targetType = 'all'` → shown to every employee
- `targetType = 'employee'` + `targetValue = employeeId` → shown only to that employee
- `targetType = 'company'` + `targetValue = companyName` → shown to all in that company
- `targetType = 'shift'` + `targetValue = shiftType` → shown to all in that shift

**Unread count:**
- Badge shown on bottom navigation tab
- Updates in real-time when new notifications arrive (Firestore stream if connected)

---

### 6.14 Employee — Tickets

**File:** `lib/screens/employee/tickets/tickets_screen.dart`

**Tabs:**
1. **My Tickets** — list of this employee's submitted tickets
2. **Raise Ticket** — form to submit a new support ticket

#### My Tickets Tab

- Pull-to-refresh (RefreshIndicator)
- Auto-refreshes on screen open (`initState`)
- Each ticket card: subject, category, priority, status badge, last update time
- Tap ticket → full detail view showing:
  - Original description
  - All replies from admin (conversation thread)
  - Current status
  - Creation and last update timestamps

#### Raise Ticket Tab

| Field | Options |
|-------|---------|
| Subject | Text (required) |
| Category | Attendance / Payroll / Leave / Technical / HR / General |
| Priority | Low / Normal / High / Urgent |
| Description | Multi-line text (required) |
| Attachment | Optional file picker |

**Submit flow:**
1. Validate form
2. `AppProvider.raiseTicket()` creates `TicketModel`:
   - `id = UUID()`
   - `employeeId = currentEmployee.id`
   - `status = 'Open'`
   - `messages = []` (thread will be added as admin replies)
3. SyncService saves to Firestore or api_server
4. Snackbar: "Ticket #TK-XXXX submitted"
5. Ticket appears in My Tickets tab
6. Admin sees it in their Open Tickets list

---

### 6.15 Employee — Profile

**File:** `lib/screens/employee/profile/employee_profile_screen.dart`

**What it shows:**
- Profile photo (tap to change)
- Personal details: Name, Employee ID, Email, Phone
- Work details: Company, Department, Designation, Shift, Join Date
- Account section: Change Password, Logout

**Change Password flow:**
1. Enter current password
2. Enter new password (min 6 chars)
3. Confirm new password
4. `AppProvider.updateEmployeePassword()` → hashes + saves to backend
5. Session remains active with new password

**Logout:**
1. Confirmation dialog
2. Clears `SharedPreferences` session
3. Navigates back to Login screen

---

## 7. Complete Data Flow for Each Feature

### Employee Login Flow

```
Employee enters ID + Password
  │
  ▼
AppProvider.loginEmployee(id, password)
  │
  ├── Find employee in _employees list by ID
  ├── Hash input password
  ├── Compare with stored password_hash
  │
  ├── Match → _currentEmployee = employee
  │          → Save to SharedPreferences
  │          → notifyListeners()
  │          → Navigate to Employee Shell
  │
  └── No match → throw Exception("Invalid credentials")
                → UI shows red error snackbar
```

### Attendance Check-In Flow

```
Employee taps Check In
  │
  ▼
AppProvider.checkIn()
  │
  ├── Create AttendanceModel:
  │   id = "ATT_${employeeId}_${date}"
  │   employeeId, employeeName, companyName
  │   date = today
  │   checkInTime = DateTime.now()
  │   status = isLate ? "Late" : "Present"
  │   breaks = []
  │
  ├── _todayAttendance = newRecord
  ├── _attendanceLogs.add(newRecord)
  │
  ├── SyncService.upsertAttendance(att.toMap())
  │   │
  │   ├── if _firestoreReady:
  │   │   FirestoreService.upsertAttendance()
  │   │   → Firestore.collection('attendance').doc(id).set(data, merge: true)
  │   │
  │   └── else:
  │       POST /api/attendance  ←  api_server.py
  │       → JSON file updated atomically
  │
  ├── Hive.box('attendance_box').put('attendance_list', ...)
  │
  └── notifyListeners()
      → Admin Live Status updates
      → Employee Dashboard updates
```

### Admin Notification Flow

```
Admin fills Compose form + taps Send
  │
  ▼
AppProvider.sendNotification(title, message, priority, targetType, targetValue)
  │
  ├── Create NotificationModel:
  │   id = UUID()
  │   title, message, priority
  │   targetType, targetValue
  │   createdBy = "Admin"
  │   createdAt = DateTime.now()
  │   isRead = false
  │
  ├── _notifications.add(notif)
  │
  ├── SyncService.upsertNotification(notif.toMap())
  │   → Saved to Firestore or api_server
  │
  └── notifyListeners()
      → Employee myNotifications getter re-evaluates
      → Notification badge count updates
      → Employee sees notification in their list
```

### Ticket Raise + Reply Flow

```
EMPLOYEE RAISES TICKET:
  Employee submits ticket form
    → AppProvider.raiseTicket()
    → SyncService.upsertTicket()
    → Saved to Firestore/api with status = 'Open'
    → Admin Open Tickets list updates

ADMIN REPLIES:
  Admin opens ticket, types reply, selects status
    → AppProvider.adminReplyTicket(ticketId, reply, status)
    → SyncService.adminReplyTicket()
    │
    ├── if Firestore: runTransaction()
    │   Read ticket doc
    │   Append message to messages array
    │   Update status, adminReply, repliedAt, repliedBy
    │   Write atomically
    │
    └── else: POST /api/tickets/reply

EMPLOYEE SEES REPLY:
  Employee pulls to refresh or re-opens Tickets screen
    → _refresh() calls refreshTickets()
    → SyncService.fetchTickets(employeeId)
    → New data loaded, UI rebuilds
    → Reply visible in ticket thread
```

---

## 8. Firebase Configuration

### Firebase Project Details

| Key | Value |
|-----|-------|
| Project ID | `abhishek-international-hrms` |
| Project Number | `664539478420` |
| Android App ID | `1:664539478420:android:4ae779119e9371fba77781` |
| Android API Key | `AIzaSyBLK5gGyHAPn-vqlxNfsl0U31wNOfiUz2Y` |
| **Web App ID** | **`1:664539478420:web:143d62f21cd2d679a77781`** |
| **Web API Key** | **`AIzaSyB0dRYUzgJ0ENoUsCgzFgFomr1y8kWw2ow`** |
| **Measurement ID** | **`G-G071XD101Y`** |
| Package Name | `com.abhishekattendance.attend` |
| Auth Domain | `abhishek-international-hrms.firebaseapp.com` |
| Storage Bucket | `abhishek-international-hrms.firebasestorage.app` |
| Database URL | `https://abhishek-international-hrms-default-rtdb.firebaseio.com` |

### Required Firebase Setup Steps

**Step 1: Create Firestore Database**
1. Go to: https://console.firebase.google.com/project/abhishek-international-hrms
2. Navigate: Build → Firestore Database
3. Click **Create Database**
4. Choose **Production mode** (then update rules) or **Test mode** (easier for development)
5. Select location: `asia-south1` (Mumbai) recommended for India

**Step 2: Set Security Rules for Development**
In Firebase Console → Firestore Database → Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```
> ⚠️ These are development rules. For production, implement proper authentication rules.

**Step 3: Seed Initial Data (Optional)**
After setting open rules, run the seed script:
```bash
cd /path/to/project
pip install requests
python3 firestore_setup.py
```

This creates:
- 5 demo employees in `employees` collection
- Empty `attendance` collection placeholder
- Empty `notifications` collection placeholder
- Empty `tickets` collection placeholder
- Empty `audit_logs` collection placeholder

**Step 4: Web App — ALREADY REGISTERED** ✅
The Web App is already registered and credentials are embedded in:
- `lib/firebase_options.dart` → `FirebaseOptions.web` block
- `web/index.html` → inline `firebaseConfig` JavaScript object

Web credentials:
```js
const firebaseConfig = {
  apiKey:            "AIzaSyB0dRYUzgJ0ENoUsCgzFgFomr1y8kWw2ow",
  authDomain:        "abhishek-international-hrms.firebaseapp.com",
  databaseURL:       "https://abhishek-international-hrms-default-rtdb.firebaseio.com",
  projectId:         "abhishek-international-hrms",
  storageBucket:     "abhishek-international-hrms.firebasestorage.app",
  messagingSenderId: "664539478420",
  appId:             "1:664539478420:web:143d62f21cd2d679a77781",
  measurementId:     "G-G071XD101Y"
};
```

No action needed for Step 4 — just create the Firestore Database (Step 1) and set rules (Step 2).

---

## 9. Firestore Database Schema

### Collection: `employees`

```
Document ID: EMP001 (employee ID)
Fields:
  id:              String  — Employee ID (EMP001)
  name:            String  — Full name
  email:           String  — Email address
  phone:           String  — Phone number
  company_name:    String  — Company name
  department:      String  — Department
  designation:     String  — Job title
  shift_type:      String  — Morning/Evening/Night/Rotational
  join_date:       String  — ISO date string
  status:          String  — active/inactive
  password_hash:   String  — Hashed password
  profile_image:   String  — Image URL or base64
  created_at:      Timestamp
  updated_at:      Timestamp
```

### Collection: `attendance`

```
Document ID: ATT_EMP001_2024-01-15
Fields:
  id:              String  — Unique attendance ID
  employee_id:     String  — Reference to employee
  employee_name:   String  — Denormalized for display
  company_name:    String  — Denormalized for filtering
  date:            String  — ISO date (yyyy-MM-dd)
  check_in_time:   Timestamp
  check_out_time:  Timestamp | null
  status:          String  — Present/Absent/Late/Half Day/Leave/Checked Out
  is_admin_marked: Boolean — true if admin overrode
  admin_note:      String  — Admin override reason
  breaks:          Array<{start_time, end_time, duration_minutes}>
  total_hours:     Number  — Total working hours
  created_at:      Timestamp
  updated_at:      Timestamp
```

### Collection: `notifications`

```
Document ID: UUID
Fields:
  id:              String
  title:           String
  message:         String
  priority:        String  — Normal/Urgent/Critical
  target_type:     String  — all/employee/company/shift
  target_value:    String  — specific value for non-all targets
  created_by:      String  — "Admin"
  created_at:      Timestamp
  is_read:         Boolean — default false
```

### Collection: `tickets`

```
Document ID: UUID
Fields:
  id:              String
  employee_id:     String
  employee_name:   String
  subject:         String
  description:     String
  category:        String  — Attendance/Payroll/Leave/Technical/HR/General
  priority:        String  — Low/Normal/High/Urgent
  status:          String  — Open/In Progress/Resolved/Closed
  admin_reply:     String  — Latest admin reply
  replied_by:      String  — Admin name
  replied_at:      Timestamp | null
  messages:        Array<{sender, text, timestamp, type}>
  created_at:      Timestamp
  updated_at:      Timestamp
  resolved_at:     Timestamp | null
```

### Collection: `audit_logs`

```
Document ID: AUDIT_EMP001_timestamp
Fields:
  id:              String
  employee_id:     String
  employee_name:   String
  action:          String  — e.g., "Manual Attendance Mark"
  action_by:       String  — Admin who performed action
  old_status:      String  — Previous value
  new_status:      String  — New value
  date:            String
  note:            String
  updated_at:      Timestamp
```

---

## 10. API Server (Fallback Mode)

**File:** `api_server.py`  
**Port:** 5060  
**Protocol:** HTTP/JSON  
**Storage:** JSON files in `api_data/` directory

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Health check → `{"status":"ok","version":"2.0"}` |
| GET/POST | `/api/employees` | List all / Create or update employee |
| POST | `/api/employees/delete` | Delete employee by ID |
| POST | `/api/employees/password` | Update employee password hash |
| GET/POST | `/api/attendance` | List all (with filters) / Upsert record |
| POST | `/api/attendance/admin-mark` | Atomic: mark attendance + write audit |
| GET/POST | `/api/notifications` | List all / Create notification |
| POST | `/api/notifications/bulk` | Bulk save notifications |
| GET/POST | `/api/tickets` | List all (filter by employee_id) / Upsert ticket |
| POST | `/api/tickets/reply` | Append admin reply to ticket |
| POST | `/api/tickets/status` | Update ticket status only |
| GET/POST | `/api/audit` | List audit logs / Append audit entry |

### File Storage

| JSON File | Contents |
|-----------|---------|
| `api_data/employees.json` | Array of all employee objects |
| `api_data/attendance.json` | Array of all attendance records |
| `api_data/notifications.json` | Array of all notifications |
| `api_data/tickets.json` | Array of all support tickets |
| `api_data/audit_logs.json` | Array of all audit log entries |

### Starting the API Server

```bash
cd /home/user/flutter_app
python3 api_server.py
# Server starts on 0.0.0.0:5060
# Health check: curl http://localhost:5060/api/health
```

---

## 11. File Structure

```
flutter_app/
├── android/
│   ├── app/
│   │   ├── google-services.json          ← REAL Firebase credentials
│   │   ├── build.gradle.kts              ← Google Services plugin applied
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/com/abhishekattendances/attend/
│   │           └── MainActivity.kt
│   └── build.gradle.kts                  ← Google Services classpath
├── lib/
│   ├── main.dart                         ← Firebase init + Provider setup
│   ├── firebase_options.dart             ← REAL Firebase credentials (all platforms)
│   ├── models/
│   │   ├── employee_model.dart           ← Employee data model
│   │   ├── attendance_model.dart         ← Attendance + Break models
│   │   ├── ticket_model.dart             ← Ticket + Message models
│   │   ├── notification_model.dart       ← Notification model
│   │   └── company_model.dart            ← Company model
│   ├── providers/
│   │   └── app_provider.dart             ← Single root ChangeNotifier
│   ├── services/
│   │   ├── sync_service.dart             ← v3.0: dual-mode routing
│   │   └── firestore_service.dart        ← Firestore CRUD + streams
│   ├── screens/
│   │   ├── admin/
│   │   │   ├── admin_shell.dart          ← Admin bottom nav
│   │   │   ├── dashboard/
│   │   │   ├── employees/
│   │   │   ├── attendance/
│   │   │   ├── notifications/
│   │   │   ├── tickets/
│   │   │   ├── reports/
│   │   │   ├── settings/
│   │   │   └── companies/
│   │   └── employee/
│   │       ├── employee_shell.dart       ← Employee bottom nav
│   │       ├── auth/                     ← Login + Splash
│   │       ├── dashboard/
│   │       ├── attendance/
│   │       ├── notifications/
│   │       ├── tickets/
│   │       └── profile/
│   ├── theme/
│   │   └── app_theme.dart               ← Dark theme colors + text styles
│   ├── widgets/
│   │   └── common/
│   │       └── app_widgets.dart          ← Reusable: DarkCard, StatusBadge, etc.
│   └── utils/
│       └── ... utility functions
├── assets/
│   ├── images/                           ← App images
│   ├── icons/                            ← App icon + UI icons
│   └── lottie/                           ← Animation files
├── api_data/                             ← JSON files (fallback mode storage)
│   ├── employees.json
│   ├── attendance.json
│   ├── notifications.json
│   ├── tickets.json
│   └── audit_logs.json
├── api_server.py                         ← Python fallback HTTP server v2.0
├── firestore_setup.py                    ← One-time Firestore seed script
├── FIREBASE_SETUP_GUIDE.md              ← Step-by-step Firebase setup
├── APP_FUNCTIONALITY_DOCUMENTATION.md   ← This document
└── pubspec.yaml                          ← Dependencies
```

---

## 12. Build & Deploy Guide

### Prerequisites

- Flutter 3.35.4 (locked version)
- Dart 3.9.2 (locked version)
- Java 17 (OpenJDK)
- Android SDK API 35

### Build Debug APK (for testing)

```bash
cd flutter_app
flutter pub get
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Build Release APK (signed, for distribution)

```bash
cd flutter_app
flutter pub get
flutter analyze                    # Should show: No issues found
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (~59.5MB)
```

> The release APK is signed with the keystore at `android/release-key.jks`.
> Keystore password: stored in `android/key.properties`

### Install APK on Android Device

```bash
# Via ADB:
adb install build/app/outputs/flutter-apk/app-release.apk

# Via file transfer:
# Copy APK to phone, tap to install
# May need to enable "Install from unknown sources" in Settings
```

### Build Web Version (Admin Panel)

```bash
cd flutter_app
flutter build web --release
# Output: build/web/

# Serve locally for testing:
python3 -m http.server 8080 --directory build/web
# Open: http://localhost:8080
```

### Deploy Web to Hosting

```bash
# Firebase Hosting (recommended):
npm install -g firebase-tools
firebase login
firebase init hosting
# Public directory: build/web
# Single page app: Yes
firebase deploy

# URL: https://abhishek-international-hrms.web.app
```

### Start Fallback API Server

```bash
cd flutter_app
python3 api_server.py
# Server: http://0.0.0.0:5060
# Admin panel: connect to this URL in SyncService._apkBase
```

---

## 13. First-Time Setup Checklist

### For Developer / IT Admin

- [ ] **1. Flutter environment** — Install Flutter 3.35.4, Dart 3.9.2, Java 17
- [ ] **2. Get project code** — Extract `AbhishekAttendance_FINAL_Firebase.zip`
- [ ] **3. Install dependencies** — `cd flutter_app && flutter pub get`
- [ ] **4. Verify credentials** — Check `android/app/google-services.json` has project ID `abhishek-international-hrms`
- [ ] **5. Create Firestore DB** — Firebase Console → Build → Firestore Database → Create
- [ ] **6. Set security rules** — Paste development rules (see Section 8)
- [ ] **7. Seed data (optional)** — `python3 firestore_setup.py`
- [ ] **8. Build APK** — `flutter build apk --release`
- [ ] **9. Install on devices** — Copy APK to all employee phones
- [ ] **10. First admin login** — Open app → Admin Login → password: `Admin@123`
- [ ] **11. Add real employees** — Admin → Employees → Add Employee for each staff member
- [ ] **12. Change passwords** — Admin → Settings → Change Password (update from defaults!)

### For End Users (Employees)

- [ ] Install the APK (provided by IT)
- [ ] Open app → Enter Employee ID and password (given by admin)
- [ ] Change password immediately (Profile → Change Password)
- [ ] Grant any permissions the app requests
- [ ] Check in on first working day

### Daily Operation

**Admin Actions:**
- Morning: Check Live Status in Attendance screen
- Use Manual Mark for absent/late corrections
- Send notifications for announcements
- Check and respond to tickets daily

**Employee Actions:**
- Morning: Open app → Check In
- Before lunch/break: Start Break
- After break: End Break
- End of day: Check Out

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| App shows "Connection Error" | api_server.py not running | Run `python3 api_server.py` on server |
| Firestore permission denied | Rules in production mode | Set development rules in Firebase Console |
| Employee can't login | Employee not added yet | Admin → Add Employee first |
| APK install fails | Unknown sources blocked | Settings → Security → Allow unknown sources |
| Data not syncing between admin/employee | Firestore not configured | Complete Steps 1-6 in Section 8 |
| Attendance not saving | Network error | Check internet connection, pull to refresh |
| Notification not visible | Wrong target set | Admin verify targetType/targetValue matches employee |

---

*Document Version: 1.0 — Generated for Final Release with real Firebase credentials*  
*App: Abhishek International Group Attendance Register*  
*Firebase Project: abhishek-international-hrms*
