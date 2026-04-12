import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isLoading = false;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'role': 'user',
        'isActive': false,
        'activeUntil': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada. Espera a que el administrador la active para iniciar sesión.'), behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Register error: $e');
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor.withValues(alpha: 0.8), fontSize: 13),
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
            colors: [backgroundColor, backgroundColor.withValues(alpha: 0.8)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_rounded, size: 64, color: primaryColor),
                ),
                const SizedBox(height: 32),
                const Text(
                  "CREAR CUENTA",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "ÚNETE A LA COMUNIDAD",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Registration Fields in a Fixed Size Box
                SizedBox(
                  width: 350, // Fixed width
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _firstNameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _buildInputDecoration('NOMBRE', Icons.person_outline),
                        ),
                        Divider(height: 1, color: surfaceColor.withValues(alpha: 0.2), indent: 20, endIndent: 20),
                        TextField(
                          controller: _lastNameController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _buildInputDecoration('APELLIDO', Icons.person_outline),
                        ),
                        Divider(height: 1, color: surfaceColor.withValues(alpha: 0.2), indent: 20, endIndent: 20),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _buildInputDecoration('CORREO ELECTRÓNICO', Icons.email_outlined),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        Divider(height: 1, color: surfaceColor.withValues(alpha: 0.2), indent: 20, endIndent: 20),
                        TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _buildInputDecoration('CONTRASEÑA', Icons.lock_outline),
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: 350, // Fixed width matching the input box
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
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
                            'REGISTRARSE',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿Ya tienes cuenta? ",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "INICIA SESIÓN",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
