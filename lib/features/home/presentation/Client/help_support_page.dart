import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  final Color backgroundColor = const Color(0xFF11151C);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color surfaceColor = const Color(0xFF55768C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('AYUDA Y SOPORTE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
              "¿Necesitas ayuda?",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Estamos aquí para apoyarte en tu camino fitness. Si tienes problemas con la app o tus rutinas, contáctanos.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
            ),
            const SizedBox(height: 40),
            _buildContactCard(
              icon: Icons.email_outlined,
              title: "Correo Electrónico",
              subtitle: "soporte@yamanisfit.com",
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.message_outlined,
              title: "WhatsApp",
              subtitle: "+1 234 567 890",
              onTap: () {},
            ),
            const SizedBox(height: 40),
            const Text(
              "Preguntas Frecuentes",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFAQItem("¿Cómo activo mi cuenta?", "Contacta a tu trainer para que habilite tu acceso después de registrarte."),
            _buildFAQItem("¿Qué pasa si mi plan expira?", "Podrás seguir viendo tu perfil pero no tendrás acceso a las rutinas diarias hasta renovar."),
            _buildFAQItem("¿Cómo veo los videos?", "Haz clic en cualquier ejercicio de tu rutina diaria para abrir el reproductor."),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceColor.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5))),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(answer, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
