import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  bool isLoading = false;
  bool _stayLoggedIn = true;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  void login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _authService.signIn(email, password, stayLoggedIn: _stayLoggedIn);

      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        String message = 'Error al iniciar sesión. Verifica tus credenciales.';
        if (_authService.lastSignInError != null) {
          if (_authService.lastSignInError!.contains('user-not-found')) {
            message = 'Usuario no encontrado.';
          } else if (_authService.lastSignInError!.contains('wrong-password')) {
            message = 'Contraseña incorrecta.';
          } else if (_authService.lastSignInError!.contains('Account not active')) {
             message = 'Tu cuenta aún no ha sido activada por el administrador.';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 14),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor, backgroundColor.withOpacity(0.8)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  height: 140,
                  width: 140,
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/logos/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.fitness_center_rounded, size: 64, color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "BIENVENIDO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "ENTRENA CON PROPÓSITO",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 48),
                
                // TextFields in a Fixed Size Box
                SizedBox(
                  width: 350, // Fixed width
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: surfaceColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _buildInputDecoration('CORREO ELECTRÓNICO', Icons.email_outlined),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        Divider(height: 1, color: surfaceColor.withOpacity(0.2), indent: 20, endIndent: 20),
                        TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _buildInputDecoration('CONTRASEÑA', Icons.lock_outline_rounded),
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Stay logged in checkbox
                SizedBox(
                  width: 350,
                  child: Row(
                    children: [
                      Theme(
                        data: ThemeData(
                          unselectedWidgetColor: primaryColor.withOpacity(0.5),
                        ),
                        child: Checkbox(
                          value: _stayLoggedIn,
                          onChanged: (value) {
                            setState(() {
                              _stayLoggedIn = value ?? true;
                            });
                          },
                          activeColor: primaryColor,
                          checkColor: backgroundColor,
                        ),
                      ),
                      const Text(
                        "Mantener sesión iniciada",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                SizedBox(
                  width: 350, // Fixed width matching the input box
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
                          )
                        : const Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tienes cuenta? ",
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: Text(
                        "REGÍSTRATE",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
