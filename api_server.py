#!/usr/bin/env python3
"""
Abhishek International Group — Attendance App
Shared REST API Server v2.0

All data flows through this server:
  - Employees (CRUD)
  - Attendance (check-in/out/break + admin manual marking)
  - Notifications (admin sends, employees fetch)
  - Tickets (employee raises, admin replies/updates)
  - Audit logs (every attendance change recorded)

Both the Flutter Web admin panel and the Android APK talk to this same server.
Port: 5060
Storage: api_data/*.json (thread-safe, flushed after every write)
"""

import http.server
import socketserver
import json
import os
import threading
import urllib.parse
from datetime import datetime

# ── Storage ────────────────────────────────────────────────────────────────────
DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'api_data')
os.makedirs(DATA_DIR, exist_ok=True)

EMPLOYEES_FILE     = os.path.join(DATA_DIR, 'employees.json')
ATTENDANCE_FILE    = os.path.join(DATA_DIR, 'attendance.json')
NOTIFICATIONS_FILE = os.path.join(DATA_DIR, 'notifications.json')
TICKETS_FILE       = os.path.join(DATA_DIR, 'tickets.json')
AUDIT_FILE         = os.path.join(DATA_DIR, 'audit_logs.json')

_lock = threading.Lock()

def _read(path, default=None):
    if default is None:
        default = []
    try:
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                return json.load(f)
    except Exception as e:
        print(f'[API] Read error {path}: {e}')
    return default

def _write(path, data):
    try:
        tmp = path + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        os.replace(tmp, path)   # atomic rename
    except Exception as e:
        print(f'[API] Write error {path}: {e}')

# ── Seed demo data on first run ────────────────────────────────────────────────
def _seed():
    if not os.path.exists(EMPLOYEES_FILE):
        demo_employees = [
            {
                "id": "emp_001",
                "employee_code": "EMP-1001",
                "full_name": "Rahul Sharma",
                "email": "rahul@learningsaint.com",
                "mobile": "9876543210",
                "emergency_contact": "",
                "company_id": "c_001",
                "company_name": "Learning Saint",
                "department": "USA Sales",
                "designation": "Sales Executive",
                "shift_type": "Night Shift",
                "shift_start_time": "8:30 PM",
                "shift_end_time": "5:30 AM",
                "reporting_manager": "Abhishek Boss",
                "branch": "Noida",
                "login_id": "rahul.sharma",
                "password_hash": "Pass@123",
                "photo_url": "",
                "status": "Active",
                "joining_date": "2026-01-01T00:00:00.000",
                "role": "employee",
                "device_bound": False,
                "bound_device_id": ""
            },
            {
                "id": "emp_002",
                "employee_code": "EMP-1002",
                "full_name": "Priya Singh",
                "email": "priya@khushlifestyle.com",
                "mobile": "9876543211",
                "emergency_contact": "",
                "company_id": "c_002",
                "company_name": "Khush Lifestyle",
                "department": "Marketing",
                "designation": "Marketing Executive",
                "shift_type": "Day Shift",
                "shift_start_time": "9:30 AM",
                "shift_end_time": "6:30 PM",
                "reporting_manager": "Abhishek Boss",
                "branch": "Noida",
                "login_id": "priya.singh",
                "password_hash": "Pass@123",
                "photo_url": "",
                "status": "Active",
                "joining_date": "2025-11-15T00:00:00.000",
                "role": "employee",
                "device_bound": False,
                "bound_device_id": ""
            },
            {
                "id": "emp_003",
                "employee_code": "EMP-1003",
                "full_name": "Amit Kumar",
                "email": "amit@vibgyor.com",
                "mobile": "9876543212",
                "emergency_contact": "",
                "company_id": "c_003",
                "company_name": "Vibgyor",
                "department": "Creative",
                "designation": "Designer",
                "shift_type": "Day Shift",
                "shift_start_time": "10:00 AM",
                "shift_end_time": "7:00 PM",
                "reporting_manager": "Abhishek Boss",
                "branch": "Kanpur",
                "login_id": "amit.kumar",
                "password_hash": "Pass@123",
                "photo_url": "",
                "status": "Active",
                "joining_date": "2025-09-01T00:00:00.000",
                "role": "employee",
                "device_bound": False,
                "bound_device_id": ""
            },
            {
                "id": "emp_004",
                "employee_code": "EMP-1004",
                "full_name": "Neha Gupta",
                "email": "neha@possessivepanda.com",
                "mobile": "9876543213",
                "emergency_contact": "",
                "company_id": "c_004",
                "company_name": "Possessive Panda",
                "department": "Sales",
                "designation": "Sales Manager",
                "shift_type": "Day Shift",
                "shift_start_time": "10:00 AM",
                "shift_end_time": "7:00 PM",
                "reporting_manager": "Abhishek Boss",
                "branch": "Noida",
                "login_id": "neha.gupta",
                "password_hash": "Pass@123",
                "photo_url": "",
                "status": "Active",
                "joining_date": "2025-06-10T00:00:00.000",
                "role": "employee",
                "device_bound": False,
                "bound_device_id": ""
            },
            {
                "id": "emp_005",
                "employee_code": "EMP-1005",
                "full_name": "Ravi Verma",
                "email": "ravi@learningsaint.com",
                "mobile": "9876543214",
                "emergency_contact": "",
                "company_id": "c_001",
                "company_name": "Learning Saint",
                "department": "UK Sales",
                "designation": "Senior Sales Executive",
                "shift_type": "Night Shift",
                "shift_start_time": "8:30 PM",
                "shift_end_time": "5:30 AM",
                "reporting_manager": "Abhishek Boss",
                "branch": "Noida",
                "login_id": "ravi.verma",
                "password_hash": "Pass@123",
                "photo_url": "",
                "status": "Active",
                "joining_date": "2024-03-20T00:00:00.000",
                "role": "employee",
                "device_bound": False,
                "bound_device_id": ""
            },
        ]
        _write(EMPLOYEES_FILE, demo_employees)
        print(f'[API] Seeded {len(demo_employees)} demo employees')

    for path in [ATTENDANCE_FILE, NOTIFICATIONS_FILE, TICKETS_FILE, AUDIT_FILE]:
        if not os.path.exists(path):
            _write(path, [])

