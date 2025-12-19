import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/constants.dart';
import '../main.dart'; // Import to access navigatorKey

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header
          Consumer2<AuthProvider, UserProfileProvider>(
            builder: (context, authProvider, profileProvider, child) {
              final user = authProvider.user;
              final profile = profileProvider.profile;
              final isLoading = profileProvider.isLoading && profile == null;

              // If profile is loading and not available, try to load it
              if (profile == null && !isLoading && !profileProvider.isLoading) {
                // Trigger profile load if not already loading
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  profileProvider.loadProfileData();
                });
              }

              // Get display name - prefer profile, fallback to user, then loading
              final displayName =
                  profile?.fullName ??
                  user?.fullName ??
                  (isLoading ? 'Loading...' : 'User');

              // Get email - prefer profile, fallback to user
              final displayEmail = profile?.email ?? user?.email ?? '';

              // Get profile image - prefer profile, fallback to user
              final profileImage = profile?.profileImg ?? user?.profileImg;

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: AppConstants.primaryGreen,
                ),
                accountName: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  displayEmail,
                  style: const TextStyle(fontSize: 14),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: profileImage != null
                      ? NetworkImage(profileImage)
                      : null,
                  child: profileImage == null
                      ? Icon(
                          isLoading ? Icons.hourglass_empty : Icons.person,
                          size: 40,
                          color: AppConstants.primaryGreen,
                        )
                      : null,
                ),
              );
            },
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  selected: true,
                  selectedTileColor: AppConstants.secondaryGray,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.child_care),
                  title: const Text('My Children'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(
                      context,
                      AppConstants.myChildrenRoute,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('Add Child'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(
                      context,
                      AppConstants.requestChildRoute,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_turned_in),
                  title: const Text('Baby Cards'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppConstants.approvedRequestsRoute,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppConstants.settingsRoute);
                  },
                ),
              ],
            ),
          ),

          // Logout
          const Divider(),
          Consumer2<AuthProvider, UserProfileProvider>(
            builder: (context, authProvider, profileProvider, child) {
              return ListTile(
                leading: const Icon(Icons.logout, color: AppConstants.errorRed),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppConstants.errorRed),
                ),
                onTap: () async {
                  // Get all providers BEFORE closing the drawer (to avoid deactivated widget error)
                  final dashboardProvider = Provider.of<DashboardProvider>(
                    context,
                    listen: false,
                  );
                  final notificationProvider =
                      Provider.of<NotificationProvider>(context, listen: false);

                  // Store the context reference before async operations
                  final navigatorContext = context;

                  Navigator.pop(navigatorContext);

                  // Show confirmation dialog
                  final shouldLogout = await showDialog<bool>(
                    context: navigatorContext,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: AppConstants.errorRed),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (shouldLogout == true) {
                    // Close dialog first
                    if (navigatorContext.mounted) {
                      Navigator.of(navigatorContext, rootNavigator: true).pop();
                    }

                    // Clear all cached data
                    await authProvider.logout();
                    await profileProvider.clearProfile();
                    dashboardProvider.clear();
                    notificationProvider.clear();

                    // Wait for state to propagate
                    await Future.delayed(const Duration(milliseconds: 100));

                    // Use global navigator key to ensure we're using the root navigator
                    // This works from ANY screen (Settings, Dashboard, etc.)
                    final rootNav = navigatorKey.currentState;
                    if (rootNav != null) {
                      try {
                        // Remove ALL routes and navigate to login
                        // This clears the entire navigation stack
                        rootNav.pushNamedAndRemoveUntil(
                          AppConstants.loginRoute,
                          (route) => false, // Remove all routes
                        );
                      } catch (e) {
                        debugPrint('Logout navigation error: $e');
                        // Fallback: pop all routes to root
                        // AuthWrapper will rebuild and show LoginScreen
                        try {
                          rootNav.popUntil((route) => route.isFirst);
                        } catch (e2) {
                          debugPrint('Fallback navigation also failed: $e2');
                        }
                      }
                    } else {
                      debugPrint('Navigator key is null - cannot navigate');
                    }
                  }
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
