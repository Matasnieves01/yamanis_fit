import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/models/user_data_sheet.dart';

class BodyScanWidget extends StatelessWidget {
  final UserBiometrics? biometrics;
  final VoidCallback? onUpdatePressed;
  final VoidCallback? onQuickWeightPressed;

  const BodyScanWidget({
    super.key,
    required this.biometrics,
    this.onUpdatePressed,
    this.onQuickWeightPressed,
  });

  static const Color primaryColor = Color(0xFFAEE084);
  static const Color surfaceColor = Color(0xFF1E2838);
  static final Color cardBorderColor = Colors.white.withValues(alpha: 0.08);

  String _formatLastDate(DateTime? date) {
    if (date == null) return "Sin registro";
    try {
      return DateFormat("d MMM", "es").format(date);
    } catch (_) {
      return "${date.day}/${date.month}";
    }
  }

  Widget _buildMeasurementBadge({
    required String label,
    required String muscleGroup,
    required double? value,
    required double? delta,
    bool isWaist = false,
  }) {
    final hasValue = value != null && value > 0;
    final displayValue = hasValue ? "${value.toStringAsFixed(1)} cm" : "-- cm";

    String? deltaText;
    Color deltaColor = primaryColor;
    if (delta != null) {
      if (delta > 0) {
        deltaText = "+${delta.toStringAsFixed(1)}";
        deltaColor = primaryColor;
      } else if (delta < 0) {
        deltaText = delta.toStringAsFixed(1);
        deltaColor = isWaist ? primaryColor : Colors.orangeAccent;
      } else {
        deltaText = "0.0";
        deltaColor = Colors.white54;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? primaryColor.withValues(alpha: 0.45) : cardBorderColor,
          width: hasValue ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: hasValue ? primaryColor : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: hasValue ? primaryColor : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            muscleGroup,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                displayValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
              if (deltaText != null)
                Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = biometrics;
    final deltas = b?.previousDeltas ?? {};
    final hasWeight = b?.weight != null && b!.weight! > 0;
    final isDataComplete = b?.isComplete == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131B27),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header principal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.accessibility_new_rounded, color: primaryColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        "ANATOMÍA & MEDIDAS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatLastDate(b?.updatedAt),
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. HUD: Barra integrada con el PESO DEL USUARIO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF172230),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132219),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.monitor_weight_outlined, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PESO CORPORAL DEL USUARIO",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            hasWeight ? "${b!.weight!.toStringAsFixed(1)} kg" : "-- kg",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (b?.weightDelta != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (b!.weightDelta! <= 0 ? primaryColor : Colors.orangeAccent)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    b.weightDelta! < 0
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 10,
                                    color: b.weightDelta! <= 0 ? primaryColor : Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    "${b.weightDelta! > 0 ? '+' : ''}${b.weightDelta!.toStringAsFixed(1)} kg",
                                    style: TextStyle(
                                      color: b.weightDelta! <= 0 ? primaryColor : Colors.orangeAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (b?.height != null && b!.height! > 0)
                            Text(
                              "· Altura: ${b.height!.toStringAsFixed(0)} cm",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onQuickWeightPressed != null)
                  InkWell(
                    onTap: onQuickWeightPressed,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_calendar_rounded, size: 14, color: primaryColor),
                          SizedBox(width: 4),
                          Text(
                            "Registrar",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Diagrama Anatómico con Músculos y Puntos Señalizados
          SizedBox(
            height: 320,
            child: Row(
              children: [
                // Columna Izquierda: Bíceps, Cadera, Muslo
                Expanded(
                  flex: 8,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMeasurementBadge(
                        label: "Bíceps",
                        muscleGroup: "Brazo",
                        value: b?.biceps,
                        delta: deltas['biceps'],
                      ),
                      _buildMeasurementBadge(
                        label: "Cadera",
                        muscleGroup: "Glúteos / Pelvis",
                        value: b?.hips,
                        delta: deltas['hips'],
                      ),
                      _buildMeasurementBadge(
                        label: "Muslo",
                        muscleGroup: "Cuádriceps",
                        value: b?.thigh,
                        delta: deltas['thigh'],
                      ),
                    ],
                  ),
                ),

                // Centro: Esqueleto Anatómico con Músculos y Líneas Señalizadoras
                Expanded(
                  flex: 11,
                  child: CustomPaint(
                    size: const Size(double.infinity, 320),
                    painter: MuscularAnatomyChartPainter(
                      primaryColor: primaryColor,
                    ),
                  ),
                ),

                // Columna Derecha: Pecho, Cintura, Gemelo
                Expanded(
                  flex: 8,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMeasurementBadge(
                        label: "Pecho",
                        muscleGroup: "Pectoral / Tórax",
                        value: b?.chest,
                        delta: deltas['chest'],
                      ),
                      _buildMeasurementBadge(
                        label: "Cintura",
                        muscleGroup: "Abdomen / Core",
                        value: b?.waist,
                        delta: deltas['waist'],
                        isWaist: true,
                      ),
                      _buildMeasurementBadge(
                        label: "Gemelo",
                        muscleGroup: "Pantorrilla",
                        value: b?.calves,
                        delta: deltas['calves'],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Detalle complementario (Cuello) si existe
          if (b?.neck != null && b!.neck! > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  "Cuello: ${b.neck!.toStringAsFixed(1)} cm",
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 5. Botón de Actualizar Medidas
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onUpdatePressed,
              icon: const Icon(Icons.straighten_rounded, color: primaryColor, size: 18),
              label: Text(
                isDataComplete ? "ACTUALIZAR MEDIDAS & PESO" : "COMPLETAR FICHA DE MEDIDAS",
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: surfaceColor.withValues(alpha: 0.35),
                side: const BorderSide(color: primaryColor, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          // 6. Aviso si faltan datos oficiales
          if (!isDataComplete) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onUpdatePressed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Ficha incompleta. Toca aquí para registrar tus medidas oficiales.",
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter que dibuja un gráfico anatómico estático, nítido y claro:
/// Muestra los músculos definidos, el esqueleto óseo de soporte y líneas
/// señalizadoras directas que apuntan desde cada músculo a su correspondiente medida.
class MuscularAnatomyChartPainter extends CustomPainter {
  final Color primaryColor;

  const MuscularAnatomyChartPainter({
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final h = size.height;

    // Paleta de colores de precisión anatómica
    const boneColor = Color(0xFFA0CCF7);
    final darkBody = const Color(0xFF141E2A).withValues(alpha: 0.7);
    final muscleFill = primaryColor.withValues(alpha: 0.14);
    final muscleHighlight = primaryColor.withValues(alpha: 0.65);
    final boneStroke = boneColor.withValues(alpha: 0.85);

    final strokePaint = Paint()
      ..color = const Color(0xFF2C435A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = darkBody
      ..style = PaintingStyle.fill;

    final muscleFillPaint = Paint()
      ..color = muscleFill
      ..style = PaintingStyle.fill;

    final muscleLinePaint = Paint()
      ..color = muscleHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final bonePaint = Paint()
      ..color = boneStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // ==========================================
    // 1. SILUETA BASE DEL CUERPO HUMANO
    // ==========================================
    final bodyPath = Path();
    bodyPath.moveTo(cx - h * 0.022, h * 0.155);
    bodyPath.lineTo(cx - h * 0.075, h * 0.185); // Hombro izq

    // Brazo izquierdo
    bodyPath.lineTo(cx - h * 0.125, h * 0.28); // Bíceps exterior
    bodyPath.lineTo(cx - h * 0.138, h * 0.41); // Antebrazo
    bodyPath.lineTo(cx - h * 0.120, h * 0.48); // Muñeca
    bodyPath.lineTo(cx - h * 0.100, h * 0.40); // Antebrazo interior
    bodyPath.lineTo(cx - h * 0.070, h * 0.27); // Axila

    // Tronco y Cintura izquierda
    bodyPath.lineTo(cx - h * 0.060, h * 0.32); // Tórax
    bodyPath.lineTo(cx - h * 0.046, h * 0.42); // Cintura
    bodyPath.lineTo(cx - h * 0.062, h * 0.51); // Cadera

    // Pierna izquierda
    bodyPath.lineTo(cx - h * 0.058, h * 0.65); // Muslo exterior
    bodyPath.lineTo(cx - h * 0.046, h * 0.74); // Rodilla
    bodyPath.lineTo(cx - h * 0.042, h * 0.86); // Gemelo
    bodyPath.lineTo(cx - h * 0.030, h * 0.95); // Tobillo
    bodyPath.lineTo(cx - h * 0.015, h * 0.95); // Pie
    bodyPath.lineTo(cx - h * 0.015, h * 0.56); // Entrepierna

    bodyPath.lineTo(cx, h * 0.53); // Ingle

    // Pierna derecha
    bodyPath.lineTo(cx + h * 0.015, h * 0.56);
    bodyPath.lineTo(cx + h * 0.015, h * 0.95);
    bodyPath.lineTo(cx + h * 0.030, h * 0.95);
    bodyPath.lineTo(cx + h * 0.042, h * 0.86);
    bodyPath.lineTo(cx + h * 0.046, h * 0.74);
    bodyPath.lineTo(cx + h * 0.058, h * 0.65);

    // Tronco y Cintura derecha
    bodyPath.lineTo(cx + h * 0.062, h * 0.51);
    bodyPath.lineTo(cx + h * 0.046, h * 0.42);
    bodyPath.lineTo(cx + h * 0.060, h * 0.32);

    // Brazo derecho
    bodyPath.lineTo(cx + h * 0.070, h * 0.27);
    bodyPath.lineTo(cx + h * 0.100, h * 0.40);
    bodyPath.lineTo(cx + h * 0.120, h * 0.48);
    bodyPath.lineTo(cx + h * 0.138, h * 0.41);
    bodyPath.lineTo(cx + h * 0.125, h * 0.28);
    bodyPath.lineTo(cx + h * 0.075, h * 0.185);

    // Cuello
    bodyPath.lineTo(cx + h * 0.022, h * 0.155);
    bodyPath.close();

    canvas.drawPath(bodyPath, fillPaint);
    canvas.drawPath(bodyPath, strokePaint);

    // Cabeza / Cráneo estilizado
    final headRect = Rect.fromCenter(
      center: Offset(cx, h * 0.085),
      width: h * 0.075,
      height: h * 0.095,
    );
    canvas.drawOval(headRect, fillPaint);
    canvas.drawOval(headRect, strokePaint);

    // ==========================================
    // 2. ESQUELETO ÓSEO DE SOPORTE
    // ==========================================
    // Clavículas
    final clavicleLeft = Path()
      ..moveTo(cx - h * 0.006, h * 0.17)
      ..quadraticBezierTo(cx - h * 0.05, h * 0.165, cx - h * 0.09, h * 0.185);
    final clavicleRight = Path()
      ..moveTo(cx + h * 0.006, h * 0.17)
      ..quadraticBezierTo(cx + h * 0.05, h * 0.165, cx + h * 0.09, h * 0.185);
    canvas.drawPath(clavicleLeft, bonePaint..strokeWidth = 1.4);
    canvas.drawPath(clavicleRight, bonePaint);

    // Esternón
    canvas.drawLine(
      Offset(cx, h * 0.17),
      Offset(cx, h * 0.27),
      bonePaint..strokeWidth = 2.0,
    );

    // Costillas
    for (int i = 0; i < 4; i++) {
      final yStart = h * (0.195 + i * 0.024);
      final yCurve = h * (0.210 + i * 0.026);
      final ribSpread = h * (0.050 - i * 0.003);

      final ribL = Path()
        ..moveTo(cx - h * 0.006, yStart)
        ..quadraticBezierTo(cx - ribSpread * 0.7, yStart + h * 0.005, cx - ribSpread, yCurve);
      canvas.drawPath(ribL, bonePaint..strokeWidth = 0.9);

      final ribR = Path()
        ..moveTo(cx + h * 0.006, yStart)
        ..quadraticBezierTo(cx + ribSpread * 0.7, yStart + h * 0.005, cx + ribSpread, yCurve);
      canvas.drawPath(ribR, bonePaint);
    }

    // Columna vertebral (Spine)
    final spinePaint = Paint()
      ..color = boneColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (double y = h * 0.28; y <= h * 0.46; y += h * 0.022) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + h * 0.012), spinePaint);
    }

    // Pelvis / Cresta Ilíaca
    final pelvisPath = Path()
      ..moveTo(cx - h * 0.055, h * 0.46)
      ..quadraticBezierTo(cx - h * 0.06, h * 0.50, cx, h * 0.525)
      ..quadraticBezierTo(cx + h * 0.06, h * 0.50, cx + h * 0.055, h * 0.46);
    canvas.drawPath(pelvisPath, bonePaint..strokeWidth = 1.4);

    // Rótulas / Rodillas
    canvas.drawCircle(Offset(cx - h * 0.046, h * 0.74), h * 0.012, bonePaint..strokeWidth = 1.1);
    canvas.drawCircle(Offset(cx + h * 0.046, h * 0.74), h * 0.012, bonePaint);

    // ==========================================
    // 3. MÚSCULOS DEFINIDOS Y VISIBLES
    // ==========================================
    // Pectorales Mayores (Pecho)
    final leftPec = Path()
      ..moveTo(cx - h * 0.006, h * 0.18)
      ..lineTo(cx - h * 0.006, h * 0.26)
      ..quadraticBezierTo(cx - h * 0.045, h * 0.265, cx - h * 0.065, h * 0.235)
      ..lineTo(cx - h * 0.065, h * 0.185)
      ..close();
    final rightPec = Path()
      ..moveTo(cx + h * 0.006, h * 0.18)
      ..lineTo(cx + h * 0.006, h * 0.26)
      ..quadraticBezierTo(cx + h * 0.045, h * 0.265, cx + h * 0.065, h * 0.235)
      ..lineTo(cx + h * 0.065, h * 0.185)
      ..close();
    canvas.drawPath(leftPec, muscleFillPaint);
    canvas.drawPath(leftPec, muscleLinePaint);
    canvas.drawPath(rightPec, muscleFillPaint);
    canvas.drawPath(rightPec, muscleLinePaint);

    // Abdominales / Recto Abdominal (Six-Pack)
    for (int r = 0; r < 3; r++) {
      final yTop = h * (0.28 + r * 0.052);
      final wAbs = h * (0.024 - r * 0.002);
      final hAbs = h * 0.042;

      final absL = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - wAbs - h * 0.005, yTop, wAbs, hAbs),
        const Radius.circular(3),
      );
      final absR = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + h * 0.005, yTop, wAbs, hAbs),
        const Radius.circular(3),
      );

      canvas.drawRRect(absL, muscleFillPaint);
      canvas.drawRRect(absL, muscleLinePaint..strokeWidth = 1.0);
      canvas.drawRRect(absR, muscleFillPaint);
      canvas.drawRRect(absR, muscleLinePaint);
    }

    // Oblicuos (Flancos)
    final obliquesL = Path()
      ..moveTo(cx - h * 0.050, h * 0.35)
      ..quadraticBezierTo(cx - h * 0.042, h * 0.41, cx - h * 0.038, h * 0.45);
    final obliquesR = Path()
      ..moveTo(cx + h * 0.050, h * 0.35)
      ..quadraticBezierTo(cx + h * 0.042, h * 0.41, cx + h * 0.038, h * 0.45);
    canvas.drawPath(obliquesL, muscleLinePaint);
    canvas.drawPath(obliquesR, muscleLinePaint);

    // Deltoides (Hombros)
    final deltL = Path()
      ..moveTo(cx - h * 0.08, h * 0.185)
      ..quadraticBezierTo(cx - h * 0.125, h * 0.21, cx - h * 0.11, h * 0.26);
    final deltR = Path()
      ..moveTo(cx + h * 0.08, h * 0.185)
      ..quadraticBezierTo(cx + h * 0.125, h * 0.21, cx + h * 0.11, h * 0.26);
    canvas.drawPath(deltL, muscleLinePaint..strokeWidth = 1.2);
    canvas.drawPath(deltR, muscleLinePaint);

    // Bíceps (Vientre muscular de los brazos)
    final bicepL = Path()
      ..moveTo(cx - h * 0.105, h * 0.26)
      ..quadraticBezierTo(cx - h * 0.122, h * 0.32, cx - h * 0.095, h * 0.37);
    final bicepR = Path()
      ..moveTo(cx + h * 0.105, h * 0.26)
      ..quadraticBezierTo(cx + h * 0.122, h * 0.32, cx + h * 0.095, h * 0.37);
    canvas.drawPath(bicepL, muscleLinePaint..strokeWidth = 1.4);
    canvas.drawPath(bicepR, muscleLinePaint);

    // Cuádriceps (Recto femoral y Vasto medial)
    canvas.drawLine(
      Offset(cx - h * 0.042, h * 0.55),
      Offset(cx - h * 0.042, h * 0.69),
      muscleLinePaint..strokeWidth = 1.3,
    );
    final vastusL = Path()
      ..moveTo(cx - h * 0.025, h * 0.66)
      ..quadraticBezierTo(cx - h * 0.038, h * 0.70, cx - h * 0.040, h * 0.72);
    canvas.drawPath(vastusL, muscleLinePaint);

    canvas.drawLine(
      Offset(cx + h * 0.042, h * 0.55),
      Offset(cx + h * 0.042, h * 0.69),
      muscleLinePaint,
    );
    final vastusR = Path()
      ..moveTo(cx + h * 0.025, h * 0.66)
      ..quadraticBezierTo(cx + h * 0.038, h * 0.70, cx + h * 0.040, h * 0.72);
    canvas.drawPath(vastusR, muscleLinePaint);

    // Gemelos / Pantorrillas
    final calfL = Path()
      ..moveTo(cx - h * 0.042, h * 0.77)
      ..quadraticBezierTo(cx - h * 0.052, h * 0.83, cx - h * 0.034, h * 0.89);
    final calfR = Path()
      ..moveTo(cx + h * 0.042, h * 0.77)
      ..quadraticBezierTo(cx + h * 0.052, h * 0.83, cx + h * 0.034, h * 0.89);
    canvas.drawPath(calfL, muscleLinePaint..strokeWidth = 1.3);
    canvas.drawPath(calfR, muscleLinePaint);

    // ==========================================
    // 4. LÍNEAS SEÑALIZADORAS CLARAS Y DIRECTAS
    // ==========================================
    // Posiciones de destino hacia las tarjetas laterales
    final targetY1 = h * 0.18; // Fila 1: Bíceps / Pecho
    final targetY2 = h * 0.50; // Fila 2: Cadera / Cintura
    final targetY3 = h * 0.82; // Fila 3: Muslo / Gemelo

    // A. Señalizador BÍCEPS (Brazo izquierdo -> Tarjeta izquierda)
    _drawMuscleCallout(
      canvas: canvas,
      musclePoint: Offset(cx - h * 0.115, h * 0.31),
      midPoint: Offset(cx - h * 0.145, targetY1),
      endPoint: Offset(0, targetY1),
      isLeft: true,
    );

    // B. Señalizador CADERA / GLÚTEOS (Pelvis izquierda -> Tarjeta izquierda)
    _drawMuscleCallout(
      canvas: canvas,
      musclePoint: Offset(cx - h * 0.055, h * 0.49),
      midPoint: Offset(cx - h * 0.080, targetY2),
      endPoint: Offset(0, targetY2),
      isLeft: true,
    );

    // C. Señalizador MUSLO / CUÁDRICEPS (Muslo izquierdo -> Tarjeta izquierda)
    _drawMuscleCallout(
      canvas: canvas,
      musclePoint: Offset(cx - h * 0.045, h * 0.63),
      midPoint: Offset(cx - h * 0.075, targetY3),
      endPoint: Offset(0, targetY3),
      isLeft: true,
    );

    // D. Señalizador PECHO / PECTORAL (Pectoral derecho -> Tarjeta derecha)
    _drawMuscleCallout(
      canvas: canvas,
      musclePoint: Offset(cx + h * 0.038, h * 0.22),
      midPoint: Offset(cx + h * 0.075, targetY1),
      endPoint: Offset(size.width, targetY1),
      isLeft: false,
    );

    // E. Señalizador CINTURA / CORE (Abdomen derecho -> Tarjeta derecha)
    _drawMuscleCallout(
      canvas: canvas,
      musclePoint: Offset(cx + h * 0.028, h * 0.39),
      midPoint: Offset(cx + h * 0.065, targetY2),
      endPoint: Offset(size.width, targetY2),
      isLeft: false,
    );

    // F. Señalizador GEMELO / PANTORRILLA (Gemelo derecho -> Tarjeta derecha)
    _drawMuscleCallout(
      canvas: canvas,
      musclePoint: Offset(cx + h * 0.042, h * 0.83),
      midPoint: Offset(cx + h * 0.075, targetY3),
      endPoint: Offset(size.width, targetY3),
      isLeft: false,
    );
  }

  /// Dibuja un pin diana sobre el músculo y una línea señalizadora quebrada directa hacia la tarjeta
  void _drawMuscleCallout({
    required Canvas canvas,
    required Offset musclePoint,
    required Offset midPoint,
    required Offset endPoint,
    required bool isLeft,
  }) {
    final leaderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final targetOuterPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final targetInnerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    // 1. Pin diana sobre el músculo exacto
    canvas.drawCircle(musclePoint, 5.0, targetOuterPaint);
    canvas.drawCircle(musclePoint, 2.5, targetInnerPaint);

    // 2. Línea señalizadora con quiebre anatómico técnico
    final path = Path()
      ..moveTo(musclePoint.dx, musclePoint.dy)
      ..lineTo(midPoint.dx, midPoint.dy)
      ..lineTo(endPoint.dx, endPoint.dy);
    canvas.drawPath(path, leaderPaint);

    // 3. Punto terminal junto a la tarjeta
    canvas.drawCircle(endPoint, 2.0, targetInnerPaint);
  }

  @override
  bool shouldRepaint(covariant MuscularAnatomyChartPainter oldDelegate) {
    return false; // Gráfico estático nítido sin animaciones
  }
}
