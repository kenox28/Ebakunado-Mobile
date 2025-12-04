# Network Connection Error Troubleshooting

## Issue: Network Connection Error with https://ebakunado.com

### Possible Causes:

1. **Network Security Config Missing Domain** ✅ FIXED
   - Added `ebakunado.com` to `network_security_config.xml`

2. **SSL Certificate Issues**
   - Invalid/self-signed certificate
   - Certificate not trusted by Android

3. **BaseURL Path Issue**
   - PHP files might be in a subdirectory (e.g., `/ebakunado/`)
   - Current: `https://ebakunado.com`
   - Might need: `https://ebakunado.com/ebakunado`

4. **Server Not Accessible**
   - Firewall blocking
   - Server down
   - DNS issues

5. **CORS Issues**
   - Server not allowing mobile app requests

---

## Solutions Applied:

### ✅ Solution 1: Added Domain to Network Security Config
Updated `android/app/src/main/res/xml/network_security_config.xml` to include:
```xml
<domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">ebakunado.com</domain>
    <trust-anchors>
        <certificates src="system" />
    </trust-anchors>
</domain-config>
```

---

## Next Steps to Try:

### Option 1: Check if PHP files are in subdirectory
If your PHP files are at `https://ebakunado.com/ebakunado/php/...`, update baseURL:
```dart
static const String baseUrl = 'https://ebakunado.com/ebakunado';
```

### Option 2: Test if server is accessible
Try accessing in browser:
- `https://ebakunado.com/php/supabase/login.php`
- Check if it returns a response

### Option 3: Check SSL Certificate
1. Open `https://ebakunado.com` in browser
2. Check if certificate is valid
3. If invalid/self-signed, we may need to add SSL bypass (development only)

### Option 4: Add SSL Certificate Bypass (Development Only)
If certificate is invalid, add to `api_client.dart`:
```dart
import 'package:dio/io.dart';

// In _initializeDio():
(_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host) => true; // DEV ONLY!
  return client;
};
```

⚠️ **WARNING**: Only use SSL bypass for development/testing!

---

## Testing Checklist:

- [ ] Test baseURL in browser
- [ ] Check if PHP files are in subdirectory
- [ ] Verify SSL certificate is valid
- [ ] Test API endpoint directly
- [ ] Check Android logs for specific error
- [ ] Verify internet connection on device
- [ ] Check if firewall is blocking

---

## Common Error Messages:

- **"Network connection error"** → Server not reachable or SSL issue
- **"SSL handshake failed"** → Certificate issue
- **"404 Not Found"** → Wrong baseURL path
- **"Connection timeout"** → Server not responding or firewall

