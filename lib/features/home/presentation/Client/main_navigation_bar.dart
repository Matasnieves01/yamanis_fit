import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/workouts_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../auth/auth_service.dart';
import 'dashboard_page.dart';
import '../Admin/clients_page.dart';
import '../Admin/notifications_page.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/promotions_page.dart' as admin_promotions;
import 'promotions_page.dart';
import '../Shared/resources_page.dart';
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
  bool _isAccessExpired = false;
  final AuthService _authService = AuthService();

  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _checkAccessStatus();
  }

  Future<void> _checkAccessStatus() async {
    if (widget.role == UserRole.user) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final isActive = await _authService.isUserAccessActive(uid);
        if (mounted) {
          setState(() {
            _isAccessExpired = !isActive;
          });
        }
      }
    }
  }

  List<Widget> get _pages {
    if (widget.role == UserRole.admin) {
      return const [
        DashboardPage(),
        WorkoutsPage(),
        ClientsPage(),
        admin_promotions.PromotionsPage(),
        ResourcesPage(isAdmin: true),
        NotificationsPage(),
        ProfilePage(),
      ];
    }
    return const [
      DashboardPage(),
      PromotionsPage(),
      ResourcesPage(isAdmin: false),
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
        const BottomNavigationBarItem(
          icon: Icon(Icons.local_offer_outlined),
          activeIcon: Icon(Icons.local_offer),
          label: 'Promos',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.folder_outlined),
          activeIcon: Icon(Icons.folder),
          label: 'Recursos',
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
      const BottomNavigationBarItem(
        icon: Icon(Icons.local_offer_outlined),
        activeIcon: Icon(Icons.local_offer),
        label: 'Promociones',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.folder_outlined),
        activeIcon: Icon(Icons.folder),
        label: 'Recursos',
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
            .snapshots()
            .map((snapshot) {
              // Filtrar localmente porque no podemos hacer query de campo inexistente vs valor específico
              // de forma simple sin índices compuestos si hay otros filtros.
              // En este caso, queremos evitar las que tienen targetRole == 'admin'
              return snapshot.docs.where((doc) {
                final data = doc.data();
                return data['targetRole'] != 'admin';
              }).toList();
            });

    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        final docs = (snapshot.data is List) 
            ? (snapshot.data as List) 
            : (snapshot.data as QuerySnapshot?)?.docs ?? [];
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

  Future<void> _openWhatsApp() async {
    const phone = '50769184836';
    final message = Uri.encodeComponent(
      'Hola! Mi membresía expiró y quiero renovarla. ¿Me puedes ayudar?',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          if (_isAccessExpired && widget.role == UserRole.user)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C222D),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'AVISO DE SUSCRIPCIÓN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tu suscripción ha expirado. Recuerda contactar con tu coach para renovarla y mantener tu perfil activo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.chat_bubble_rounded),
                            label: const Text(
                              'RENOVAR POR WHATSAPP',
                              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: TextButton(
                            onPressed: () => setState(() => _isAccessExpired = false),
                            child: const Text(
                              'ENTENDIDO',
                              style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
