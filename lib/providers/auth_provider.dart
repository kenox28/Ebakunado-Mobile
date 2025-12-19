import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../models/login_response.dart';
import '../models/user.dart';
import '../models/google_sign_in_response.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _userType;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  // Google Sign-In instance
  // serverClientId should be the WEB client ID (for backend token verification)
  // The Android client ID is automatically detected based on SHA-1 + package name
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AppConstants.googleWebClientId,
  );

  // Store Google credential for completing profile (new users)
  String? _pendingGoogleCredential;
  GoogleSignInAccount? _pendingGoogleAccount;

  // JWT Token storage
  String? _jwtToken;

  User? get user => _user;
  String? get userType => _userType;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // Google Sign-In getters
  String? get pendingGoogleCredential => _pendingGoogleCredential;
  GoogleSignInAccount? get pendingGoogleAccount => _pendingGoogleAccount;
  String? get jwtToken => _jwtToken;

  Future<bool> login(
    String emailOrPhone,
    String password, {
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      _setLoading(true);
    }

    try {
      final response = await ApiClient.instance.login(emailOrPhone, password);

      // Parse JSON string if needed
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final loginResponse = LoginResponse.fromJson(responseData);

      if (loginResponse.isSuccess) {
        _user = loginResponse.user;
        _userType = loginResponse.userType;
        _isLoggedIn = true;
        notifyListeners();
        return true;
      } else {
        throw Exception(loginResponse.message);
      }
    } on DioException catch (e) {
      debugPrint('🔴 AuthProvider: DioException caught');
      debugPrint('🔴 Error Type: ${e.type}');
      debugPrint('🔴 Error Message: ${e.message}');
      debugPrint('🔴 Has Response: ${e.response != null}');

      if (e.response?.data != null &&
          e.response?.data is Map<String, dynamic>) {
        final errorData = e.response!.data as Map<String, dynamic>;
        debugPrint('🔴 Server Error Response: $errorData');
        throw Exception(errorData['message'] ?? 'Login failed');
      } else {
        // Provide more specific error messages based on error type
        String errorMessage = 'Network error. Please check your connection.';
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage =
              'Connection timeout. The server took too long to respond.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Receive timeout. The server did not respond in time.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage =
              'Connection error. Cannot reach the server. Please check your internet connection.';
        } else if (e.type == DioExceptionType.unknown) {
          errorMessage =
              'Unknown network error: ${e.message ?? "Please check your connection"}';
        }
        debugPrint('🔴 Throwing error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('🔴 AuthProvider: General exception caught: $e');
      debugPrint('🔴 Exception Type: ${e.runtimeType}');
      if (e is AuthExpiredException) {
        await logout();
      }
      rethrow;
    } finally {
      if (showGlobalLoading) {
        _setLoading(false);
      }
    }
  }

  // ============================================
  // Google Sign-In Methods
  // ============================================

  /// Initiate Google Sign-In and get ID token
  /// Returns the GoogleSignInAccount if successful, null otherwise
  Future<GoogleSignInAccount?> initiateGoogleSignIn() async {
    try {
      debugPrint('🔵 Initiating Google Sign-In...');

      // Sign out first to ensure fresh login
      await _googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('🔴 Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('🔵 Google Sign-In successful: ${account.email}');
      return account;
    } catch (e) {
      debugPrint('🔴 Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Get the ID token from a GoogleSignInAccount
  Future<String?> getGoogleIdToken(GoogleSignInAccount account) async {
    try {
      final GoogleSignInAuthentication auth = await account.authentication;
      debugPrint(
        '🔵 Got Google ID Token: ${auth.idToken?.substring(0, 50)}...',
      );
      return auth.idToken;
    } catch (e) {
      debugPrint('🔴 Error getting Google ID token: $e');
      return null;
    }
  }

  /// Google Login - For existing users
  /// Returns GoogleSignInResponse with status:
  /// - 'success': User logged in successfully
  /// - 'not_found': User doesn't exist (needs to sign up)
  /// - 'error': Error occurred
  Future<GoogleSignInResponse> googleLogin({
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      _setLoading(true);
    }

    try {
      // Step 1: Initiate Google Sign-In
      final account = await initiateGoogleSignIn();
      if (account == null) {
        return GoogleSignInResponse(
          status: 'error',
          message: 'Google Sign-In was cancelled',
        );
      }

      // Step 2: Get ID token
      final idToken = await getGoogleIdToken(account);
      if (idToken == null) {
        return GoogleSignInResponse(
          status: 'error',
          message: 'Failed to get Google authentication token',
        );
      }

      // Step 3: Send to backend
      final response = await ApiClient.instance.googleLogin(idToken);

      // Step 4: Handle response
      if (response.isAuthenticated && response.user != null) {
        // Store JWT token
        _jwtToken = response.token;
        await _saveJwtToken(response.token);

        // Convert GoogleUser to User for compatibility
        _user = User(
          fname: response.user!.fname,
          lname: response.user!.lname,
          email: response.user!.email,
          profileImg: response.user!.profileImg,
        );
        _userType = 'user';
        _isLoggedIn = true;
        notifyListeners();
      }

      return response;
    } on DioException catch (e) {
      debugPrint('🔴 Google Login DioException: ${e.message}');
      return GoogleSignInResponse(
        status: 'error',
        message: _extractErrorMessage(e),
      );
    } catch (e) {
      debugPrint('🔴 Google Login error: $e');
      return GoogleSignInResponse(
        status: 'error',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (showGlobalLoading) {
        _setLoading(false);
      }
    }
  }

  /// Google Sign-Up - Step 1: Get Google account and store for profile completion
  /// Returns the GoogleSignInAccount if successful
  Future<GoogleSignInAccount?> googleSignUpStep1({
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      _setLoading(true);
    }

    try {
      // Step 1: Initiate Google Sign-In
      final account = await initiateGoogleSignIn();
      if (account == null) {
        return null;
      }

      // Step 2: Get ID token
      final idToken = await getGoogleIdToken(account);
      if (idToken == null) {
        throw Exception('Failed to get Google authentication token');
      }

      // Store for later use
      _pendingGoogleCredential = idToken;
      _pendingGoogleAccount = account;
      notifyListeners();

      return account;
    } catch (e) {
      debugPrint('🔴 Google Sign-Up Step 1 error: $e');
      rethrow;
    } finally {
      if (showGlobalLoading) {
        _setLoading(false);
      }
    }
  }

  /// Google Sign-Up - Step 2: Complete profile and create account
  /// Call this after user fills in additional profile info
  Future<GoogleSignInResponse> googleSignUpComplete(
    GoogleSignUpRequest request, {
    bool showGlobalLoading = true,
  }) async {
    if (showGlobalLoading) {
      _setLoading(true);
    }

    try {
      // Send to backend
      final response = await ApiClient.instance.googleSignUp(request);

      // Handle response
      if (response.isAuthenticated && response.user != null) {
        // Store JWT token
        _jwtToken = response.token;
        await _saveJwtToken(response.token);

        // Convert GoogleUser to User for compatibility
        _user = User(
          fname: response.user!.fname,
          lname: response.user!.lname,
          email: response.user!.email,
          profileImg: response.user!.profileImg,
        );
        _userType = 'user';
        _isLoggedIn = true;

        // Clear pending data
        clearPendingGoogleData();
        notifyListeners();
      }

      return response;
    } on DioException catch (e) {
      debugPrint('🔴 Google Sign-Up Complete DioException: ${e.message}');
      return GoogleSignInResponse(
        status: 'error',
        message: _extractErrorMessage(e),
      );
    } catch (e) {
      debugPrint('🔴 Google Sign-Up Complete error: $e');
      return GoogleSignInResponse(
        status: 'error',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (showGlobalLoading) {
        _setLoading(false);
      }
    }
  }

  /// Clear pending Google Sign-Up data
  void clearPendingGoogleData() {
    _pendingGoogleCredential = null;
    _pendingGoogleAccount = null;
    notifyListeners();
  }

  /// Sign out from Google
  Future<void> googleSignOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign out error: $e');
    }
  }

  // JWT Token storage helpers
  Future<void> _saveJwtToken(String? token) async {
    if (token == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
    } catch (e) {
      debugPrint('Error saving JWT token: $e');
    }
  }

  Future<String?> _loadJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('jwt_token');
    } catch (e) {
      debugPrint('Error loading JWT token: $e');
      return null;
    }
  }

  Future<void> _clearJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
    } catch (e) {
      debugPrint('Error clearing JWT token: $e');
    }
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null && e.response?.data is Map<String, dynamic>) {
      final errorData = e.response!.data as Map<String, dynamic>;
      return errorData['message'] ?? 'An error occurred';
    }

    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Connection error. Please check your internet.';
    }

    return 'Network error. Please try again.';
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.logout();
    } catch (e) {
      // Continue with logout even if API call fails
      debugPrint('Logout API call failed: $e');
    }

    // Sign out from Google
    await googleSignOut();

    // Clear JWT token
    await _clearJwtToken();
    _jwtToken = null;

    // Cancel daily notifications on logout
    await NotificationService.cancelAllNotifications();

    // Clear local state and cookies
    await ApiClient.instance.clearCookies();
    _user = null;
    _userType = null;
    _isLoggedIn = false;
    clearPendingGoogleData();
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    // This would typically check for stored session/token
    // For now, we'll rely on the API session cookies
    _setLoading(true);

    try {
      // Try to fetch user data to verify session
      final response = await ApiClient.instance.getDashboardSummary();

      if (response.statusCode == 200 && response.data != null) {
        // Parse JSON string if needed
        Map<String, dynamic> data;
        if (response.data is String) {
          data = json.decode(response.data);
        } else {
          data = response.data;
        }

        // Check if response indicates user is logged in
        if (data['status'] == 'success') {
          _isLoggedIn = true;
        } else {
          _isLoggedIn = false;
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      _isLoggedIn = false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setGlobalLoading(bool loading) {
    _setLoading(loading);
  }
}
