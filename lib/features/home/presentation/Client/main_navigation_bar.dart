import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/workouts_page.dart';
import '../../../auth/auth_service.dart';
import 'dashboard_page.dart';
import '../Admin/clients_page.dart';
import 'profile_page.dart';

class MainNavigationBar extends StatefulWidget {
  const MainNavigationBar({super.key, required this.role});

  final UserRole role;

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  int _currentIndex = 0;

  List<Widget> get _pages {
    if (widget.role == UserRole.admin) {
      return const [
        DashboardPage(),
        WorkoutsPage(),
        ClientsPage(),
        ProfilePage(),
      ];
    }
    return const [
      DashboardPage(),
      ProfilePage(),
    ];
  }

  List<BottomNavigationBarItem> get _items {
    if (widget.role == UserRole.admin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Create Workout',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Clients',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }

    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final items = _items;

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: items,
      ),
    );
  }

}