# Push Notification System Architecture

## 📚 Libraries Used

### Flutter/Dart Packages:

1. **`flutter_local_notifications: ^19.0.0`** - Main notification library

   - Handles local notifications (scheduled and immediate)
   - Platform-specific implementations for Android and iOS
   - Supports scheduled notifications with timezone support

2. **`timezone: ^0.10.1`** - Timezone handling

   - Manages timezone-aware scheduling
   - Converts device timezone to proper scheduling times

3. **`shared_preferences: ^2.2.2`** - Local storage

   - Stores notification preferences
   - Caches notification data
   - Stores last notification check times

4. **`permission_handler: ^11.3.1`** - Permission management

   - Requests notification permissions
   - Checks if notifications are enabled

5. **`app_settings: ^5.1.1`** - App settings access

   - Opens system notification settings
   - Opens exact alarm settings (Android 12+)

6. **`supabase_flutter: ^2.0.0`** - Backend integration
   - Fetches notification data from Supabase
   - Real-time updates (if configured)

### Native Android Components:

1. **`NotificationAlarmReceiver.kt`** - BroadcastReceiver

   - Handles alarm triggers from Android AlarmManager
   - Shows notifications when alarms fire
   - Re-schedules alarms after device reboot

2. **`DailyCheckService.kt`** - Foreground Service

   - Runs Flutter code in background
   - Executes daily notification checks
   - Communicates with Flutter via MethodChannel

3. **`MainActivity.kt`** - Native integration
   - MethodChannel handlers for alarm scheduling
   - Timezone retrieval
   - Exact alarm permission requests

---

## 🏗️ Architecture Overview

### Type: **Local Notifications (NOT Push Notifications)**

Your app uses **LOCAL notifications**, not push notifications (FCM/APNS). This means:

- ✅ Notifications are scheduled locally on the device
- ✅ No external push notification service needed
- ✅ Works offline (after initial data fetch)
- ❌ Cannot send notifications from server without app running
- ❌ No real-time push from backend

---

## 🔄 How It Works

### 1. **Initialization Flow**

```
main.dart
  ↓
1. Initialize timezone (tz.initializeTimeZones())
2. Initialize NotificationService
   - Request permissions
   - Create notification channel
   - Schedule visibility alarm
3. Schedule daily notification check
```

**Key Files:**

- `lib/main.dart` - App entry point
- `lib/services/notification_service.dart` - Main service

### 2. **Daily Notification Check System**

#### **Two Daily Check Times:**

- **Morning:** 8:00 AM
- **Evening:** 11:59 PM

#### **How Daily Checks Work:**

```
Android AlarmManager (Native)
  ↓ (Triggers at scheduled time)
NotificationAlarmReceiver.kt
  ↓ (Starts foreground service)
DailyCheckService.kt
  ↓ (Launches Flutter engine)
alarmBackgroundDispatcher() (Flutter)
  ↓ (Calls NotificationService)
handleDailyAlarmInBackground()
  ↓ (Fetches data from API)
get_daily_notifications.php (Backend)
  ↓ (Returns notification data)
Schedule individual notifications
```

**Key Files:**

- `android/.../NotificationAlarmReceiver.kt` - Alarm receiver
- `android/.../DailyCheckService.kt` - Background service
- `lib/services/notification_service.dart` - Flutter handler

### 3. **Notification Scheduling**

#### **Types of Notifications:**

1. **Scheduled Notifications** (Individual)

   - Scheduled for specific dates/times
   - Uses `flutter_local_notifications.zonedSchedule()`
   - Example: "BCG vaccine due tomorrow"

2. **Daily Check Notifications** (Batch)

   - Triggered by daily alarm
   - Fetches fresh data from backend
   - Schedules multiple notifications at once

3. **Immediate Notifications**
   - Shown immediately
   - Uses `flutter_local_notifications.show()`
   - Example: "Account created successfully"

#### **Scheduling Process:**

```dart
// Schedule a notification
NotificationService.scheduleNotification(
  id: uniqueId,
  title: "Vaccine Due",
  body: "BCG vaccine is due tomorrow",
  scheduledDate: DateTime(2025, 12, 10, 8, 0),
  payload: "immunization_tomorrow_baby123",
);
```

**Implementation:**

- Uses `tz.TZDateTime` for timezone-aware scheduling
- Android: `AndroidScheduleMode.exactAllowWhileIdle` for reliability
- iOS: Uses Darwin notification settings

### 4. **Native Android Integration**

#### **Method Channels:**

1. **`com.ebakunado/alarms`** - Alarm scheduling

   - `scheduleNativeAlarm` - Schedule alarm
   - `scheduleDailyCheckAlarms` - Schedule daily checks
   - `cancelNativeNotification` - Cancel alarm
   - `getDeviceTimeZone` - Get device timezone
   - `requestScheduleExactAlarms` - Request exact alarm permission

2. **`com.ebakunado/alarm_background`** - Background communication
   - `backgroundReady` - Service ready signal
   - `handleDailyAlarm` - Trigger daily check
   - `alarmComplete` - Service completion signal

#### **Android Components:**

1. **AlarmManager** - System alarm scheduling

   - `setExactAndAllowWhileIdle()` - Exact alarms (Android 6+)
   - `setAlarmClock()` - Alarm clock (Android 5+)
   - Survives device reboot (re-scheduled via BOOT_COMPLETED)

