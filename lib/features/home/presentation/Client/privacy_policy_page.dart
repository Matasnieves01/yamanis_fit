import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  final Color backgroundColor = const Color(0xFF11151C);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color surfaceColor = const Color(0xFF55768C);

  static const String webUrl = 'https://vyofit-5eedf.web.app/privacy-policy.html';

  Future<void> _openWebVersion(BuildContext context) async {
    final uri = Uri.parse(webUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tu Privacidad es Importante",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "En Yamani's Fit nos tomamos muy en serio la protección de tus datos personales. A continuación, detallamos cómo manejamos tu información.",
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            _buildSection(
              "1. Información que Recolectamos",
              "Recopilamos tu nombre, correo electrónico, contraseña (cifrada por Firebase Authentication) y datos de entrenamiento (rutinas asignadas, ejercicios, pesos levantados, repeticiones, feedback de progreso y comentarios) para personalizar tu experiencia y permitir que tu entrenador realice el seguimiento adecuado.",
            ),
            _buildSection(
              "2. Uso de la Información",
              "Tus datos se utilizan exclusivamente para la gestión de tus rutinas, el seguimiento de tu progreso físico, la comunicación con tu entrenador, el envío de notificaciones dentro de la app y la mejora de nuestros servicios. No utilizamos tus datos para publicidad.",
            ),
            _buildSection(
              "3. Protección de Datos",
              "Utilizamos servicios de Google Firebase (Authentication, Firestore y Storage) con altos estándares de seguridad para asegurar que tu información esté protegida contra accesos no autorizados.",
            ),
            _buildSection(
              "4. Compartir Información",
              "No vendemos ni compartimos tus datos personales con terceros para fines comerciales. Tu información personal y de entrenamiento solo es visible para ti y para tu entrenador/administrador asignado dentro de la app, quien la utiliza para diseñar y ajustar tus rutinas.",
            ),
            _buildSection(
              "5. Aviso de Salud y Contenido de Ejercicio",
              "Las rutinas de ejercicio y los planes de alimentación disponibles en la app son orientativos y elaborados por tu entrenador. Esta información no constituye asesoría médica ni nutricional profesional y no sustituye la consulta con un médico, nutricionista u otro profesional de la salud. Consulta a un profesional antes de iniciar cualquier programa de ejercicio o alimentación, especialmente si tienes una condición médica preexistente.",
            ),
            _buildSection(
              "6. Retención y Eliminación de Datos",
              "Conservamos tu información mientras tu cuenta esté activa. Puedes solicitar la eliminación de tu cuenta y de tus datos en cualquier momento desde Perfil > Configuración > Eliminar Cuenta. Esta acción es permanente e irreversible.",
            ),
            _buildSection(
              "7. Contacto",
              "Si tienes preguntas sobre esta política o sobre el manejo de tus datos, escríbenos a vyofitsoporte@gmail.com.",
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _openWebVersion(context),
                icon: Icon(Icons.open_in_new_rounded, color: primaryColor, size: 18),
                label: Text(
                  'VER VERSIÓN WEB',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                "Última actualización: Junio 2026",
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
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
