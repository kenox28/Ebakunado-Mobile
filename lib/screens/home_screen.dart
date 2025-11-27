import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import '../widgets/dashboard_content.dart';
import '../widgets/app_bottom_navigation.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showConfigBanner = false;
  bool _checkingWizard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _maybeShowFirstRunWizard();
      _refreshConfigBanner();
    });
  }

  Future<void> _loadData() async {
    try {
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      final profileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: false,
      );

      // Ensure profile is loaded first (if not already loaded)
      // This is important for the drawer to show profile information
      if (profileProvider.profile == null) {
        debugPrint('HomeScreen: Profile not loaded, loading profile data...');
        try {
          await profileProvider.loadProfileData();
          debugPrint(
            'HomeScreen: Profile loaded - ${profileProvider.profile?.fullName ?? "unknown"}',
          );
        } catch (e) {
          debugPrint('HomeScreen: Error loading profile: $e');
          // Continue anyway - drawer will show loading state
        }
      } else {
        debugPrint(
          'HomeScreen: Profile already loaded - ${profileProvider.profile?.fullName ?? "unknown"}',
        );
      }

      // Load dashboard data and notifications in parallel
      await Future.wait([
        dashboardProvider.loadDashboardData(),
        notificationProvider.loadNotifications(),
      ]);

      // IMPORTANT: Check for missed notifications FIRST (when app opens)
      // This handles cases where notifications were scheduled but didn't fire when app was closed
      await NotificationService.checkForMissedNotifications();

      // Schedule daily notification check (only if user is logged in)
      await NotificationService.scheduleDailyNotificationCheck();

      // Get user_id from profile provider (more reliable than SharedPreferences)
      final userId = profileProvider.profile?.userId;

      final childrenSummary = dashboardProvider.childrenSummary;
      if (childrenSummary != null) {
        // Schedule notifications in advance for today/tomorrow immunizations.
        // These scheduled entries will trigger at the right time even if the app is closed.
        await NotificationService.scheduleUpcomingImmunizationNotifications(
          childrenSummary,
          userId: userId,
        );
        // Do NOT trigger checkNotificationsFromDashboardData here to avoid
        // immediate push when landing on dashboard; notifications will only
        // appear when their scheduled time arrives (or from missed-notification recovery).
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleError(context, e);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData();
  }

  Future<void> _maybeShowFirstRunWizard() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('first_run_seen') ?? false;
    final allOk = await _allConfigOk();
    if (!seen && !allOk && mounted) {
      await _showFirstRunWizardDialog();
      // After wizard, set flag; banner will still show until all green
      await prefs.setBool('first_run_seen', true);
    }
  }

  Future<void> _refreshConfigBanner() async {
    final notif = await NotificationService.areNotificationsEnabled();
    final exact = await NotificationService.canScheduleExactAlarms();
    final battery = await NotificationService.isBatteryOptimizationDisabled();
    final shouldShow = !(notif && exact && battery);
    if (mounted) {
      setState(() => _showConfigBanner = shouldShow);
    }
  }

  Future<bool> _allConfigOk() async {
    final notif = await NotificationService.areNotificationsEnabled();
    final exact = await NotificationService.canScheduleExactAlarms();
    final battery = await NotificationService.isBatteryOptimizationDisabled();
    return notif && exact && battery;
  }

  Future<void> _showFirstRunWizardDialog() async {
    if (_checkingWizard) return;
    _checkingWizard = true;
    int step = 0; // 0: Notifications, 1: Exact Alarms, 2: Battery
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> goNext() async {
              // Re-check and advance
              final notif = await NotificationService.areNotificationsEnabled();
              final exact = await NotificationService.canScheduleExactAlarms();
              final battery =
                  await NotificationService.isBatteryOptimizationDisabled();
              if (step == 0 && notif) {
                setStateDialog(() => step = 1);
              } else if (step == 1 && exact) {
                setStateDialog(() => step = 2);
              } else if (step == 2 && battery) {
                if (mounted) Navigator.pop(ctx);
              } else {
                // Stay on same step; user can retry or skip
                setStateDialog(() {});
              }
              await _refreshConfigBanner();
            }

            Widget contentForStep() {
              if (step == 0) {
                return const Text(
                  'Step 1: Enable Notifications\n\n'
                  'This opens your phone’s App notifications for Ebakunado.\n'
                  'Action: Turn notifications ON (Allow all).',
                );
              } else if (step == 1) {
                return const Text(
                  'Step 2: Allow Exact Alarms\n\n'
                  'This opens Special app access → Schedule exact alarms.\n'
                  'Action: Allow Ebakunado.',
                );
              }
              return const Text(
                'Step 3: Unrestrict Battery Optimization\n\n'
                'This opens your phone’s app details/battery settings.\n'
                'Action: Set Battery to Unrestricted (or Don’t optimize).',
              );
            }

            List<Widget> actions() {
              return [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () async {
                    // Open system settings for current step
                    if (step == 0) {
                      await NotificationService.openSystemNotificationSettings();
                    } else if (step == 1) {
                      await NotificationService.requestExactAlarmPermission();
                    } else {
                      await NotificationService.openSystemBatterySettings();
                    }
                  },
                  child: const Text('Open settings'),
                ),
                ElevatedButton(
                  onPressed: () async => goNext(),
                  child: Text(step == 2 ? 'Finish' : 'Next'),
                ),
              ];
            }

            return AlertDialog(
              title: const Text('Enable Notifications When Closed'),
              content: contentForStep(),
              actions: actions(),
            );
          },
        );
      },
    );
    _checkingWizard = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            backgroundColor: AppConstants.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [const NotificationBell(), const SizedBox(width: 8)],
          ),
          drawer: const AppDrawer(),
          body: Column(
            children: [
              if (_showConfigBanner)
                MaterialBanner(
                  content: const Text(
                    'Notifications may be delayed while settings are restricted. Review Settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppConstants.settingsRoute,
                        ).then((_) => _refreshConfigBanner());
                      },
                      child: const Text('Review'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showConfigBanner = false),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _handleRefresh();
                    await _refreshConfigBanner();
                  },
                  child: const DashboardContent(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomNavigation(
            current: BottomNavDestination.dashboard,
          ),
        );
      },
    );
  }
}
