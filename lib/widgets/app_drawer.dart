import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/constants.dart';

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

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: AppConstants.primaryGreen,
                ),
                accountName: Text(
                  profile?.fullName ?? user?.fullName ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  profile?.email ?? user?.email ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: (profile?.profileImg != null)
                      ? NetworkImage(profile!.profileImg!)
                      : (user?.profileImg != null)
                      ? NetworkImage(user!.profileImg!)
                      : null,
                  child:
                      (profile?.profileImg == null && user?.profileImg == null)
                      ? Icon(
                          Icons.person,
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
                    Navigator.pushNamed(context, AppConstants.myChildrenRoute);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Add Child'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppConstants.addChildRoute);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_turned_in),
                  title: const Text('Approved Requests'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppConstants.approvedRequestsRoute,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.vaccines),
                  title: const Text('Immunization Approvals'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppConstants.immunizationApprovalsRoute,
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
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to help
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & Support coming soon'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Debug & Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/notification_test');
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
                  Navigator.pop(context);

                  // Show confirmation dialog
                  final shouldLogout = await showDialog<bool>(
                    context: context,
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
                    await authProvider.logout();
                    await profileProvider.clearProfile(); // Clear profile data
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppConstants.loginRoute,
                        (route) => false,
                      );
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
