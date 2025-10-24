import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_bell.dart';
import '../widgets/dashboard_content.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
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

      // Load dashboard data and notifications in parallel
      await Future.wait([
        dashboardProvider.loadDashboardData(),
        notificationProvider.loadNotifications(),
      ]);

      // Schedule daily notification check (only if user is logged in)
      await NotificationService.scheduleDailyNotificationCheck();

      // Check for immunization notifications after login
      await NotificationService.checkForNewNotificationsDaily();
    } catch (e) {
      if (mounted) {
        ErrorHandler.handleError(context, e);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData();
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
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: const DashboardContent(),
          ),
        );
      },
    );
  }
}
