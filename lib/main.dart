import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/child_record_screen.dart';
import 'screens/immunization_schedule_screen.dart';
import 'screens/my_children_screen.dart';
import 'screens/add_child_screen.dart';
import 'screens/chr_requests_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notification_test_screen.dart';
import 'utils/constants.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz.initializeTimeZones();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize notification service
  await NotificationService.initialize();

  // Schedule daily notification check
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
            case AppConstants.addChildRoute:
              return MaterialPageRoute(builder: (_) => const AddChildScreen());
            case AppConstants.chrRequestsRoute:
              return MaterialPageRoute(
                builder: (_) => const ChrRequestsScreen(),
              );
            case AppConstants.settingsRoute:
              return MaterialPageRoute(builder: (_) => const SettingsScreen());
            case AppConstants.approvedRequestsRoute:
              return MaterialPageRoute(
                builder: (_) =>
                    const PlaceholderScreen(title: 'Approved Requests'),
              );
            case '/debug':
              return MaterialPageRoute(builder: (_) => const DebugScreen());
            case '/notification_test':
              return MaterialPageRoute(
                builder: (_) => const NotificationTestScreen(),
              );
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
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
        if (authProvider.isLoading) {
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
