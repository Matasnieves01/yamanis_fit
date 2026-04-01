import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  final Color backgroundColor = const Color(0xFF11151C);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color surfaceColor = const Color(0xFF55768C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('POLÍTICA DE PRIVACIDAD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tu Privacidad es Importante",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "En Yamani's Fit nos tomamos muy en serio la protección de tus datos personales. A continuación, detallamos cómo manejamos tu información.",
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildSection(
              "1. Información que Recolectamos",
              "Recopilamos tu nombre, correo electrónico y datos de entrenamiento (ejercicios, pesos y feedback) para personalizar tu experiencia y permitir que tu trainer realice el seguimiento adecuado.",
            ),
            _buildSection(
              "2. Uso de la Información",
              "Tus datos se utilizan exclusivamente para la gestión de tus rutinas, comunicación con tu entrenador y mejora de nuestros servicios.",
            ),
            _buildSection(
              "3. Protección de Datos",
              "Utilizamos servicios de Google Firebase con altos estándares de seguridad para asegurar que tu información esté protegida contra accesos no autorizados.",
            ),
            _buildSection(
              "4. Compartir Información",
              "No vendemos ni compartimos tus datos personales con terceros para fines comerciales. Tu información solo es visible para ti y tu entrenador asignado.",
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Última actualización: Marzo 2024",
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
