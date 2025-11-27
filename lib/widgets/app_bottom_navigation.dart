import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum BottomNavDestination { dashboard, addChild, myChildren }

class AppBottomNavigation extends StatelessWidget {
  final BottomNavDestination current;

  const AppBottomNavigation({
    super.key,
    required this.current,
  });

  void _onDestinationSelected(BuildContext context, int index) {
    final destination = BottomNavDestination.values[index];
    if (destination == current) {
      return;
    }

    String route;
    switch (destination) {
      case BottomNavDestination.dashboard:
        route = AppConstants.homeRoute;
        break;
      case BottomNavDestination.addChild:
        route = AppConstants.requestChildRoute;
        break;
      case BottomNavDestination.myChildren:
        route = AppConstants.myChildrenRoute;
        break;
    }

    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (index) => _onDestinationSelected(context, index),
      height: 72,
      indicatorColor: AppConstants.primaryGreen.withOpacity(0.15),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.child_friendly_outlined),
          selectedIcon: Icon(Icons.child_friendly),
          label: 'Add Child',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'My Children',
        ),
      ],
    );
  }
}

