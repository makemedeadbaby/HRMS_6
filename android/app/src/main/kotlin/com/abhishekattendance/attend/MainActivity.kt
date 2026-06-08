package com.abhishekattendance.attend

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Register notification channels on Android 8+ (API 26+)
        // These channels must exist before FCM data-messages can display notifications.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannels()
        }
    }

    private fun createNotificationChannels() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // ── Channel 1 : Break reminders ──────────────────────────────────────
        // Used for: break_end FCM push from Cloud Function
        val breakChannel = NotificationChannel(
            "hrms_break_channel",
            "Break Reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alerts when your break time is over"
            enableVibration(true)
            enableLights(true)
        }

        // ── Channel 2 : Shift / logout reminders ─────────────────────────────
        // Used for: logout_reminder and shift_reminder FCM pushes
        val reminderChannel = NotificationChannel(
            "hrms_reminder_channel",
            "Shift Reminders",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Shift start and check-out reminders"
            enableVibration(true)
        }

        // ── Channel 3 : Admin broadcasts ─────────────────────────────────────
        // Used for: admin-panel notifications sent to all / company / dept
        val adminChannel = NotificationChannel(
            "hrms_admin_channel",
            "Admin Notifications",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Company-wide announcements and admin alerts"
            enableVibration(true)
            enableLights(true)
        }

        manager.createNotificationChannels(
            listOf(breakChannel, reminderChannel, adminChannel)
        )
    }
}
