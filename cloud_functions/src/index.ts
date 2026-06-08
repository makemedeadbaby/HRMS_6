/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * Abhishek International HRMS — Firebase Cloud Functions
 * Project : abhishek-international-hrms
 * Region  : asia-south1  (Mumbai — closest to your employees)
 *
 * Functions in this file:
 *
 * 1. processScheduledNotifications  (pubsub every-minute scheduler)
 *    Polls `scheduled_notifications` for documents whose `scheduled_at` ≤ now
 *    and `processed == false`, then fires FCM push for each one.
 *    Marks each document processed=true + adds processed_at timestamp.
 *
 * 2. processFcmSendQueue  (Firestore onCreate trigger on `fcm_send_queue`)
 *    Fires immediately when admin sends a notification from the app panel.
 *    Reads the token list already stored in the doc and calls FCM multicast.
 *
 * 3. onEmployeeCheckIn  (Firestore onCreate trigger on `attendance`)
 *    Auto-schedules logout reminder + shift reminder when a check-in doc appears.
 *    This ensures reminders fire even if the app crashes after check-in.
 *
 * 4. cleanupOldNotifications  (pubsub daily)
 *    Deletes processed scheduled_notifications older than 7 days to keep
 *    Firestore tidy and reduce read costs.
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// ── Init ───────────────────────────────────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ── Region — set to Mumbai for minimum latency to Indian users ─────────────────
const REGION = "asia-south1";

// ── Collection names (must match Flutter app) ─────────────────────────────────
const COL_SCHEDULED = "scheduled_notifications";
const COL_FCM_QUEUE = "fcm_send_queue";
const COL_ATTENDANCE = "attendance";
const COL_EMPLOYEES  = "employees";

