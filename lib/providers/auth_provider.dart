import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../models/login_response.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _userType;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  User? get user => _user;
  String? get userType => _userType;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  Future<bool> login(String emailOrPhone, String password) async {
    _setLoading(true);

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
      if (e.response?.data != null &&
          e.response?.data is Map<String, dynamic>) {
        final errorData = e.response!.data as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Login failed');
      } else {
        throw Exception('Network error. Please check your connection.');
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        await logout();
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.logout();
    } catch (e) {
      // Continue with logout even if API call fails
      debugPrint('Logout API call failed: $e');
    }

    // Cancel daily notifications on logout
    await NotificationService.cancelAllNotifications();

    // Clear local state and cookies
    await ApiClient.instance.clearCookies();
    _user = null;
    _userType = null;
    _isLoggedIn = false;
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
}
