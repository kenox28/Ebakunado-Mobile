import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/forgot_password_request_screen.dart';
import 'screens/forgot_password_verify_screen.dart';
import 'screens/forgot_password_reset_screen.dart';
import 'screens/home_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/child_record_screen.dart';
import 'screens/immunization_schedule_screen.dart';
import 'screens/my_children_screen.dart';
import 'screens/approved_requests_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/app_notification_settings_screen.dart';
import 'screens/add_child_screen.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();
  await NotificationService.initializeTimezone();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize notification service (this also initializes WorkManager)
  await NotificationService.initialize();

  // Schedule daily notification check (uses WorkManager for reliability)
  await NotificationService.scheduleDailyNotificationCheck();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
      ],
      child: MaterialApp(
        title: 'Ebakunado',
        theme: AppConstants.appTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppConstants.loginRoute:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case AppConstants.createAccountRoute:
              return MaterialPageRoute(
                builder: (_) => const CreateAccountScreen(),
              );
            case AppConstants.forgotPasswordRequestRoute:
              return MaterialPageRoute(
                builder: (_) => const ForgotPasswordRequestScreen(),
              );
            case AppConstants.forgotPasswordVerifyRoute:
              return MaterialPageRoute(
                builder: (_) => const ForgotPasswordVerifyScreen(),
                settings: settings, // Pass settings to access arguments
              );
            case AppConstants.forgotPasswordResetRoute:
              return MaterialPageRoute(
                builder: (_) => const ForgotPasswordResetScreen(),
              );
            case AppConstants.homeRoute:
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case AppConstants.childRecordRoute:
              final args = settings.arguments as Map<String, dynamic>?;
              final babyId = args?['baby_id'] as String?;
              if (babyId != null) {
                return MaterialPageRoute(
                  builder: (_) => ChildRecordScreen(babyId: babyId),
                );
              }
              return MaterialPageRoute(
                builder: (_) => const PlaceholderScreen(title: 'Child Record'),
              );
            case AppConstants.upcomingScheduleRoute:
              final args = settings.arguments as Map<String, dynamic>?;
              final babyId = args?['baby_id'] as String?;
              if (babyId != null) {
                return MaterialPageRoute(
                  builder: (_) => ImmunizationScheduleScreen(babyId: babyId),
                );
              }
              return MaterialPageRoute(
                builder: (_) =>
                    const PlaceholderScreen(title: 'Immunization Schedule'),
              );
            case AppConstants.myChildrenRoute:
              return MaterialPageRoute(
                builder: (_) => const MyChildrenScreen(),
              );
            case AppConstants.requestChildRoute:
              return MaterialPageRoute(builder: (_) => const AddChildScreen());
            case AppConstants.approvedRequestsRoute:
              return MaterialPageRoute(
                builder: (_) => const ApprovedRequestsScreen(),
              );
            case AppConstants.settingsRoute:
              return MaterialPageRoute(builder: (_) => const SettingsScreen());
            case '/app-notifications':
              return MaterialPageRoute(
                builder: (_) => const AppNotificationSettingsScreen(),
              );
            case '/debug':
              return MaterialPageRoute(builder: (_) => const DebugScreen());
            default:
              return MaterialPageRoute(
                builder: (_) =>
                    const Scaffold(body: Center(child: Text('Page not found'))),
              );
          }
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleFirstLaunchAndAuth();
    });
  }

  Future<void> _handleFirstLaunchAndAuth() async {
    try {
      // Check if this is first launch and request permissions
      await _handleFirstLaunchPermissions();

      // Then check auth status
      await _checkAuthStatus();
    } catch (e) {
      debugPrint('Initialization failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingFirstLaunch = false);
      }
    }
  }

  Future<void> _handleFirstLaunchPermissions() async {
    if (!Platform.isAndroid) {
      return; // Only for Android
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool('first_launch_completed') ?? true;

      if (isFirstLaunch) {
        debugPrint('First launch detected - requesting permissions...');

        // Request notification permission (system dialog)
        await NotificationService.requestPermissions();

        // Request battery optimization exemption (system dialog)
        await NotificationService.requestBatteryOptimizationExemption();

        // Request exact alarms permission (system dialog, Android 12+)
        final canSchedule = await NotificationService.canScheduleExactAlarms();
        if (!canSchedule) {
          await NotificationService.requestExactAlarmPermission();
        }

        // Mark first launch as completed
        await prefs.setBool('first_launch_completed', false);
        debugPrint('First launch permissions requested');
      }
    } catch (e) {
      debugPrint('Error handling first launch permissions: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: false,
      );

      // Load profile data from storage first
      await profileProvider.loadProfileFromStorage();

      // Check auth status
      await authProvider.checkAuthStatus();

      // If user is logged in, load fresh profile data from API
      if (authProvider.isLoggedIn) {
        await profileProvider.loadProfileData();
      }
    } catch (e) {
      // If auth check fails, user will see login screen
      debugPrint('Auth check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading screen while checking first launch and auth
        if (_isCheckingFirstLaunch || authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Static logo (no animation)
                  Image.asset(
                    'assets/ebakunado-logo-without-label.png',
                    height: 80,
                    width: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ebakunado',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Animated progress indicator
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppConstants.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return authProvider.isLoggedIn
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}

// Placeholder screen for routes that aren't implemented yet
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '$title Coming Soon',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is under development',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
