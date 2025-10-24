<?php
/**
 * Daily Notifications API Endpoint
 *
 * This endpoint provides daily immunization notifications as an alternative to direct Supabase queries.
 * It handles the same logic as the cron job but through the Flutter app.
 *
 * Returns:
 * - Today immunizations
 * - Tomorrow immunizations
 * - Missed immunizations
 * - Checks notification_logs to prevent duplicates
 *
 * GET /php/supabase/users/get_daily_notifications.php
 *
 * Response format:
 * {
 *   "status": "success",
 *   "data": {
 *     "today": [...],
 *     "tomorrow": [...],
 *     "missed": [...]
 *   }
 * }
 */

// Set timezone
date_default_timezone_set('Asia/Manila');

// Set error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Include required files
require_once __DIR__ . '/../../../database/SupabaseConfig.php';
require_once __DIR__ . '/../../../database/DatabaseHelper.php';

// Start session for authentication
session_start();

// Debug session information
error_log('=== Daily Notifications Debug ===');
error_log('Session ID: ' . session_id());
error_log('Session user_id: ' . (isset($_SESSION['user_id']) ? $_SESSION['user_id'] : 'NOT SET'));
error_log('All session vars: ' . json_encode($_SESSION));
error_log('Cookies: ' . json_encode($_COOKIE));

// Check if user is logged in
if (!isset($_SESSION['user_id']) || empty($_SESSION['user_id'])) {
    error_log('Authentication failed - no user_id in session');
    error_log('Session variables: ' . json_encode($_SESSION));
    error_log('Request headers: ' . json_encode(getallheaders()));
    error_log('Cookies: ' . json_encode($_COOKIE));

    // Check if this is a test request (for debugging)
    $isTestRequest = isset($_GET['test']) && $_GET['test'] === '1';

    if ($isTestRequest) {
        echo json_encode([
            'status' => 'success',
            'message' => 'API endpoint is accessible (test mode)',
            'test_mode' => true,
            'debug' => [
                'session_id' => session_id(),
                'session_vars' => $_SESSION,
                'cookies' => $_COOKIE,
                'headers' => getallheaders(),
                'note' => 'This is test mode - authentication not required'
            ]
        ]);
        exit;
    }

    echo json_encode([
        'status' => 'error',
        'message' => 'User not authenticated',
        'debug' => [
            'session_id' => session_id(),
            'session_vars' => $_SESSION,
            'cookies' => $_COOKIE,
            'headers' => getallheaders(),
            'server_info' => [
                'PHP_SESSION_COOKIE_NAME' => ini_get('session.name'),
                'PHP_SESSION_SAVE_PATH' => ini_get('session.save_path'),
                'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD'] ?? 'unknown',
                'HTTP_USER_AGENT' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
            ]
        ]
    ]);
    exit;
}

$currentUserId = $_SESSION['user_id'];

try {
    $today = date('Y-m-d');
    $tomorrow = date('Y-m-d', strtotime('+1 day'));

    $notifications = [
        'today' => [],
        'tomorrow' => []
    ];

    // Helper function to check if notification already sent
    function isNotificationAlreadySent($babyId, $type, $date) {
        global $currentUserId;
        $exists = supabaseSelect(
            'notification_logs',
            'id',
            [
                'baby_id' => $babyId,
                'user_id' => $currentUserId,
                'type' => $type,
                'notification_date' => $date
            ],
            null,
            1
        );
        return count($exists) > 0;
    }

    // Helper function to get child info
    function getChildInfo($babyId) {
        return supabaseSelect(
            'child_health_records',
            'baby_id,child_fname,child_lname',
            ['baby_id' => $babyId],
            null,
            1
        );
    }

    // Check for TODAY's immunizations
    $todaySchedules = supabaseSelect(
        'immunization_records',
        'id,baby_id,vaccine_name,dose_number,schedule_date',
        [
            'schedule_date' => $today,
            'status' => 'scheduled'
        ],
        'schedule_date.asc'
    );

    foreach ($todaySchedules as $schedule) {
        $childInfo = getChildInfo($schedule['baby_id']);
        if (count($childInfo) > 0) {
            $child = $childInfo[0];
            $childName = $child['child_fname'] . ' ' . $child['child_lname'];

            if (!isNotificationAlreadySent($schedule['baby_id'], 'schedule_same_day', $today)) {
                $notifications['today'][] = [
                    'baby_id' => $schedule['baby_id'],
                    'child_name' => $childName,
                    'vaccine_name' => $schedule['vaccine_name'],
                    'dose_number' => $schedule['dose_number'],
                    'schedule_date' => $schedule['schedule_date'],
                    'message' => "$childName has {$schedule['vaccine_name']} scheduled today",
                    'type' => 'today'
                ];
            }
        }
    }

    // Check for TOMORROW's immunizations
    $tomorrowSchedules = supabaseSelect(
        'immunization_records',
        'id,baby_id,vaccine_name,dose_number,schedule_date',
        [
            'schedule_date' => $tomorrow,
            'status' => 'scheduled'
        ],
        'schedule_date.asc'
    );

    foreach ($tomorrowSchedules as $schedule) {
        $childInfo = getChildInfo($schedule['baby_id']);
        if (count($childInfo) > 0) {
            $child = $childInfo[0];
            $childName = $child['child_fname'] . ' ' . $child['child_lname'];

            if (!isNotificationAlreadySent($schedule['baby_id'], 'schedule_reminder', $today)) {
                $notifications['tomorrow'][] = [
                    'baby_id' => $schedule['baby_id'],
                    'child_name' => $childName,
                    'vaccine_name' => $schedule['vaccine_name'],
                    'dose_number' => $schedule['dose_number'],
                    'schedule_date' => $schedule['schedule_date'],
                    'message' => "$childName has {$schedule['vaccine_name']} scheduled tomorrow",
                    'type' => 'tomorrow'
                ];
            }
        }
    }


    echo json_encode([
        'status' => 'success',
        'message' => 'Daily notifications retrieved successfully',
        'data' => $notifications,
        'user_id' => $currentUserId,
        'today_date' => $today,
        'tomorrow_date' => $tomorrow
    ]);

} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'user_id' => $currentUserId ?? null
    ]);
}
?>
