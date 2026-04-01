import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // If we have a user, check if they should stay logged in
        return FutureBuilder<bool>(
          future: authService.shouldStayLoggedIn(),
          builder: (context, stayLoggedInSnapshot) {
            if (stayLoggedInSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final stayLoggedIn = stayLoggedInSnapshot.data ?? true;

            if (!stayLoggedIn) {
              // If they shouldn't stay logged in, sign them out and show login page
              authService.signOut();
              return const LoginPage();
            }

            // If they should stay logged in, proceed to check role and show home
            return FutureBuilder<UserRole>(
              future: authService.getUserRole(user.uid),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final role = roleSnapshot.data ?? UserRole.user;
                return MainNavigationBar(role: role);
              },
            );
          },
        );
      },
    );
  }
}
