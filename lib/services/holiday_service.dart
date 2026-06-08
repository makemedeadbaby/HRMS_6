import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/holiday_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HolidayService — Firestore CRUD for the `holidays` collection.
//
// Collection: `holidays`
// Document ID = HolidayModel.id
// ─────────────────────────────────────────────────────────────────────────────

class HolidayService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'holidays';

  // ── Fetch all holidays ─────────────────────────────────────────────────────
  static Future<List<HolidayModel>> fetchAll() async {
    try {
      final snap = await _db.collection(_col).get();
      return snap.docs
          .map((d) => HolidayModel.fromMap({...d.data(), 'id': d.id}))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      if (kDebugMode) debugPrint('[HolidayService] fetchAll error: $e');
      return [];
    }
  }

  // ── Fetch holidays for a specific department ───────────────────────────────
  static Future<List<HolidayModel>> fetchForDept(String dept) async {
    final all = await fetchAll();
    return all.where((h) => h.appliesToDept(dept)).toList();
  }

  // ── Seed Indian holidays (only if collection is empty) ────────────────────
  static Future<void> seedIfEmpty() async {
    try {
      final snap =
          await _db.collection(_col).limit(1).get();
      if (snap.docs.isNotEmpty) return; // already seeded

      final batch = _db.batch();
      for (final h in IndianHolidays.holidays2025) {
        final ref = _db.collection(_col).doc(h.id);
        batch.set(ref, h.toMap());
      }
      await batch.commit();
      if (kDebugMode) debugPrint('[HolidayService] Seeded ${IndianHolidays.holidays2025.length} Indian holidays');
    } catch (e) {
      if (kDebugMode) debugPrint('[HolidayService] seedIfEmpty error: $e');
    }
  }

  // ── Add a new custom holiday ───────────────────────────────────────────────
  static Future<void> addHoliday(HolidayModel holiday) async {
    try {
      await _db.collection(_col).doc(holiday.id).set(holiday.toMap());
    } catch (e) {
      if (kDebugMode) debugPrint('[HolidayService] addHoliday error: $e');
    }
  }

  // ── Update department applicability for a holiday ─────────────────────────
  static Future<void> updateDeptApplicability({
    required String holidayId,
    required List<String> depts, // empty = all depts
  }) async {
    try {
      await _db.collection(_col).doc(holidayId).update({
        'applicable_departments': depts,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[HolidayService] updateDepts error: $e');
    }
  }

  // ── Delete a holiday ──────────────────────────────────────────────────────
  static Future<void> deleteHoliday(String holidayId) async {
    try {
      await _db.collection(_col).doc(holidayId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[HolidayService] delete error: $e');
    }
  }

  // ── Upsert (create or replace) ────────────────────────────────────────────
  static Future<void> upsert(HolidayModel holiday) async {
    try {
      await _db.collection(_col).doc(holiday.id).set(
            holiday.toMap(),
            SetOptions(merge: false),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('[HolidayService] upsert error: $e');
    }
  }
}