2. **Foreground Service** - Background execution

   - `DailyCheckService` runs as foreground service
   - Required for background Flutter execution
   - Shows invisible notification to keep service alive

3. **BroadcastReceiver** - Alarm handling
   - `NotificationAlarmReceiver` receives alarm broadcasts
   - Handles BOOT_COMPLETED to re-schedule alarms
   - Triggers foreground service for daily checks

---

## 📱 Notification Features

### **Notification Channel:**

- **ID:** `immunization_channel`
- **Name:** "Immunization Notifications"
- **Importance:** MAX (for expandable notifications)
- **Features:** Sound, Vibration, Badge

### **Notification Types:**

1. **BigTextStyle** - Expandable notifications

   - Shows full message when expanded
   - Android-specific feature

2. **Scheduled Notifications**

   - Timezone-aware
   - Survives app closure
   - Re-scheduled after reboot

3. **Interactive Notifications**
   - Tap to open app
   - Payload for navigation
   - Auto-cancel after tap

---

## 🔐 Permissions & Settings

### **Android Permissions:**

1. **Notification Permission** (Android 13+)

   - Requested via `requestNotificationsPermission()`
   - Checked via `areNotificationsEnabled()`

2. **Exact Alarm Permission** (Android 12+)

   - Required for precise scheduling
   - Requested via `requestExactAlarmPermission()`
   - Opens system settings

3. **Battery Optimization**
   - User must disable battery optimization
   - Required for reliable alarms

### **iOS Permissions:**

1. **Alert Permission**

   - Requested during initialization
   - `requestAlertPermission: true`

2. **Badge Permission**

   - `requestBadgePermission: true`

3. **Sound Permission**
   - `requestSoundPermission: true`

---

## 🔄 Data Flow

### **Daily Notification Check:**

```
1. Alarm fires (8:00 AM or 11:59 PM)
   ↓
2. NotificationAlarmReceiver receives broadcast
   ↓
3. Starts DailyCheckService (foreground service)
   ↓
4. Service launches Flutter engine
   ↓
5. Flutter calls handleDailyAlarmInBackground()
   ↓
6. Fetches data from: get_daily_notifications.php
   ↓
7. Processes notification data
   ↓
8. Schedules individual notifications
   ↓
9. Service stops
```

### **Backend Integration:**

**Endpoint:** `php/supabase/users/get_daily_notifications.php`

**Returns:**

- Upcoming vaccines
- Due dates
- Child information
- Notification messages

**Caching:**

- Uses `SharedPreferences` to cache data
- Reduces API calls
- Works offline after initial fetch

---

## 🛠️ Key Methods

### **NotificationService Methods:**

1. **`initialize()`** - Initialize notification service
2. **`scheduleDailyNotificationCheck()`** - Schedule daily alarms
3. **`scheduleNotification()`** - Schedule individual notification
4. **`showNotification()`** - Show immediate notification
5. **`cancelNotification()`** - Cancel specific notification
6. **`cancelAllNotifications()`** - Cancel all notifications
7. **`handleDailyAlarmInBackground()`** - Process daily check

### **NotificationProvider Methods:**

1. **`loadNotifications()`** - Load notifications from API
2. **`markAsRead()`** - Mark notification as read
3. **`markAllAsRead()`** - Mark all as read

---

## 📊 Notification Data Model

### **NotificationItem:**

```dart
{
  id: String,
  type: String, // 'immunization', 'approval', etc.
  priority: String, // 'high', 'medium', 'low'
  title: String,
  message: String,
  actionUrl: String?,
  timestamp: DateTime,
  unread: bool,
  icon: String?,
  babyId: String?,
}
```

### **DailyNotificationsResponse:**

```dart
{
  status: 'success',
  notifications: [
    {
      baby_id: String,
      baby_name: String,
      vaccine_name: String,
      due_date: String,
      days_until: int,
      message: String,
    }
  ]
}
```

---

## ⚙️ Configuration

### **Notification Channel Settings:**

- **Importance:** MAX
- **Priority:** MAX
- **Sound:** Enabled
- **Vibration:** Enabled
- **Badge:** Enabled

### **Scheduling Settings:**

- **Mode:** `AndroidScheduleMode.exactAllowWhileIdle`
- **Timezone:** Device local timezone
- **Re-schedule:** After device reboot

---

## 🐛 Troubleshooting

### **Common Issues:**

1. **Notifications not showing:**

   - Check notification permissions
   - Check battery optimization settings
   - Verify exact alarm permission (Android 12+)

2. **Daily checks not running:**

   - Verify alarms are scheduled
   - Check device reboot handling
   - Ensure foreground service is running

3. **Timezone issues:**
   - Verify timezone initialization
   - Check device timezone settings
   - Ensure timezone data is loaded

---

## 📝 Notes

- **WorkManager is disabled** - Using native Android alarms instead
- **No FCM/APNS** - Pure local notifications
- **Offline support** - Uses cached data when offline
- **Background execution** - Uses foreground service for reliability
- **Reboot handling** - Alarms re-scheduled after device reboot

---

## 🔗 Related Files

- `lib/services/notification_service.dart` - Main service
- `lib/providers/notification_provider.dart` - State management
- `lib/models/notification.dart` - Data models
- `lib/models/daily_notifications.dart` - Daily notification models
- `android/.../NotificationAlarmReceiver.kt` - Alarm receiver
- `android/.../DailyCheckService.kt` - Background service
- `android/.../MainActivity.kt` - Native integration

---

**Last Updated:** Based on codebase scan
