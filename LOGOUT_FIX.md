# Logout Issue Fix

## Problem

New users cannot logout properly, but old users with child records can logout. This is because:

1. The PHP `logout.php` tries to access `$_SESSION['user_id']` on line 33 **BEFORE** checking if it exists
2. For new users without session data, this causes undefined variable errors
3. The logout flow fails silently for new users

## Root Cause

**In your `logout.php` line 33:**

```php
$user_id = $_SESSION['user_id'];  // ❌ ERROR: May not exist for new users!
```

This happens BEFORE any session validation, so for new users:

- `$_SESSION['user_id']` is undefined
- PHP generates a warning
- The logout might not complete properly

## Solution

Replace your `logout.php` with this corrected version:

```php
<?php
// Start output buffering to prevent any output before JSON
ob_start();

// Set JSON header first
header('Content-Type: application/json');

session_start();

// Get user_id SAFELY with null check
$user_id = $_SESSION['user_id'] ?? null;  // ✅ FIXED: Use null coalescing operator
$db_connected = false;

// Try to include database - but don't fail if it doesn't work
try {
    include "../../../database/Database.php";
    $db_connected = isset($connect) && !$connect->connect_error;
} catch (Exception $e) {
    error_log("Database connection error during logout: " . $e->getMessage());
}

// Log the logout activity ONLY if user_id exists and DB is connected
if ($user_id && $db_connected) {
    try {
        $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';

        $log_sql = "INSERT INTO activity_logs (user_id, user_type, action_type, description, ip_address, created_at) VALUES (?, ?, 'logout', ?, ?, NOW())";
        $log_stmt = $connect->prepare($log_sql);

        if ($log_stmt) {
            $description = "User logged out successfully";
            $user_type = 'user'; // Default user type
            $log_stmt->bind_param("ssss", $user_id, $user_type, $description, $ip);
            $log_stmt->execute();
            $log_stmt->close();
            error_log("User logout logged successfully for ID: " . $user_id);
        } else {
            error_log("Failed to prepare logout log statement: " . $connect->error);
        }
    } catch (Exception $log_error) {
        error_log("Logout logging error: " . $log_error->getMessage());
        // Continue with logout even if logging fails
    }
}

// Clear and destroy the session
session_unset();
session_destroy();

// Clear output buffer and return success response
ob_clean();
echo json_encode([
    "status" => "success",
    "message" => "User logged out successfully",
    "debug" => [
        "db_connected" => $db_connected,
        "had_session" => ($user_id !== null)
    ]
]);
?>
```

## Key Changes

### 1. **Safe Session Access (Line 10)**

```php
// BEFORE (WRONG):
$user_id = $_SESSION['user_id'];  // ❌ Undefined for new users

// AFTER (CORRECT):
$user_id = $_SESSION['user_id'] ?? null;  // ✅ Returns null if not set
```

### 2. **Conditional Logging (Line 22)**

```php
// BEFORE (WRONG):
try {
    $user_id = $_SESSION['user_id'];  // ❌ Too late, error already happened
    // ... logging code
}

// AFTER (CORRECT):
if ($user_id && $db_connected) {  // ✅ Only log if user_id exists
    try {
        // ... logging code
    }
}
```

### 3. **Always Destroy Session (Line 45)**

```php
// Always clear session, regardless of user_id
session_unset();
session_destroy();  // ✅ Works for both new and old users
```

## Why This Fixes the Issue

**For New Users:**

- `$user_id` safely defaults to `null`
- Logging is skipped (no error)
- Session is still cleared properly ✅

**For Old Users:**

- `$user_id` has a value
- Logging works as before
- Session is cleared properly ✅

## Testing

1. **Create a new account**
2. **Login immediately**
3. **Try to logout** - Should work now!

4. **Login with an old account**
5. **Try to logout** - Should still work!

## Implementation

1. **Backup your current `logout.php`**
2. **Replace with the corrected version above**
3. **Test with both new and old users**

The issue should be completely resolved! ✅
