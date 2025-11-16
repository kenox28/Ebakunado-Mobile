package com.example.ebakunado_mobile

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONArray
import com.example.ebakunado_mobile.DailyCheckService

class NotificationAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                // Re-schedule alarm after device reboot using stored hour/minute.
                rescheduleFromPrefs(context, adjustForPast = false)
                rescheduleDailyChecksFromPrefs(context, adjustForPast = false)
            }
            ACTION_NATIVE_NOTIFICATION -> {
                showCustomNotification(context, intent)
            }
            ACTION_NATIVE_ALARM, null -> {
                showFallbackNotification(context, isDailyCheck = false, requestCode = -1, titleOverride = null, bodyOverride = null)
                // Schedule the next day using stored hour/minute.
                rescheduleFromPrefs(context, adjustForPast = true)
            }
            ACTION_DAILY_CHECK_ALARM -> {
                val requestCode = intent?.getIntExtra(EXTRA_DAILY_REQUEST_CODE, -1) ?: -1
                val title = intent?.getStringExtra(EXTRA_DAILY_TITLE)
                val body = intent?.getStringExtra(EXTRA_DAILY_BODY)
                // New native-only path: display per-child notifications from cache; no background Flutter
                showPerChildFromCache(context, requestCode)
                rescheduleDailyChecksFromPrefs(
                    context,
                    adjustForPast = true,
                    specificRequestCode = requestCode
                )
            }
            else -> {
                // Ignore other actions
            }
        }
    }

    private fun showPerChildFromCache(context: Context, requestCode: Int) {
        // Read from Flutter's SharedPreferences store where Dart saved the cache
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val cacheDate = flutterPrefs.getString(FLUTTER_KEY_NATIVE_CACHE_DATE, null)
        if (cacheDate != today) {
            // Cache stale or missing; nothing to show
            return
        }

        val todayJson = flutterPrefs.getString(FLUTTER_KEY_NATIVE_TODAY_LIST, null) ?: "[]"
        val tomorrowJson = flutterPrefs.getString(FLUTTER_KEY_NATIVE_TOMORROW_LIST, null) ?: "[]"

        // Policy: always show today's entries on alarm
        postEntries(context, JSONArray(todayJson))
        // Optional: In evening (approx 23:59), also post tomorrow's previews
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (hour >= 21) {
            postEntries(context, JSONArray(tomorrowJson))
        }
    }

    private fun postEntries(context: Context, array: JSONArray) {
        if (array.length() == 0) return
        val notificationManager = ContextCompat.getSystemService(
            context,
            NotificationManager::class.java
        ) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Immunization notifications"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val babyId = obj.optString("id", "")
            val title = obj.optString("title", "Immunization Reminder")
            val body = obj.optString("body", "")
            val payload = obj.optString("payload", null)
            if (title.isBlank() || body.isBlank()) continue

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (payload != null) putExtra(EXTRA_NOTIFICATION_PAYLOAD, payload)
            }
            val notifId = (babyId.hashCode() % 100000 + 60000)
            val pendingIntent = PendingIntent.getActivity(
                context,
                notifId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .build()

            notificationManager.notify(notifId, notification)
        }
    }

    private fun showCustomNotification(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_NOTIFICATION_ID, NOTIFICATION_ID)
        val title = intent.getStringExtra(EXTRA_NOTIFICATION_TITLE)
            ?: "Immunization Reminder"
        val body = intent.getStringExtra(EXTRA_NOTIFICATION_BODY)
            ?: "Open Ebakunado to check upcoming immunizations."
        val channelId = intent.getStringExtra(EXTRA_NOTIFICATION_CHANNEL_ID)
            ?: CHANNEL_ID
        val payload = intent.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD)

        val notificationManager = ContextCompat.getSystemService(
            context,
            NotificationManager::class.java
        ) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Scheduled immunization notifications"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            payload?.let { putExtra(EXTRA_NOTIFICATION_PAYLOAD, it) }
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            // Avoid full-screen popup to prevent app interruption
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        notificationManager.notify(id, notification)
    }

    private fun showFallbackNotification(
        context: Context,
        isDailyCheck: Boolean,
        requestCode: Int,
        titleOverride: String?,
        bodyOverride: String?
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        if (isDailyCheck) {
            // If no explicit title/body, do not show any daily fallback notification
            if (titleOverride.isNullOrBlank() || bodyOverride.isNullOrBlank()) {
                return
            }
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val lastShownKey = "$KEY_LAST_DAILY_FALLBACK_DAY-$requestCode"
            val lastShown = prefs.getString(lastShownKey, null)
            if (today == lastShown) {
                return
            }
            prefs.edit().putString(lastShownKey, today).apply()
        }

        val title = if (isDailyCheck) titleOverride
        else prefs.getString(KEY_TITLE, "Immunization Reminder")
        val body = if (isDailyCheck) bodyOverride
        else prefs.getString(KEY_BODY, "Open Ebakunado to check upcoming immunizations.")

        val notificationManager = ContextCompat.getSystemService(context, NotificationManager::class.java)
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for daily immunization reminders"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            REQUEST_CODE_ACTIVITY,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title ?: "")
            .setContentText(body ?: "")
            .setStyle(NotificationCompat.BigTextStyle().bigText(body ?: ""))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            // Avoid full-screen popup to prevent app interruption
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun findDailySlotDetail(prefs: android.content.SharedPreferences, requestCode: Int): org.json.JSONObject? {
        val json = prefs.getString(KEY_DAILY_CHECK_SLOTS, null) ?: return null
        val array = JSONArray(json)
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            if (obj.optInt("requestCode") == requestCode) {
                return obj
            }
        }
        return null
    }

    private fun startDailyCheckService(
        context: Context,
        requestCode: Int,
        title: String?,
        body: String?
    ) {
        if (requestCode == -1) {
            return
        }

        val serviceIntent = Intent(context, DailyCheckService::class.java).apply {
            putExtra(DailyCheckService.EXTRA_REQUEST_CODE, requestCode)
            putExtra(DailyCheckService.EXTRA_TITLE, title)
            putExtra(DailyCheckService.EXTRA_BODY, body)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun rescheduleFromPrefs(context: Context, adjustForPast: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val hour = prefs.getInt(KEY_HOUR, -1)
        val minute = prefs.getInt(KEY_MINUTE, -1)

        if (hour !in 0..23 || minute !in 0..59) {
            return
        }

        val calendar = Calendar.getInstance().apply {
            timeZone = TimeZone.getDefault()
            if (adjustForPast) {
                timeInMillis = System.currentTimeMillis()
            }
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)

            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
            action = ACTION_NATIVE_ALARM
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            pendingIntent
        )
    }

    private fun rescheduleDailyChecksFromPrefs(
        context: Context,
        adjustForPast: Boolean,
        specificRequestCode: Int? = null
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_DAILY_CHECK_SLOTS, null) ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        val array = JSONArray(json)
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val requestCode = obj.optInt("requestCode", -1)
            if (requestCode == -1) continue
            if (specificRequestCode != null && specificRequestCode != requestCode) continue

            val hour = obj.optInt("hour", -1)
            val minute = obj.optInt("minute", -1)
            if (hour !in 0..23 || minute !in 0..59) continue

            val calendar = Calendar.getInstance().apply {
                timeZone = TimeZone.getDefault()
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (adjustForPast || timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
                action = ACTION_DAILY_CHECK_ALARM
                putExtra(EXTRA_DAILY_REQUEST_CODE, requestCode)
                putExtra(EXTRA_DAILY_HOUR, hour)
                putExtra(EXTRA_DAILY_MINUTE, minute)
                // Do not attach default title/body; background service will compute fresh content
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val showIntent = PendingIntent.getActivity(
                context,
                requestCode + 1000,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val alarmClockInfo = AlarmManager.AlarmClockInfo(
                    calendar.timeInMillis,
                    showIntent
                )
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        }
    }

    companion object {
        const val ACTION_NATIVE_ALARM = "com.example.ebakunado_mobile.ACTION_NATIVE_ALARM"
        const val ACTION_NATIVE_NOTIFICATION = "com.example.ebakunado_mobile.ACTION_NATIVE_NOTIFICATION"
        const val ACTION_DAILY_CHECK_ALARM = "com.example.ebakunado_mobile.ACTION_DAILY_CHECK_ALARM"
        const val PREFS_NAME = "ebakunado_native_prefs"

        const val KEY_TITLE = "fallback_title"
        const val KEY_BODY = "fallback_body"
        const val KEY_HOUR = "fallback_hour"
        const val KEY_MINUTE = "fallback_minute"
        const val KEY_DAILY_CHECK_SLOTS = "daily_check_slots"
        const val KEY_LAST_DAILY_FALLBACK_DAY = "daily_fallback_last_day"
        // Flutter SharedPreferences file and keys (plugin stores under this file with 'flutter.' prefix)
        const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        const val FLUTTER_KEY_NATIVE_CACHE_DATE = "flutter.native_cache_date"
        const val FLUTTER_KEY_NATIVE_TODAY_LIST = "flutter.native_today_notifications"
        const val FLUTTER_KEY_NATIVE_TOMORROW_LIST = "flutter.native_tomorrow_notifications"

        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_NOTIFICATION_TITLE = "extra_notification_title"
        const val EXTRA_NOTIFICATION_BODY = "extra_notification_body"
        const val EXTRA_NOTIFICATION_CHANNEL_ID = "extra_notification_channel_id"
        const val EXTRA_NOTIFICATION_PAYLOAD = "extra_notification_payload"
        const val EXTRA_DAILY_REQUEST_CODE = "extra_daily_request_code"
        const val EXTRA_DAILY_HOUR = "extra_daily_hour"
        const val EXTRA_DAILY_MINUTE = "extra_daily_minute"
        const val EXTRA_DAILY_TITLE = "extra_daily_title"
        const val EXTRA_DAILY_BODY = "extra_daily_body"

        const val REQUEST_CODE = 900001
        const val REQUEST_CODE_ACTIVITY = 900002
        const val CHANNEL_ID = "immunization_channel"
        const val CHANNEL_NAME = "Immunization Notifications"
        const val NOTIFICATION_ID = 100500
    }
}

