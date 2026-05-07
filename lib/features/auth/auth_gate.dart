import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/branded_loading_screen.dart';
import '../home/presentation/Client/login_page.dart';
import '../home/presentation/Client/main_navigation_bar.dart';
import 'auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: BrandedLoadingScreen());
        }

        final user = authSnapshot.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<Map<String, dynamic>>(
          future: Future.wait([
            authService.shouldStayLoggedIn(),
            authService.getUserRole(user.uid),
          ]).then((results) => {
            'stayLoggedIn': results[0],
            'role': results[1],
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: BrandedLoadingScreen());
            }

            final stayLoggedIn = snapshot.data?['stayLoggedIn'] ?? true;
            final role = snapshot.data?['role'] ?? UserRole.user;

            if (!stayLoggedIn) {
              authService.signOut();
              return const LoginPage();
            }

            return MainNavigationBar(role: role);
          },
        );
      },
    );
  }
}
