import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamanis_fit/features/home/presentation/Client/data_sheet_page.dart';

/// Diálogo de felicitación cuando el usuario completa todos los ejercicios de su plan.
/// Informa la sugerencia de volverse a tomar las medidas (opcional) para evaluar el progreso.
class PlanCompletedDialog extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback? onDismiss;

  const PlanCompletedDialog({
    super.key,
    this.primaryColor = const Color(0xFFAEE084),
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141A22),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge / Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.25),
                    primaryColor.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: primaryColor,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title
            const Text(
              '¡FELICITACIONES!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            Text(
              'Has completado todos los ejercicios',
              style: TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Body text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.straighten_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¿Quieres ver tu evolución?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Te recomendamos volverte a tomar las medidas para que puedas ver y comparar tu progreso físico con el paso del tiempo.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Nota explícita de opcional
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Volverse a medir es totalmente opcional.',
                            style: TextStyle(
                              color: Colors.amber.shade200,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Botón principal: Tomar medidas
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onDismiss?.call();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataSheetPage(
                        isRequiredForRoutine: false,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.straighten_rounded,
                  color: Color(0xFF11151C),
                  size: 20,
                ),
                label: const Text(
                  'TOMAR MEDIDAS AHORA',
                  style: TextStyle(
                    color: Color(0xFF11151C),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 6,
                  shadowColor: primaryColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Botón secundario: Más tarde
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDismiss?.call();
                },
                child: Text(
                  'MÁS TARDE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo informativo cuando los ejercicios están bloqueados por haber superado
/// las semanas del plan y la semana adicional de gracia sin completarlos.
class PlanBlockedDialog extends StatelessWidget {
  final VoidCallback? onRenewWhatsApp;

  const PlanBlockedDialog({
    super.key,
    this.onRenewWhatsApp,
  });

  static Future<void> defaultOpenWhatsApp(BuildContext context) async {
    const phone = '50769184836';
    final message = Uri.encodeComponent(
      'Hola! Mi plan de rutina y semana adicional han expirado. Quiero renovar mi suscripción para continuar entrenando.',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141A22),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.25),
                    Colors.redAccent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_clock_rounded,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'EJERCICIOS BLOQUEADOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Período del plan y semana de gracia finalizados',
              style: TextStyle(
                color: Colors.redAccent.shade100,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                'Han transcurrido las semanas de tu plan y la semana adicional concedida para completar tus ejercicios pendientes. Para continuar entrenando y desbloquear nuevas rutinas, renueva tu suscripción con tu coach.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (onRenewWhatsApp != null) {
                    onRenewWhatsApp!();
                  } else {
                    defaultOpenWhatsApp(context);
                  }
                },
                icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'RENOVAR POR WHATSAPP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  elevation: 6,
                  shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'ENTENDIDO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
