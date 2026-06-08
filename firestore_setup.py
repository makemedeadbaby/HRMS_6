#!/usr/bin/env python3
"""
Abhishek International HRMS - Firestore Database Setup Script
=============================================================
Run this ONCE after setting Firestore security rules to allow writes.

Prerequisites:
  1. Go to Firebase Console -> Firestore Database -> Rules
  2. Set rules to:
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /{document=**} {
           allow read, write: if true;
         }
       }
     }
  3. Click Publish
  4. Run: python3 firestore_setup.py

This script seeds demo employees so you can test login immediately.
"""

import requests
import json
from datetime import datetime

PROJECT_ID = "abhishek-international-hrms"
API_KEY    = "AIzaSyBLK5gGyHAPn-vqlxNfsl0U31wNOfiUz2Y"
BASE_URL   = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

def to_firestore(value):
    """Convert a Python value to Firestore REST API field format."""
    if isinstance(value, bool):
        return {"booleanValue": value}
    elif isinstance(value, int):
        return {"integerValue": str(value)}
    elif isinstance(value, float):
        return {"doubleValue": value}
    elif value is None:
        return {"nullValue": None}
    elif isinstance(value, list):
        return {"arrayValue": {"values": [to_firestore(v) for v in value]}}
    elif isinstance(value, dict):
        return {"mapValue": {"fields": {k: to_firestore(v) for k, v in value.items()}}}
    else:
        return {"stringValue": str(value)}

def set_doc(collection, doc_id, data):
    url = f"{BASE_URL}/{collection}/{doc_id}?key={API_KEY}"
    fields = {k: to_firestore(v) for k, v in data.items()}
    resp = requests.patch(url, json={"fields": fields})
    if resp.status_code in (200, 201):
        print(f"  ✅ {collection}/{doc_id}")
        return True
    else:
        print(f"  ❌ {collection}/{doc_id}: {resp.status_code} {resp.text[:200]}")
        return False

print("\n🔥 Abhishek International HRMS — Firestore Setup")
print("=" * 52)

# ── Employees ────────────────────────────────────────────────────────────────
print("\n📋 Creating Employees...")
employees = [
    {
        "id": "emp_001", "employee_code": "EMP-1001", "full_name": "Rahul Sharma",
        "email": "rahul@learningsaint.com", "mobile": "9876543210",
        "emergency_contact": "", "company_id": "c_001", "company_name": "Learning Saint",
        "department": "USA Sales", "designation": "Sales Executive",
        "shift_type": "Night Shift", "shift_start_time": "8:30 PM",
        "shift_end_time": "5:30 AM", "reporting_manager": "Abhishek Boss",
        "branch": "Noida", "login_id": "rahul.sharma", "password_hash": "Pass@123",
        "photo_url": "", "status": "Active",
        "joining_date": "2026-01-01T00:00:00.000", "role": "employee",
        "device_bound": False, "bound_device_id": "",
    },
    {
        "id": "emp_002", "employee_code": "EMP-1002", "full_name": "Priya Singh",
        "email": "priya@khushlifestyle.com", "mobile": "9876543211",
        "emergency_contact": "", "company_id": "c_002", "company_name": "Khush Lifestyle",
        "department": "Marketing", "designation": "Marketing Executive",
        "shift_type": "Day Shift", "shift_start_time": "9:30 AM",
        "shift_end_time": "6:30 PM", "reporting_manager": "Abhishek Boss",
        "branch": "Noida", "login_id": "priya.singh", "password_hash": "Pass@123",
        "photo_url": "", "status": "Active",
        "joining_date": "2025-11-15T00:00:00.000", "role": "employee",
        "device_bound": False, "bound_device_id": "",
    },
    {
        "id": "emp_003", "employee_code": "EMP-1003", "full_name": "Amit Kumar",
        "email": "amit@vibgyor.com", "mobile": "9876543212",
        "emergency_contact": "", "company_id": "c_003", "company_name": "Vibgyor",
        "department": "Creative", "designation": "Designer",
        "shift_type": "Day Shift", "shift_start_time": "10:00 AM",
        "shift_end_time": "7:00 PM", "reporting_manager": "Abhishek Boss",
        "branch": "Kanpur", "login_id": "amit.kumar", "password_hash": "Pass@123",
        "photo_url": "", "status": "Active",
        "joining_date": "2025-09-01T00:00:00.000", "role": "employee",
        "device_bound": False, "bound_device_id": "",
    },
    {
        "id": "emp_004", "employee_code": "EMP-1004", "full_name": "Neha Gupta",
        "email": "neha@possessivepanda.com", "mobile": "9876543213",
        "emergency_contact": "", "company_id": "c_004", "company_name": "Possessive Panda",
        "department": "Sales", "designation": "Sales Manager",
        "shift_type": "Day Shift", "shift_start_time": "10:00 AM",
        "shift_end_time": "7:00 PM", "reporting_manager": "Abhishek Boss",
        "branch": "Noida", "login_id": "neha.gupta", "password_hash": "Pass@123",
        "photo_url": "", "status": "Active",
        "joining_date": "2025-06-10T00:00:00.000", "role": "employee",
        "device_bound": False, "bound_device_id": "",
    },
    {
        "id": "emp_005", "employee_code": "EMP-1005", "full_name": "Ravi Verma",
        "email": "ravi@learningsaint.com", "mobile": "9876543214",
        "emergency_contact": "", "company_id": "c_001", "company_name": "Learning Saint",
        "department": "UK Sales", "designation": "Senior Sales Executive",
        "shift_type": "Night Shift", "shift_start_time": "8:30 PM",
        "shift_end_time": "5:30 AM", "reporting_manager": "Abhishek Boss",
        "branch": "Noida", "login_id": "ravi.verma", "password_hash": "Pass@123",
        "photo_url": "", "status": "Active",
        "joining_date": "2024-03-20T00:00:00.000", "role": "employee",
        "device_bound": False, "bound_device_id": "",
    },
]
for emp in employees:
    set_doc("employees", emp["id"], emp)

# ── Collections: Create empty placeholder docs ────────────────────────────────
print("\n📁 Initializing empty collections...")
set_doc("attendance",    "_init", {"_initialized": True, "created_at": datetime.now().isoformat()})
set_doc("notifications", "_init", {"_initialized": True, "created_at": datetime.now().isoformat()})
set_doc("tickets",       "_init", {"_initialized": True, "created_at": datetime.now().isoformat()})
set_doc("audit_logs",    "_init", {"_initialized": True, "created_at": datetime.now().isoformat()})

print("\n✅ Firestore setup complete!")
print("\nYou can now:")
print("  • Login to the app with: rahul.sharma / Pass@123")
print("  • Or create employees from the Admin Panel")
print("  • Admin login: admin / Admin@123")
