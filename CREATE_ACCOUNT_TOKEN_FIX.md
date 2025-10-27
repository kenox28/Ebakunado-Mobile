# Create Account Token Fix

## Problem

The app was showing "Invalid token" error when trying to create an account.

## Root Cause

The PHP endpoint (`create_account.php`) expects a special mobile app token: `BYPASS_FOR_MOBILE_APP`, but the Flutter app was trying to generate a CSRF token from a different endpoint (`generate_csrf.php`).

## Solution

### 1. Updated `api_client.dart`

Changed the `createAccount` method to use the hardcoded mobile app token instead of generating a CSRF token:

```dart
// Before (WRONG):
final csrfResponse = await generateCsrfToken();
csrfToken: csrfResponse.csrfToken,

// After (CORRECT):
csrfToken: 'BYPASS_FOR_MOBILE_APP', // Special token for mobile apps
```

### 2. Updated `create_account_screen.dart`

- Removed the `_loadCsrfToken()` method (no longer needed)
- Removed the call to `_loadCsrfToken()` from `initState()`
- Updated `_createAccount()` to pass an empty string for csrfToken (will be set by API client)

## How It Works Now

1. **User fills in the form** and verifies OTP
2. **App creates request** with empty csrfToken
3. **API client** sets `csrfToken: 'BYPASS_FOR_MOBILE_APP'`
4. **API client** sets `mobile_app_request: true`
5. **PHP endpoint** checks for mobile app request
6. **PHP endpoint** validates the special token: `BYPASS_FOR_MOBILE_APP`
7. **Account is created successfully** ✅

## PHP Endpoint Logic

```php
$is_mobile_app = isset($_POST['mobile_app_request']) && $_POST['mobile_app_request'] === 'true';

if ($is_mobile_app) {
    // For mobile app requests, we'll use a special token system
    $expected_mobile_token = 'BYPASS_FOR_MOBILE_APP';

    if (!isset($_POST['csrf_token']) || $_POST['csrf_token'] !== $expected_mobile_token) {
        echo json_encode([
            "status" => "failed",
            "message" => "Invalid mobile app token."
        ]);
        exit();
    }
}
```

## Benefits

- ✅ Mobile apps don't need to manage CSRF tokens
- ✅ Simplified authentication flow
- ✅ Special token identifies mobile app requests
- ✅ Still secure with OTP verification

## Testing

To test the account creation:

1. Fill in personal information
2. Send and verify OTP
3. Select location (Province, City, Barangay, Purok)
4. Enter password (must meet requirements)
5. Agree to terms
6. Click "Create Account"
7. Check terminal logs for:
   ```
   Creating account for: user@example.com
   Creating account with data: {...csrf_token: BYPASS_FOR_MOBILE_APP...}
   Create Account Response: {status: success, message: Successfully created account}
   ```

## Files Changed

- `lib/services/api_client.dart` - Updated createAccount method
- `lib/screens/create_account_screen.dart` - Removed CSRF token loading
- `CREATE_ACCOUNT_TOKEN_FIX.md` - This documentation

## Related Files

- Website: `ebakunado/php/supabase/create_account.php`
- Model: `lib/models/create_account_request.dart`
- Response: `lib/models/create_account_response.dart`
