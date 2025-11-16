import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _testResult = 'Not tested yet';
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing connection...';
    });

    try {
      final dio = Dio();

      // Test basic connectivity to your server
      print('🧪 Testing connection to: ${AppConstants.baseUrl}');

      final response = await dio.get(
        '${AppConstants.baseUrl}/php/supabase/login.php',
        options: Options(
          validateStatus: (status) => true, // Accept any status code
        ),
      );

      setState(() {
        _testResult =
            '''
✅ Connection Test Results:
Status Code: ${response.statusCode}
Response Headers: ${response.headers}
Response Data: ${response.data}
''';
      });
    } catch (e) {
      setState(() {
        _testResult =
            '''
❌ Connection Test Failed:
Error: $e
Error Type: ${e.runtimeType}
''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLoginEndpoint() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing login endpoint...';
    });

    try {
      final dio = Dio();

      // Test login endpoint with dummy data (should fail but show structure)
      final formData = FormData.fromMap({
        'Email_number': 'test@example.com',
        'password': 'testpassword',
      });

      print(
        '🧪 Testing login endpoint: ${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
      );

      final response = await dio.post(
        '${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => true, // Accept any status code
        ),
      );

      setState(() {
        _testResult =
            '''
✅ Login Endpoint Test Results:
Status Code: ${response.statusCode}
Response Headers: ${response.headers}
Response Data: ${response.data}

📝 Note: This should return "Invalid email/phone or password" 
since we're using dummy credentials. If you see this message,
the endpoint is working correctly!
''';
      });
    } catch (e) {
      setState(() {
        _testResult =
            '''
❌ Login Endpoint Test Failed:
Error: $e
Error Type: ${e.runtimeType}

🔧 Possible issues:
- Server not running on ${AppConstants.baseUrl}
- CORS not configured for mobile app
- Network connectivity issues
- Firewall blocking the connection
''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRealLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter both email/phone and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = 'Testing real login...';
    });

    try {
      final dio = Dio();

      final formData = FormData.fromMap({
        'Email_number': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      print(
        '🧪 Testing real login: ${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
      );

      final response = await dio.post(
        '${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          validateStatus: (status) => true,
        ),
      );

      setState(() {
        _testResult =
            '''
🔐 Real Login Test Results:
Status Code: ${response.statusCode}
Response Data: ${response.data}

${response.data is Map && response.data['status'] == 'success'
                ? '✅ LOGIN SUCCESSFUL!'
                : response.data is Map && response.data['status'] == 'already_logged_in'
                ? '✅ ALREADY LOGGED IN!'
                : '❌ Login failed - check credentials'}
''';
      });
    } catch (e) {
      setState(() {
        _testResult =
            '''
❌ Real Login Test Failed:
Error: $e
Error Type: ${e.runtimeType}
''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLogout() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing logout...';
    });

    try {
      final dio = Dio();

      print(
        '🧪 Testing logout: ${AppConstants.baseUrl}${AppConstants.logoutEndpoint}',
      );

      final response = await dio.post(
        '${AppConstants.baseUrl}${AppConstants.logoutEndpoint}',
        options: Options(validateStatus: (status) => true),
      );

      setState(() {
        _testResult =
            '''
🚪 Logout Test Results:
Status Code: ${response.statusCode}
Response Data: ${response.data}

${response.data is Map && response.data['status'] == 'success' ? '✅ LOGOUT SUCCESSFUL!' : '❌ Logout failed or no session to clear'}
''';
      });
    } catch (e) {
      setState(() {
        _testResult =
            '''
❌ Logout Test Failed:
Error: $e
Error Type: ${e.runtimeType}
''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testAppLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _testResult = '❌ Please enter both email/phone and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = 'Testing app login flow...';
    });

    try {
      // Import the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      setState(() {
        _testResult =
            '''
🔐 App Login Flow Test Results:
Success: $success
Auth Provider State:
- Is Logged In: ${authProvider.isLoggedIn}
- User Type: ${authProvider.userType}
- User: ${authProvider.user?.fullName}

${success ? '✅ APP LOGIN SUCCESSFUL!' : '❌ App login failed - check console logs for details'}
''';
      });
    } catch (e) {
      setState(() {
        _testResult =
            '''
❌ App Login Flow Test Failed:
Error: $e
Error Type: ${e.runtimeType}

Check the console logs for detailed debugging information.
''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug API Connection'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'API Base URL: ${AppConstants.baseUrl}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: const Text('Test Basic Connection'),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _isLoading ? null : _testLoginEndpoint,
              child: const Text('Test Login Endpoint (Dummy)'),
            ),
            const SizedBox(height: 16),

            // Real credentials test
            const Text(
              'Test with Real Credentials:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email or Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testRealLogin,
              child: const Text('Test Real Login'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLogout,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Test Logout'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testAppLogin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Test App Login Flow'),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _testResult,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
