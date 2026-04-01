import 'package:flutter/material.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/presentation/Client/login_page.dart';
import 'features/home/presentation/Client/register_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VYO Fitness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const AuthGate(),
      },
    );
  }
}
