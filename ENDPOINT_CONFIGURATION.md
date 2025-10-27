# Endpoint Configuration

## Overview

All API endpoints now point to the website server instead of local PHP files. This ensures that when admin changes credentials (like TextBee API keys), the mobile app automatically uses the updated credentials without requiring an app rebuild.

## Base URL

```
http://192.168.43.73/ebakunado
```

## Create Account Endpoints

All these endpoints are now hosted on your website:

1. **Send OTP**: `/php/supabase/send_otp.php`

   - Website file: `ebakunado/php/supabase/send_otp.php`
   - Handles OTP generation and SMS sending via TextBee
   - Uses session storage for OTP verification

2. **Verify OTP**: `/php/supabase/verify_otp.php`

   - Website file: `ebakunado/php/supabase/verify_otp.php`
   - Validates OTP against session data

3. **Get Places**: `/php/supabase/admin/get_places.php`

   - Website file: `ebakunado/php/supabase/admin/get_places.php`
   - Returns cascading location data (provinces, cities, barangays, puroks)

4. **Create Account**: `/php/supabase/create_account.php`

   - Website file: `ebakunado/php/supabase/create_account.php`
   - Handles user registration with validation

5. **Generate CSRF**: `/php/supabase/generate_csrf.php`
   - Website file: `ebakunado/php/supabase/generate_csrf.php`
   - Provides CSRF token for security

## Benefits of Website Endpoints

✅ **Centralized Management**: Admin can update TextBee credentials on the website
✅ **No App Updates Required**: Changes to API keys don't require app rebuild
✅ **Single Source of Truth**: One codebase for all credential management
✅ **Easier Maintenance**: Update endpoints in one place

## Removed Files

The following local PHP files were removed as they're now hosted on the website:

- `php/supabase/send_otp.php`
- `php/supabase/verify_otp.php`
- `php/supabase/create_account.php`
- `php/supabase/generate_csrf.php`
- `php/supabase/admin/get_places.php`

## Testing

To test the endpoints:

1. Ensure your website at `http://192.168.43.73/ebakunado` is running
2. Run the Flutter app: `flutter run`
3. Navigate to Create Account screen
4. Fill in personal information
5. Click "Send OTP"
6. Check your phone for the SMS
7. Enter OTP in the modal
8. Complete the remaining steps

## Updating Base URL

If your website IP changes, update the `baseUrl` in:

```
ebakunado_mobile/lib/utils/constants.dart
```

Change line 4-5:

```dart
static const String baseUrl =
    'http://YOUR_NEW_IP/ebakunado';
```

## Website Endpoint Requirements

Your website endpoints must:

- Accept `multipart/form-data` POST requests
- Return JSON responses with `status` and `message` fields
- Use PHP sessions for OTP verification
- Handle CORS headers if needed
