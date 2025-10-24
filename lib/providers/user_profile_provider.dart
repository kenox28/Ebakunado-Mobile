import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  // Storage keys
  static const String _profileKey = 'user_profile_data';
  static const String _profileImageKey = 'user_profile_image';
  static const String _profileNameKey = 'user_profile_name';
  static const String _profileEmailKey = 'user_profile_email';
  static const String _profilePhoneKey = 'user_profile_phone';

  // Getters
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get displayName => _profile?.fullName ?? 'Loading...';
  String? get profileImageUrl => _profile?.profileImg;

  // Load profile data from API (same logic as Settings screen)
  Future<void> loadProfileData() async {
    _setLoading(true);
    _clearError();

    try {
      final response = await ApiClient.instance.getProfileData();

      // Handle JSON string response
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final profileResponse = ProfileDataResponse.fromJson(responseData);

      if (profileResponse.success && profileResponse.profile != null) {
        _profile = profileResponse.profile!;
        await _saveProfileToStorage(_profile!);
        notifyListeners();
      } else {
        _setError('Failed to load profile data');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _setError('Session expired');
      } else {
        _setError('Network error. Please try again.');
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        _setError('Session expired');
      } else {
        _setError('Failed to load profile data. Please try again.');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Load profile data from storage (for app startup)
  Future<void> loadProfileFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);

      if (profileJson != null) {
        final profileData = json.decode(profileJson);
        _profile = UserProfile.fromJson(profileData);
        notifyListeners();
      }
    } catch (e) {
      // If there's an error loading from storage, just continue without profile
    }
  }

  // Save profile data to storage
  Future<void> _saveProfileToStorage(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, json.encode(profile.toJson()));
      await prefs.setString(_profileNameKey, profile.fullName);
      await prefs.setString(_profileEmailKey, profile.email);
      await prefs.setString(_profilePhoneKey, profile.phoneNumber ?? '');
      if (profile.profileImg != null) {
        await prefs.setString(_profileImageKey, profile.profileImg!);
      }
    } catch (e) {
      // If there's an error saving, just continue
    }
  }

  // Update profile data (called from Settings screen)
  void updateProfile(UserProfile newProfile) {
    _profile = newProfile;
    notifyListeners();
  }

  // Clear profile data (called on logout)
  Future<void> clearProfile() async {
    _profile = null;
    _error = null;

    // Cancel notifications when profile is cleared
    await NotificationService.cancelAllNotifications();

    // Clear from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_profileImageKey);
      await prefs.remove(_profileNameKey);
      await prefs.remove(_profileEmailKey);
      await prefs.remove(_profilePhoneKey);
    } catch (e) {
      // If there's an error clearing storage, just continue
    }

    notifyListeners();
  }

  // Refresh profile data (called from Settings after updates)
  Future<void> refreshProfile() async {
    await loadProfileData();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
