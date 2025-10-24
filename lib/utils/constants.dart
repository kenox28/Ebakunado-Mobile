import 'package:flutter/material.dart';

class AppConstants {
  // API Configuration
  static const String baseUrl =
      'http://192.168.43.73/ebakunado'; // Local server
  static const String apiKey = 'MY_SECRET_KEY';
  static const int requestTimeout = 30; // seconds

  // Supabase Configuration
  static const String supabaseUrl = 'https://wdwjddwrkxvipzabroed.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkd2pkZHdya3h2aXB6YWJyb2VkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA4MjkwNSwiZXhwIjoyMDczNjU4OTA1fQ.w3PdR-eP8WVK-H6l2sc9wjdo4ORx_J12Nd7DvMOV9_E';

  // Authentication Endpoints
  static const String loginEndpoint = '/php/supabase/login.php';
  static const String logoutEndpoint = '/php/supabase/users/logout.php';

  // Notification Endpoints
  static const String notificationsEndpoint =
      '/php/supabase/users/get_user_notifications.php';
  static const String markNotificationReadEndpoint =
      '/php/supabase/users/mark_notification_read.php';
  static const String markAllNotificationsReadEndpoint =
      '/php/supabase/users/mark_notifications_read_all.php';
  static const String dailyNotificationsEndpoint =
      '/php/supabase/users/get_daily_notifications.php';

  // Dashboard Endpoints
  static const String childrenSummaryEndpoint =
      '/php/supabase/users/get_children_summary.php';
  static const String acceptedChildEndpoint =
      '/php/supabase/users/get_accepted_child.php';
  static const String dashboardSummaryEndpoint =
      '/php/supabase/users/get_dashboard_summary.php';
  static const String childListEndpoint =
      '/php/supabase/users/get_child_list.php';

  // Child Details Endpoints
  static const String childDetailsEndpoint =
      '/php/supabase/users/get_child_details.php';
  static const String immunizationScheduleEndpoint =
      '/php/supabase/users/get_immunization_schedule.php';

  // CHR Request Endpoints
  static const String requestChrDocEndpoint =
      '/php/supabase/users/request_chr_doc.php';
  static const String getChrDocStatusEndpoint =
      '/php/supabase/users/get_chr_doc_status.php';
  static const String getMyChrRequestsEndpoint =
      '/php/supabase/users/get_my_chr_requests.php';

  // Add Child Endpoints
  static const String addChildEndpoint = '/php/supabase/users/add_child.php';
  static const String claimChildWithCodeEndpoint =
      '/php/supabase/users/claim_child_with_code.php';
  static const String requestImmunizationEndpoint =
      '/php/supabase/users/request_immunization.php';

  // Settings/Profile Endpoints
  static const String getProfileDataEndpoint =
      '/php/supabase/users/get_profile_data.php';
  static const String updateProfileEndpoint =
      '/php/supabase/users/update_profile.php';
  static const String uploadProfilePhotoEndpoint =
      '/php/supabase/users/upload_profile_photo.php';

  // Legacy Endpoints (keeping for compatibility)
  static const String getUsersEndpoint = '/get_users.php';
  static const String getMidwivesEndpoint = '/get_midwives.php';
  static const String getBhwEndpoint = '/get_bhw.php';
  static const String getImmunizationsEndpoint = '/get_immunizations.php';
  static const String getAdminsEndpoint = '/get_admins.php';
  static const String getSuperAdminsEndpoint = '/get_super_admins.php';
  static const String getLogsEndpoint = '/get_logs.php';

  // Colors - Healthcare theme
  static const Color primaryGreen = Color(0xFF1A7B49); // Dark green primary
  static const Color buttonBlue = Color(0xFF2196F3); // Blue for buttons
  static const Color lightGreen = Color(0xFF81C784); // Light green for buttons
  static const Color mediumGreen = Color(
    0xFF4CAF50,
  ); // Medium green for buttons
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color secondaryGray = Color(0xFFF5F5F5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  // Modern Alert Colors (connected to app theme)
  static const Color alertSuccess = Color(
    0xFF2E7D32,
  ); // Darker green for success
  static const Color alertError = Color(0xFFD32F2F); // Modern red for errors
  static const Color alertWarning = Color(
    0xFFF57C00,
  ); // Modern orange for warnings
  static const Color alertInfo = Color(0xFF1976D2); // Modern blue for info

  // Legacy color for backward compatibility
  static const Color primaryBlue = buttonBlue;

  // Route Names
  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String requestChildRoute = '/request_child';
  static const String approvedRequestsRoute = '/approved_requests';
  static const String upcomingScheduleRoute = '/upcoming_schedule';
  static const String childRecordRoute = '/child_record';
  static const String addChildRoute = '/add_child';
  static const String myChildrenRoute = '/my_children';
  static const String chrRequestsRoute = '/chr_requests';
  static const String settingsRoute = '/settings';

  // Storage Keys
  static const String isLoggedInKey = 'is_logged_in';
  static const String userEmailKey = 'user_email';
  static const String authTokenKey = 'auth_token';
  static const String lastSyncKey = 'last_sync';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardElevation = 4.0;
  static const double borderRadius = 12.0;
  static const double iconSize = 24.0;
  static const double avatarRadius = 30.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: textPrimary,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );

  // App Theme
  static ThemeData get appTheme {
    return ThemeData(
      primarySwatch: MaterialColor(0xFF1A7B49, {
        50: const Color(0xFFE8F5E8),
        100: const Color(0xFFC8E6C8),
        200: const Color(0xFFA5D6A5),
        300: const Color(0xFF81C784),
        400: const Color(0xFF66BB6A),
        500: const Color(0xFF1A7B49),
        600: const Color(0xFF388E3C),
        700: const Color(0xFF2E7D32),
        800: const Color(0xFF1B5E20),
        900: const Color(0xFF0D4A2A),
      }),
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: headingStyle,
        headlineMedium: subheadingStyle,
        bodyLarge: bodyStyle,
        bodySmall: captionStyle,
      ),
    );
  }
}
