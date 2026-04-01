import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/auth/auth_service.dart';
import 'settings_page.dart';
import 'help_support_page.dart';
import 'privacy_policy_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _displayName = "Cargando...";
  String _email = "";
  bool _isLoading = true;

  // Kinetic Theme Colors
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email = user.email ?? "";
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _displayName = "${data?['firstName'] ?? ''} ${data?['lastName'] ?? ''}".trim();
            if (_displayName.isEmpty) _displayName = "Sin nombre proporcionado";
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _displayName = "Error al cargar el nombre";
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleSignOut(BuildContext context) async {
    final authService = AuthService();
    await authService.signOut();
  }

  Future<void> _navigateToSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
    if (mounted) {
      _loadUserData(); // Refresh data when returning from settings
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Image.asset(
          'assets/logos/logo.png',
          height: 40,
          errorBuilder: (context, error, stackTrace) => const Text(
            'PERFIL',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: surfaceColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: primaryColor.withOpacity(0.2),
                      child: Icon(Icons.person, size: 60, color: primaryColor),
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? CircularProgressIndicator(color: primaryColor)
                        : Text(
                            _displayName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                    const SizedBox(height: 8),
                    Text(
                      _email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Menu Options
              _buildProfileOption(
                icon: Icons.settings_outlined, 
                title: "Configuración", 
                onTap: () => _navigateToSettings(context)
              ),
              _buildProfileOption(
                icon: Icons.help_outline_rounded, 
                title: "Ayuda y Soporte",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportPage()))
              ),
              _buildProfileOption(
                icon: Icons.privacy_tip_outlined, 
                title: "Política de Privacidad",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()))
              ),
              const SizedBox(height: 40),
              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => _handleSignOut(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    "CERRAR SESIÓN",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({required IconData icon, required String title, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceColor.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        leading: Icon(icon, color: primaryColor),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white.withOpacity(0.2)),
        onTap: onTap ?? () {},
      ),
    );
  }
}
