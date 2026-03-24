import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/auth/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _displayName = "Loading...";
  String _email = "";
  bool _isLoading = true;

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
            if (_displayName.isEmpty) _displayName = "No Name Provided";
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _displayName = "Error loading name";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFF55768C),
                child: Icon(Icons.person, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 20),
              // User Name (Fetched from Firestore)
              Text(
                _displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _email,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _buildProfileOption(icon: Icons.settings, title: "Settings"),
              _buildProfileOption(icon: Icons.notifications, title: "Notifications"),
              _buildProfileOption(icon: Icons.help_outline, title: "Help & Support"),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleSignOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text("Log Out"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({required IconData icon, required String title}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFAEE084)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}