// ── Notification type constants (must match NotificationScheduler.dart) ────────
type NotifType = "break_end" | "logout_reminder" | "shift_reminder" | "custom";

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1 — processScheduledNotifications
//
// Runs every minute via Cloud Scheduler.
// Picks up any document in `scheduled_notifications` where:
//   • processed == false
//   • scheduled_at <= now
// Sends a single FCM push to the stored token, then marks it processed.
// ─────────────────────────────────────────────────────────────────────────────
export const processScheduledNotifications = functions
  .region(REGION)
  .pubsub
  .schedule("every 1 minutes")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    // Query all due, unprocessed notifications
    const snap = await db
      .collection(COL_SCHEDULED)
      .where("processed", "==", false)
      .where("scheduled_at", "<=", now)
      .limit(100) // process max 100 per minute to stay within function timeout
      .get();

    if (snap.empty) {
      functions.logger.info("[ScheduledNotifs] No due notifications.");
      return;
    }

    functions.logger.info(
      `[ScheduledNotifs] Processing ${snap.docs.length} notifications`
    );

    const batch = db.batch();
    const sends: Promise<string>[] = [];

    for (const doc of snap.docs) {
      const data = doc.data();
      const token: string = data.fcm_token ?? "";
      const title: string = data.title ?? "Abhishek HRMS";
      const body: string  = data.body ?? "";
      const type: NotifType = data.type ?? "custom";
      const employeeId: string = data.employee_id ?? "";

      if (!token) {
        functions.logger.warn(
          `[ScheduledNotifs] Doc ${doc.id} has no fcm_token — skipping`
        );
        // Still mark processed so we don't keep retrying an empty token
        batch.update(doc.ref, {
          processed: true,
          processed_at: admin.firestore.FieldValue.serverTimestamp(),
          error: "no_token",
        });
        continue;
      }

      // Build the FCM message
      const message: admin.messaging.Message = {
        token,
        notification: { title, body },
        android: {
          priority: "high",
          notification: {
            channelId: _androidChannelForType(type),
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            // Show notification even if app is in foreground
            visibility: "public",
          },
        },
        data: {
          type,
          employee_id: employeeId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          notification_id: doc.id,
        },
      };

      // Queue the send
      sends.push(
        messaging.send(message).then((msgId) => {
          functions.logger.info(
            `[ScheduledNotifs] ✅ Sent ${type} to ${employeeId} — msgId: ${msgId}`
          );
          return msgId;
        })
      );

      // Mark processed immediately in the batch (optimistic)
      batch.update(doc.ref, {
        processed: true,
        processed_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Commit batch + await all sends in parallel
    await Promise.all([batch.commit(), Promise.allSettled(sends)]);
    functions.logger.info("[ScheduledNotifs] Batch complete.");
  });

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2 — processFcmSendQueue
//
// Triggered instantly when admin sends a notification from the app panel.
// The Flutter app writes to `fcm_send_queue` with a list of tokens.
// This function fires the FCM multicast immediately (no 1-minute lag).
// ─────────────────────────────────────────────────────────────────────────────
export const processFcmSendQueue = functions
  .region(REGION)
  .firestore
  .document(`${COL_FCM_QUEUE}/{docId}`)
  .onCreate(async (snap) => {
    const data = snap.data();

    // Idempotency guard — if somehow already processed, skip
    if (data.processed === true) return;

    const tokens: string[] = (data.tokens as string[]) ?? [];
    const title: string    = data.title ?? "Abhishek HRMS";
    const body: string     = data.body ?? "";
    const priority: string = data.priority ?? "normal";
    const targetType: string = data.target_type ?? "global";

    if (tokens.length === 0) {
      await snap.ref.update({ processed: true, error: "no_tokens" });
      functions.logger.warn(`[FcmQueue] ${snap.id} — no tokens, skipped`);
      return;
    }

    functions.logger.info(
      `[FcmQueue] Sending to ${tokens.length} device(s) — target: ${targetType}`
    );

    // FCM allows max 500 tokens per multicast; chunk if needed
    const results: admin.messaging.SendResponse[] = [];

    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const multicastMsg: admin.messaging.MulticastMessage = {
        tokens: chunk,
        notification: { title, body },
        android: {
          priority: priority === "high" ? "high" : "normal",
          notification: {
            channelId: "hrms_admin_channel",
            priority: "high",
            defaultSound: true,
            visibility: "public",
          },
        },
        data: {
          type: "admin_notification",
          target_type: targetType,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      const response = await messaging.sendEachForMulticast(multicastMsg);
      results.push(...response.responses);

      const successCount = response.successCount;
      const failCount    = response.failureCount;
      functions.logger.info(
        `[FcmQueue] Chunk sent — success: ${successCount}, fail: ${failCount}`
      );

      // Auto-clean stale tokens from employee docs
      const staleCleaner: Promise<void>[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errCode = resp.error?.code ?? "";
          const staleErrors = [
            "messaging/invalid-registration-token",
            "messaging/registration-token-not-registered",
          ];
          if (staleErrors.includes(errCode)) {
            const staleToken = chunk[idx];
            staleCleaner.push(_clearStaleToken(staleToken));
          }
        }
      });
      await Promise.allSettled(staleCleaner);
    }

    const totalSuccess = results.filter((r) => r.success).length;

    await snap.ref.update({
      processed: true,
      processed_at: admin.firestore.FieldValue.serverTimestamp(),
      delivery_count: totalSuccess,
    });

    functions.logger.info(
      `[FcmQueue] ✅ Done — ${totalSuccess}/${tokens.length} delivered`
    );
  });

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 3 — onEmployeeCheckIn
//
// Firestore trigger: fires when a new attendance document is created.
// This is a server-side guarantee that logout + shift reminders are always
// scheduled, even if the Flutter app crashes after checkIn() runs.
//
// It reads the employee's shiftEndTime / shiftStartTime from the `employees`
// collection and writes to `scheduled_notifications`, just like the app does.
// The minute-scheduler (Function 1) then picks it up and fires the push.
// ─────────────────────────────────────────────────────────────────────────────
export const onEmployeeCheckIn = functions
  .region(REGION)
  .firestore
  .document(`${COL_ATTENDANCE}/{docId}`)
  .onCreate(async (snap) => {
    const att = snap.data();
    const employeeId: string = att.employee_id ?? att.employeeId ?? "";

    if (!employeeId) return;

    // Fetch the employee record to get FCM token + shift times
    const empSnap = await db.collection(COL_EMPLOYEES).doc(employeeId).get();
    if (!empSnap.exists) {
      functions.logger.warn(
        `[CheckIn] Employee ${employeeId} not found in Firestore`
      );
      return;
    }

    const emp = empSnap.data()!;
    const fcmToken: string   = emp.fcm_token ?? "";
    const shiftEnd: string   = emp.shift_end_time ?? "";
    const shiftStart: string = emp.shift_start_time ?? "";
    const shiftType: string  = emp.shift_type ?? "Day Shift";

    if (!fcmToken) {
      functions.logger.info(
        `[CheckIn] ${employeeId} has no FCM token — no reminders scheduled`
      );
      return;
    }

    const now = new Date();
    const scheduled: Promise<admin.firestore.DocumentReference>[] = [];

    // ── Logout reminder: 1 hour before shift end ────────────────────────────
    const endDt = _parseShiftTime(shiftEnd, now);
    if (endDt) {
      const reminderAt = new Date(endDt.getTime() - 60 * 60 * 1000); // -1 hour
      if (reminderAt > now) {
        scheduled.push(
          _upsertScheduledNotif({
            employeeId,
            fcmToken,
            title: "🕐 1 Hour Left to Check Out",
            body: `Your shift ends at ${shiftEnd}. Don't forget to check out!`,
            scheduledAt: reminderAt,
            type: "logout_reminder",
          })
        );
        functions.logger.info(
          `[CheckIn] Logout reminder for ${employeeId} at ${reminderAt.toISOString()}`
        );
      }
    }

    // ── Shift start reminder: 15 mins before next shift start ───────────────
    const startDt = _parseShiftTime(shiftStart, now);
    if (startDt) {
      // Always push to "tomorrow's" shift start if already past today's
      const tomorrowStart = new Date(startDt.getTime());
      if (tomorrowStart <= now) {
        tomorrowStart.setDate(tomorrowStart.getDate() + 1);
      }
      const shiftReminderAt = new Date(
        tomorrowStart.getTime() - 15 * 60 * 1000
      ); // -15 mins
      if (shiftReminderAt > now) {
        scheduled.push(
          _upsertScheduledNotif({
            employeeId,
            fcmToken,
            title: "🌅 Shift Starting Soon",
            body: `Your ${shiftType} starts at ${shiftStart}. Time to get ready!`,
            scheduledAt: shiftReminderAt,
            type: "shift_reminder",
          })
        );
        functions.logger.info(
          `[CheckIn] Shift reminder for ${employeeId} at ${shiftReminderAt.toISOString()}`
        );
      }
    }

    await Promise.allSettled(scheduled);
  });

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 4 — cleanupOldNotifications
//
// Runs daily at 3 AM IST.
// Deletes processed scheduled_notifications older than 7 days.
// Keeps Firestore lean and prevents ever-growing read costs.
// ─────────────────────────────────────────────────────────────────────────────
export const cleanupOldNotifications = functions
  .region(REGION)
  .pubsub
  .schedule("0 3 * * *")      // 3:00 AM every day
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // 7 days ago
    );

    const snap = await db
      .collection(COL_SCHEDULED)
      .where("processed", "==", true)
      .where("processed_at", "<=", cutoff)
      .limit(500)
      .get();

    if (snap.empty) {
      functions.logger.info("[Cleanup] Nothing to delete.");
      return;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    functions.logger.info(
      `[Cleanup] ✅ Deleted ${snap.docs.length} old notifications`
    );
  });

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — _upsertScheduledNotif
// Creates or replaces a scheduled notification for an employee+type combo.
// Prevents duplicate reminders if the function is triggered multiple times.
// ─────────────────────────────────────────────────────────────────────────────
async function _upsertScheduledNotif(opts: {
  employeeId: string;
  fcmToken: string;
  title: string;
  body: string;
  scheduledAt: Date;
  type: NotifType;
}): Promise<admin.firestore.DocumentReference> {
  const { employeeId, fcmToken, title, body, scheduledAt, type } = opts;

  // Delete any existing unprocessed notification of same type for this employee
  const existing = await db
    .collection(COL_SCHEDULED)
    .where("employee_id", "==", employeeId)
    .where("type", "==", type)
    .where("processed", "==", false)
    .get();

  const deleteBatch = db.batch();
  existing.docs.forEach((d) => deleteBatch.delete(d.ref));
  if (!existing.empty) await deleteBatch.commit();

  // Write fresh
  const ref = await db.collection(COL_SCHEDULED).add({
    employee_id: employeeId,
    fcm_token: fcmToken,
    title,
    body,
    scheduled_at: admin.firestore.Timestamp.fromDate(scheduledAt),
    type,
    processed: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    created_by: "cloud_function",
  });

  return ref;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — _parseShiftTime
// Converts "09:30 AM" → today's Date object in IST.
// ─────────────────────────────────────────────────────────────────────────────
function _parseShiftTime(timeStr: string, baseDate: Date): Date | null {
  if (!timeStr) return null;
  try {
    const parts = timeStr.trim().split(" ");
    if (parts.length < 2) return null;
    const [hStr, mStr] = parts[0].split(":");
    let hour = parseInt(hStr, 10);
    const minute = parseInt(mStr, 10);
    const isPm = parts[1].toUpperCase() === "PM";
    if (isPm && hour !== 12) hour += 12;
    if (!isPm && hour === 12) hour = 0;

    const d = new Date(baseDate);
    d.setHours(hour, minute, 0, 0);
    return d;
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — _androidChannelForType
// Maps notification type to a pre-defined Android notification channel.
// Channels are created by the Flutter app on first launch.
// ─────────────────────────────────────────────────────────────────────────────
function _androidChannelForType(type: NotifType): string {
  switch (type) {
    case "break_end":        return "hrms_break_channel";
    case "logout_reminder":  return "hrms_reminder_channel";
    case "shift_reminder":   return "hrms_reminder_channel";
    default:                 return "hrms_admin_channel";
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — _clearStaleToken
// Removes an invalid/expired FCM token from the employee document so we
// don't keep sending to dead tokens and wasting quota.
// ─────────────────────────────────────────────────────────────────────────────
async function _clearStaleToken(token: string): Promise<void> {
  try {
    // Find the employee with this token
    const snap = await db
      .collection(COL_EMPLOYEES)
      .where("fcm_token", "==", token)
      .limit(1)
      .get();

    if (snap.empty) return;

    await snap.docs[0].ref.update({ fcm_token: "" });
    functions.logger.info(
      `[StaleToken] Cleared dead token from ${snap.docs[0].id}`
    );
  } catch (e) {
    functions.logger.warn(`[StaleToken] Failed to clear token: ${e}`);
  }
}
// updated: Mon Jun  8 23:26:55 UTC 2026
