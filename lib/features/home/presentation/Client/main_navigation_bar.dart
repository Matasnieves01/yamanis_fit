import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/workouts_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/auth_service.dart';
import 'dashboard_page.dart';
import '../Admin/clients_page.dart';
import '../Admin/notifications_page.dart';
import 'profile_page.dart';
import 'notifications_page.dart';

class MainNavigationBar extends StatefulWidget {
  const MainNavigationBar({super.key, required this.role});

  final UserRole role;

  @override
  State<MainNavigationBar> createState() => _MainNavigationBarState();
}

class _MainNavigationBarState extends State<MainNavigationBar> {
  int _currentIndex = 0;

  final Color primaryColor = const Color(0xFFAEE084);

  List<Widget> get _pages {
    if (widget.role == UserRole.admin) {
      return const [
        DashboardPage(),
        WorkoutsPage(),
        ClientsPage(),
        NotificationsPage(),
        ProfilePage(),
      ];
    }
    return const [
      DashboardPage(),
      ClientNotificationsPage(),
      ProfilePage(),
    ];
  }

  List<BottomNavigationBarItem> get _items {
    if (widget.role == UserRole.admin) {
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center_outlined),
          activeIcon: Icon(Icons.fitness_center),
          label: 'Ejercicios',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Clientes',
        ),
        BottomNavigationBarItem(
          icon: _buildNotificationIcon(isAdmin: true),
          label: 'Alertas',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ];
    }

    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Inicio',
      ),
      BottomNavigationBarItem(
        icon: _buildNotificationIcon(isAdmin: false),
        label: 'Alertas',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];
  }

  Widget _buildNotificationIcon({required bool isAdmin}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Icon(Icons.notifications_outlined);
    }

    // Update queries to match security rules:
    // 1. Admins only see notifications where targetRole == 'admin'
    // 2. Clients only see notifications where userId == currentUid
    final stream = isAdmin
        ? FirebaseFirestore.instance
            .collection('notifications')
            .where('targetRole', isEqualTo: 'admin')
            .where('read', isEqualTo: false)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .where('read', isEqualTo: false)
            .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        // The where clauses in the query already handle most filtering
        final hasUnread = docs.isNotEmpty;

        return Stack(
          children: [
            const Icon(Icons.notifications_outlined),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Theme(
        data: ThemeData.dark().copyWith(
          canvasColor: const Color(0xFF11151C),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.white38,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          items: _items,
        ),
      ),
    );
  }
}
