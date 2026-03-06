import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/features/auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  void login() async {
    final user = await _authService.signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (user != null) {
      // Navigate to the home page or show a success message
      if (kDebugMode) {
        if (kDebugMode) {
          print("Login Succesfull");
        }
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Show an error message
      if (kDebugMode) {
        print("Login failed");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),

      body: Padding(
          padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Email'
              ),
            ),
            const SizedBox(height: 20,),

            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                  labelText: 'Password',
              ),
              obscureText: true,
            ),

            const SizedBox(height: 30,),
            
            ElevatedButton(
                onPressed: login,
                child: const Text('Login'),
            )
          ],
        ),
      ),
    );
  }
}