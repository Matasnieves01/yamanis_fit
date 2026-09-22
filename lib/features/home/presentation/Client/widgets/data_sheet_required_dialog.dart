import 'package:flutter/material.dart';

class DataSheetRequiredDialog extends StatelessWidget {
  final String? customTitle;
  final String? customSubtitle;
  final bool isForRoutineRequest;

  const DataSheetRequiredDialog({
    super.key,
    this.customTitle,
    this.customSubtitle,
    this.isForRoutineRequest = false,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFAEE084);
    const surfaceDark = Color(0xFF151A24);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.28),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Radiant Icon Badge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.32),
                            blurRadius: 26,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E2838),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.65),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.assignment_late_rounded,
                        color: primaryColor,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 13,
                        color: primaryColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "DATOS OBLIGATORIOS",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  customTitle ?? "¡Completa tu Planilla de Datos!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  customSubtitle ??
                      (isForRoutineRequest
                          ? "Para poder solicitar o recibir tu plan de entrenamiento personalizado, tu entrenadora necesita conocer tus medidas corporales y tu estado de salud."
                          : "Para que tu entrenadora pueda conocer tus antecedentes médicos, lesiones y diseñar tu plan 100% personalizado y seguro, es necesario registrar tus medidas y responder la encuesta."),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Checklist Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildCheckItem(
                        icon: Icons.straighten_rounded,
                        title: "Medidas Corporales",
                        description: "Peso, altura, cintura, brazos, muslos y zonas clave.",
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1,
                        ),
                      ),
                      _buildCheckItem(
                        icon: Icons.health_and_safety_rounded,
                        title: "Encuesta Médica y Hábitos",
                        description: "Condición de salud, lesiones, medicación, nivel físico y metas.",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Warning reminder
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Solo podrás solicitar o recibir rutinas una vez completada tu planilla.",
                        style: TextStyle(
                          color: Colors.orangeAccent.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Primary CTA button (Realizar)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "REALIZAR AHORA",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Secondary CTA button (Rellenar luego)
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      "Rellenar luego",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    const primaryColor = Color(0xFFAEE084);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
