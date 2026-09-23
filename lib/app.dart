import 'package:flutter/material.dart';
import 'core/widgets/app_background.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/presentation/Client/login_page.dart';
import 'features/home/presentation/Client/register_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const brandBackground = Color(0xFF11151C);
    const brandPrimary = Color(0xFFAEE084);

    return MaterialApp(
      title: 'VYO Fitness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: brandBackground,
        colorScheme: ColorScheme.dark(
          primary: brandPrimary,
          onPrimary: brandBackground,
          surface: brandBackground,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: brandPrimary,
        ),
      ),
      builder: (context, child) {
        return AppBackground(
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const AuthGate(),
      },
    );
  }
}
