package com.example.ebakunado_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class DailyCheckService : Service() {
    companion object {
        const val EXTRA_REQUEST_CODE = "extra_request_code"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"

        private const val FOREGROUND_CHANNEL_ID = "daily_check_sync_channel"
        private const val FOREGROUND_CHANNEL_NAME = "Daily Check Sync"
        private const val FOREGROUND_NOTIFICATION_ID = 920001
        private const val BACKGROUND_CHANNEL_NAME = "com.ebakunado/alarm_background"
    }

    private var flutterEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private var isReady = false
    private var pendingArguments: Map<String, Any?>? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundNotification()
        initializeFlutterEngine()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val requestCode = intent?.getIntExtra(EXTRA_REQUEST_CODE, -1) ?: -1
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val body = intent?.getStringExtra(EXTRA_BODY) ?: ""

        pendingArguments = mapOf(
            "requestCode" to requestCode,
            "title" to title,
            "body" to body,
            "triggerMillis" to System.currentTimeMillis(),
        )

        dispatchIfReady()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        backgroundChannel?.setMethodCallHandler(null)
        flutterEngine?.destroy()
        flutterEngine = null
        backgroundChannel = null
        isReady = false
        pendingArguments = null
        super.onDestroy()
    }

    private fun startForegroundNotification() {
        val manager = ContextCompat.getSystemService(this, NotificationManager::class.java)
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existing = manager.getNotificationChannel(FOREGROUND_CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    FOREGROUND_CHANNEL_ID,
                    FOREGROUND_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps Ebakunado daily checks running in the background"
                    setShowBadge(false)
                    enableVibration(false)
                }
                manager.createNotificationChannel(channel)
            }
        }

        val notification = NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setContentTitle("Ebakunado Background Checks")
            .setContentText("Syncing immunization reminders…")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    private fun initializeFlutterEngine() {
        if (flutterEngine != null) {
            return
        }

        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val bundlePath = loader.findAppBundlePath() ?: run {
            stopService()
            return
        }

        val engine = FlutterEngine(applicationContext)
        GeneratedPluginRegistrant.registerWith(engine)

        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "backgroundReady" -> {
                    isReady = true
                    result.success(null)
                    dispatchIfReady()
                }
                "alarmComplete" -> {
                    result.success(null)
                    stopService()
                }
                else -> result.notImplemented()
            }
        }

        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(bundlePath, "alarmBackgroundDispatcher")
        )

        flutterEngine = engine
        backgroundChannel = channel
    }

    private fun dispatchIfReady() {
        val channel = backgroundChannel ?: return
        val args = pendingArguments ?: return
        if (!isReady) {
            return
        }

        try {
            channel.invokeMethod("handleDailyAlarm", args)
            pendingArguments = null
        } catch (e: Exception) {
            Log.e("DailyCheckService", "Failed to dispatch alarm", e)
            stopService()
        }
    }

    private fun stopService() {
        pendingArguments = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }
}