_seed()

# ── Web dir ────────────────────────────────────────────────────────────────────
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

# ── Request Handler ─────────────────────────────────────────────────────────────
class Handler(http.server.SimpleHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def log_message(self, fmt, *args):
        # Only log API calls, not static file serving
        if '/api/' in (args[0] if args else ''):
            print(f'[API] {args[0]} → {args[1]}')

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-Key')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    # ── GET ────────────────────────────────────────────────────────────────────
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        # ── Health ──────────────────────────────────────────────────────────────
        if path == '/api/health':
            self._json({'status': 'ok', 'time': datetime.now().isoformat(), 'version': '2.0'})

        # ── Employees ───────────────────────────────────────────────────────────
        elif path == '/api/employees':
            employees = _read(EMPLOYEES_FILE)
            # Optional filter by company_id
            cid = params.get('company_id', [None])[0]
            if cid:
                employees = [e for e in employees if e.get('company_id') == cid]
            self._json(employees)

        elif path.startswith('/api/employees/'):
            emp_id = path.split('/')[-1]
            employees = _read(EMPLOYEES_FILE)
            emp = next((e for e in employees if e.get('id') == emp_id), None)
            if emp:
                self._json(emp)
            else:
                self._error(404, f'Employee {emp_id} not found')

        # ── Attendance ──────────────────────────────────────────────────────────
        elif path == '/api/attendance':
            attendance = _read(ATTENDANCE_FILE)
            # Optional filters
            emp_id = params.get('employee_id', [None])[0]
            date   = params.get('date', [None])[0]
            company_id = params.get('company_id', [None])[0]
            if emp_id:
                attendance = [a for a in attendance if a.get('employee_id') == emp_id]
            if date:
                attendance = [a for a in attendance if a.get('date', '').startswith(date)]
            if company_id:
                attendance = [a for a in attendance if a.get('company_id') == company_id]
            self._json(attendance)

        # ── Notifications ────────────────────────────────────────────────────────
        elif path == '/api/notifications':
            notifications = _read(NOTIFICATIONS_FILE)
            # Optional filter by target (server-side basic filter)
            emp_id = params.get('employee_id', [None])[0]
            self._json(notifications)  # client-side filtering for target matching

        # ── Tickets ──────────────────────────────────────────────────────────────
        elif path == '/api/tickets':
            tickets = _read(TICKETS_FILE)
            # Optional filters
            emp_id = params.get('employee_id', [None])[0]
            status = params.get('status', [None])[0]
            if emp_id:
                tickets = [t for t in tickets if t.get('employee_id') == emp_id]
            if status:
                tickets = [t for t in tickets if t.get('status') == status]
            # Sort newest first
            tickets.sort(key=lambda t: t.get('created_at', ''), reverse=True)
            self._json(tickets)

        elif path.startswith('/api/tickets/'):
            ticket_id = path.split('/')[-1]
            tickets = _read(TICKETS_FILE)
            ticket = next((t for t in tickets if t.get('id') == ticket_id), None)
            if ticket:
                self._json(ticket)
            else:
                self._error(404, f'Ticket {ticket_id} not found')

        # ── Audit Logs ────────────────────────────────────────────────────────────
        elif path == '/api/audit':
            audit = _read(AUDIT_FILE)
            emp_id = params.get('employee_id', [None])[0]
            if emp_id:
                audit = [a for a in audit if a.get('employee_id') == emp_id]
            audit.sort(key=lambda a: a.get('updated_at', ''), reverse=True)
            self._json(audit)

        # ── Static file fallback (Flutter web) ──────────────────────────────────
        else:
            super().do_GET()

    # ── POST ───────────────────────────────────────────────────────────────────
    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        body = self._body()

        with _lock:
            # ── Employee CRUD ──────────────────────────────────────────────────
            if path == '/api/employees':
                employees = _read(EMPLOYEES_FILE)
                emp = body
                emp_id = emp.get('id', '')
                idx = next((i for i, e in enumerate(employees) if e.get('id') == emp_id), None)
                if idx is not None:
                    employees[idx] = emp
                    action = 'updated'
                else:
                    employees.append(emp)
                    action = 'created'
                _write(EMPLOYEES_FILE, employees)
                self._json({'ok': True, 'action': action, 'id': emp_id, 'total': len(employees)})

            elif path == '/api/employees/delete':
                employees = _read(EMPLOYEES_FILE)
                emp_id = body.get('id', '')
                before = len(employees)
                employees = [e for e in employees if e.get('id') != emp_id]
                _write(EMPLOYEES_FILE, employees)
                self._json({'ok': True, 'deleted': before - len(employees)})

            elif path == '/api/employees/password':
                employees = _read(EMPLOYEES_FILE)
                emp_id  = body.get('id', '')
                new_pass = body.get('password_hash', '')
                updated = False
                for e in employees:
                    if e.get('id') == emp_id:
                        e['password_hash'] = new_pass
                        updated = True
                        break
                _write(EMPLOYEES_FILE, employees)
                self._json({'ok': updated})

            elif path == '/api/employees/bulk':
                data = body if isinstance(body, list) else []
                _write(EMPLOYEES_FILE, data)
                self._json({'ok': True, 'count': len(data)})

            # ── Attendance ────────────────────────────────────────────────────
            elif path == '/api/attendance':
                attendance = _read(ATTENDANCE_FILE)
                att = body
                att_id = att.get('id', '')
                idx = next((i for i, a in enumerate(attendance) if a.get('id') == att_id), None)
                if idx is not None:
                    attendance[idx] = att
                    action = 'updated'
                else:
                    attendance.append(att)
                    action = 'created'
                _write(ATTENDANCE_FILE, attendance)
                self._json({'ok': True, 'action': action})

            elif path == '/api/attendance/bulk':
                data = body if isinstance(body, list) else []
                _write(ATTENDANCE_FILE, data)
                self._json({'ok': True, 'count': len(data)})

            elif path == '/api/attendance/admin-mark':
                # Admin manually marks attendance + creates audit log
                attendance = _read(ATTENDANCE_FILE)
                audit      = _read(AUDIT_FILE)
                att = body.get('attendance', {})
                audit_entry = body.get('audit', {})
                att_id = att.get('id', '')
                idx = next((i for i, a in enumerate(attendance) if a.get('id') == att_id), None)
                if idx is not None:
                    attendance[idx] = att
                else:
                    attendance.append(att)
                if audit_entry:
                    audit.append(audit_entry)
                _write(ATTENDANCE_FILE, attendance)
                _write(AUDIT_FILE, audit)
                self._json({'ok': True})

            # ── Notifications ─────────────────────────────────────────────────
            elif path == '/api/notifications':
                notifications = _read(NOTIFICATIONS_FILE)
                notif = body
                notif_id = notif.get('id', '')
                idx = next((i for i, n in enumerate(notifications) if n.get('id') == notif_id), None)
                if idx is not None:
                    # Preserve server-side read tracking if needed
                    notifications[idx] = notif
                    action = 'updated'
                else:
                    notifications.append(notif)
                    action = 'created'
                _write(NOTIFICATIONS_FILE, notifications)
                self._json({'ok': True, 'action': action})

            elif path == '/api/notifications/bulk':
                data = body if isinstance(body, list) else []
                _write(NOTIFICATIONS_FILE, data)
                self._json({'ok': True, 'count': len(data)})

            # ── Tickets ────────────────────────────────────────────────────────
            elif path == '/api/tickets':
                tickets = _read(TICKETS_FILE)
                ticket = body
                ticket_id = ticket.get('id', '')
                idx = next((i for i, t in enumerate(tickets) if t.get('id') == ticket_id), None)
                if idx is not None:
                    tickets[idx] = ticket
                    action = 'updated'
                else:
                    tickets.append(ticket)
                    action = 'created'
                _write(TICKETS_FILE, tickets)
                self._json({'ok': True, 'action': action, 'id': ticket_id})

            elif path == '/api/tickets/reply':
                # Admin replies to a ticket
                tickets = _read(TICKETS_FILE)
                ticket_id   = body.get('ticket_id', '')
                reply       = body.get('reply', '')
                replied_by  = body.get('replied_by', 'Admin')
                new_status  = body.get('status', 'In Progress')
                message_obj = body.get('message', {})
                updated = False
                for t in tickets:
                    if t.get('id') == ticket_id:
                        t['admin_reply'] = reply
                        t['replied_by']  = replied_by
                        t['status']      = new_status
                        msgs = t.get('messages', [])
                        if message_obj:
                            msgs.append(message_obj)
                        t['messages'] = msgs
                        updated = True
                        break
                _write(TICKETS_FILE, tickets)
                self._json({'ok': updated})

            elif path == '/api/tickets/status':
                # Admin updates ticket status only
                tickets = _read(TICKETS_FILE)
                ticket_id  = body.get('ticket_id', '')
                new_status = body.get('status', '')
                resolved_at = body.get('resolved_at')
                updated = False
                for t in tickets:
                    if t.get('id') == ticket_id:
                        t['status'] = new_status
                        if resolved_at:
                            t['resolved_at'] = resolved_at
                        updated = True
                        break
                _write(TICKETS_FILE, tickets)
                self._json({'ok': updated})

            elif path == '/api/tickets/bulk':
                data = body if isinstance(body, list) else []
                _write(TICKETS_FILE, data)
                self._json({'ok': True, 'count': len(data)})

            # ── Audit Logs ─────────────────────────────────────────────────────
            elif path == '/api/audit':
                audit = _read(AUDIT_FILE)
                entry = body
                audit.append(entry)
                _write(AUDIT_FILE, audit)
                self._json({'ok': True})

            elif path == '/api/audit/bulk':
                data = body if isinstance(body, list) else []
                _write(AUDIT_FILE, data)
                self._json({'ok': True})

            # ── 404 ────────────────────────────────────────────────────────────
            else:
                self._error(404, f'Unknown API endpoint: {path}')

    # ── Helpers ────────────────────────────────────────────────────────────────
    def _body(self):
        length = int(self.headers.get('Content-Length', 0))
        raw = self.rfile.read(length) if length else b'{}'
        try:
            return json.loads(raw.decode('utf-8'))
        except Exception:
            return {}

    def _json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _error(self, code, msg):
        self._json({'error': msg}, code)


# ── Server startup ─────────────────────────────────────────────────────────────
if __name__ == '__main__':
    PORT = 5060
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(('0.0.0.0', PORT), Handler) as httpd:
        print(f'')
        print(f'╔══════════════════════════════════════════════════════╗')
        print(f'║   Abhishek Attendance API Server v2.0                ║')
        print(f'║   Port: {PORT}   Data: api_data/                       ║')
        print(f'║   Endpoints:                                         ║')
        print(f'║     GET/POST  /api/employees                         ║')
        print(f'║     GET/POST  /api/attendance                        ║')
        print(f'║     POST      /api/attendance/admin-mark             ║')
        print(f'║     GET/POST  /api/notifications                     ║')
        print(f'║     GET/POST  /api/tickets                           ║')
        print(f'║     POST      /api/tickets/reply                     ║')
        print(f'║     POST      /api/tickets/status                    ║')
        print(f'║     GET/POST  /api/audit                             ║')
        print(f'╚══════════════════════════════════════════════════════╝')
        print(f'')
        httpd.serve_forever()
