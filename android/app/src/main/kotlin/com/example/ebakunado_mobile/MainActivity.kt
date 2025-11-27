package com.example.ebakunado_mobile

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.edit
import java.util.Calendar
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.ebakunado/alarms"
    private val prefsName = "ebakunado_native_prefs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    try {
                        val canSchedule = canScheduleExactAlarms()
                        result.success(canSchedule)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "requestScheduleExactAlarms" -> {
                    try {
                        requestScheduleExactAlarms()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openSystemNotificationSettings" -> {
                    try {
                        openSystemNotificationSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openSystemBatterySettings" -> {
                    try {
                        openSystemBatterySettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getDeviceTimeZone" -> {
                    try {
                        val tzId = TimeZone.getDefault().id // e.g., "Asia/Manila"
                        result.success(tzId)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "saveFallbackNotification" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val title = args?.get("title") as? String ?: ""
                        val body = args?.get("body") as? String ?: ""
                        saveFallbackNotification(title, body)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "scheduleNativeAlarm" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val epochMillis = (args?.get("epochMillis") as? Number)?.toLong()
                        val hour = (args?.get("hour") as? Number)?.toInt()
                        val minute = (args?.get("minute") as? Number)?.toInt()

                        if (epochMillis == null || hour == null || minute == null) {
                            result.error("ARG_ERROR", "Missing epochMillis/hour/minute", null)
                        } else {
                            scheduleNativeAlarm(epochMillis, hour, minute)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "cancelNativeAlarm" -> {
                    try {
                        cancelNativeAlarm()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "scheduleNativeNotification" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        scheduleNativeNotification(args)
                        result.success(true)
                    } catch (e: IllegalArgumentException) {
                        result.error("ARG_ERROR", e.message, null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "wasNotificationShownByNative" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val babyId = args?.get("babyId") as? String ?: ""
                        val payload = args?.get("payload") as? String ?: ""
                        val date = args?.get("date") as? String ?: ""
                        
                        if (babyId.isEmpty() || date.isEmpty()) {
                            result.success(false)
                        } else {
                            val wasShown = wasNotificationShownByNative(babyId, payload, date)
                            result.success(wasShown)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "cancelNativeNotification" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val id = (args?.get("id") as? Number)?.toInt()
                            ?: throw IllegalArgumentException("Missing notification id")
                        cancelNativeNotification(id)
                        result.success(true)
                    } catch (e: IllegalArgumentException) {
                        result.error("ARG_ERROR", e.message, null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "cancelNativeNotificationsRange" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val startId = (args?.get("startId") as? Number)?.toInt()
                            ?: throw IllegalArgumentException("Missing startId")
                        val endId = (args["endId"] as? Number)?.toInt()
                            ?: throw IllegalArgumentException("Missing endId")
                        cancelNativeNotificationsRange(startId, endId)
                        result.success(true)
                    } catch (e: IllegalArgumentException) {
                        result.error("ARG_ERROR", e.message, null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "scheduleDailyCheckAlarms" -> {
                    try {
                        val args = call.arguments as? Map<*, *>
                        val slots = args?.get("slots") as? List<*>
                        scheduleDailyCheckAlarms(slots)
                        result.success(true)
                    } catch (e: IllegalArgumentException) {
                        result.error("ARG_ERROR", e.message, null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "cancelDailyCheckAlarms" -> {
                    try {
                        cancelDailyCheckAlarms()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        // On Android 12+ we can query AlarmManager.canScheduleExactAlarms()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            // Below Android 12, exact alarm special permission is not required
            true
        }
    }

    private fun requestScheduleExactAlarms() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Prefer the official request intent on Android 12+
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            } catch (_: Exception) {
                // Fall through to app details if the action is not available
            }
        }
        // Fallback: open the app details settings where user can navigate to Special app access
        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(fallback)
    }

    private fun openSystemNotificationSettings() {
        try {
            // Direct to App notification settings for this package
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {
            // Fallback: app details page
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallback)
        }
    }

    private fun openSystemBatterySettings() {
        // Best effort: open app details so user can reach Battery/Unrestricted
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {
            // Fallback: open main battery optimization screen
            try {
                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallback)
            } catch (_: Exception) {
                // Last resort: open general settings
                val general = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(general)
            }
        }
    }

    private fun saveFallbackNotification(title: String, body: String) {
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit {
            putString(NotificationAlarmReceiver.KEY_TITLE, title)
            putString(NotificationAlarmReceiver.KEY_BODY, body)
        }
    }

    private fun scheduleNativeAlarm(targetMillis: Long, hour: Int, minute: Int) {
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit {
            putInt(NotificationAlarmReceiver.KEY_HOUR, hour)
            putInt(NotificationAlarmReceiver.KEY_MINUTE, minute)
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis = adjustTriggerTime(targetMillis, hour, minute)

        val intent = Intent(applicationContext, NotificationAlarmReceiver::class.java).apply {
            action = NotificationAlarmReceiver.ACTION_NATIVE_ALARM
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            NotificationAlarmReceiver.REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent
        )
    }

    private fun cancelNativeAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, NotificationAlarmReceiver::class.java).apply {
            action = NotificationAlarmReceiver.ACTION_NATIVE_ALARM
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            NotificationAlarmReceiver.REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
    }

    private fun scheduleNativeNotification(args: Map<*, *>?) {
        val id = (args?.get("id") as? Number)?.toInt()
            ?: throw IllegalArgumentException("Missing notification id")
        val triggerAtMillis = (args["triggerAtMillis"] as? Number)?.toLong()
            ?: throw IllegalArgumentException("Missing triggerAtMillis")
        val title = args["title"] as? String ?: ""
        val body = args["body"] as? String ?: ""
        val channelId = args["channelId"] as? String
            ?: NotificationAlarmReceiver.CHANNEL_ID
        val payload = args["payload"] as? String

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            throw IllegalStateException("Exact alarm permission not granted")
        }

        val intent = Intent(applicationContext, NotificationAlarmReceiver::class.java).apply {
            action = NotificationAlarmReceiver.ACTION_NATIVE_NOTIFICATION
            putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_ID, id)
            putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_TITLE, title)
            putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_BODY, body)
            putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_CHANNEL_ID, channelId)
            payload?.let {
                putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_PAYLOAD, it)
            }
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
    }

    private fun cancelNativeNotification(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, NotificationAlarmReceiver::class.java).apply {
            action = NotificationAlarmReceiver.ACTION_NATIVE_NOTIFICATION
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun cancelNativeNotificationsRange(startId: Int, endId: Int) {
        if (startId > endId) return
        for (id in startId..endId) {
            cancelNativeNotification(id)
        }
    }

    private fun scheduleDailyCheckAlarms(slotArgs: List<*>?) {
        val slots = slotArgs ?: throw IllegalArgumentException("Missing slots")
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val jsonArray = JSONArray()

        slots.forEach { entry ->
            val slotMap = entry as? Map<*, *>
                ?: throw IllegalArgumentException("Invalid slot entry")
            val requestCode = (slotMap["requestCode"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Missing requestCode")
            val hour = (slotMap["hour"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Missing hour")
            val minute = (slotMap["minute"] as? Number)?.toInt()
                ?: throw IllegalArgumentException("Missing minute")
            val epochMillis = (slotMap["epochMillis"] as? Number)?.toLong() ?: 0L
            val title = slotMap["title"] as? String
                ?: "Daily Immunization Check"
            val body = slotMap["body"] as? String
                ?: "No immunizations due today or tomorrow."

            scheduleDailyCheckAlarm(
                requestCode,
                hour,
                minute,
                epochMillis,
                title,
                body
            )

            val jsonObject = JSONObject().apply {
                put("requestCode", requestCode)
                put("hour", hour)
                put("minute", minute)
                put("title", title)
                put("body", body)
            }
            jsonArray.put(jsonObject)
        }

        prefs.edit {
            putString(NotificationAlarmReceiver.KEY_DAILY_CHECK_SLOTS, jsonArray.toString())
        }
    }

    private fun cancelDailyCheckAlarms() {
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val json = prefs.getString(NotificationAlarmReceiver.KEY_DAILY_CHECK_SLOTS, null)
        if (json != null) {
            val array = JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                val requestCode = obj.optInt("requestCode", -1)
                if (requestCode != -1) {
                    cancelDailyCheckAlarm(requestCode)
                }
            }
        }

        prefs.edit {
            remove(NotificationAlarmReceiver.KEY_DAILY_CHECK_SLOTS)
        }
    }

    private fun scheduleDailyCheckAlarm(
        requestCode: Int,
        hour: Int,
        minute: Int,
        epochMillis: Long,
        title: String,
        body: String
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, NotificationAlarmReceiver::class.java).apply {
            action = NotificationAlarmReceiver.ACTION_DAILY_CHECK_ALARM
            putExtra(NotificationAlarmReceiver.EXTRA_DAILY_REQUEST_CODE, requestCode)
            putExtra(NotificationAlarmReceiver.EXTRA_DAILY_HOUR, hour)
            putExtra(NotificationAlarmReceiver.EXTRA_DAILY_MINUTE, minute)
            putExtra(NotificationAlarmReceiver.EXTRA_DAILY_TITLE, title)
            putExtra(NotificationAlarmReceiver.EXTRA_DAILY_BODY, body)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val adjustedTarget = if (epochMillis > 0L) {
            adjustTriggerTime(epochMillis, hour, minute)
        } else {
            adjustTriggerTime(System.currentTimeMillis(), hour, minute)
        }

        val showIntent = PendingIntent.getActivity(
            applicationContext,
            requestCode + 1000,
            Intent(applicationContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val alarmClockInfo = AlarmManager.AlarmClockInfo(
                adjustedTarget,
                showIntent
            )
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                adjustedTarget,
                pendingIntent
            )
        }
    }

    private fun cancelDailyCheckAlarm(requestCode: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, NotificationAlarmReceiver::class.java).apply {
            action = NotificationAlarmReceiver.ACTION_DAILY_CHECK_ALARM
        }

        val pendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()

        val showIntent = PendingIntent.getActivity(
            applicationContext,
            requestCode + 1000,
            Intent(applicationContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(showIntent)
        showIntent.cancel()
    }

    private fun adjustTriggerTime(targetMillis: Long, hour: Int, minute: Int): Long {
        val now = System.currentTimeMillis()
        if (targetMillis > now) {
            return targetMillis
        }

        val calendar = Calendar.getInstance().apply {
            timeZone = TimeZone.getDefault()
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= now) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        return calendar.timeInMillis
    }

    private fun wasNotificationShownByNative(babyId: String, payload: String, date: String): Boolean {
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val notificationKey = "shown_notif_$babyId$payload$date"
        val lastShown = prefs.getString(notificationKey, null)
        return lastShown == date
    }
}
