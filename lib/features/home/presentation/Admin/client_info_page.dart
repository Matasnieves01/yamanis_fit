import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/client_routines_page.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/client_tracking_sheet_page.dart';
import 'package:yamanis_fit/features/home/presentation/Client/widgets/body_scan_widget.dart';
import 'package:yamanis_fit/models/user_data_sheet.dart';

class ClientInfoPage extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientEmail;

  const ClientInfoPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
  });

  @override
  State<ClientInfoPage> createState() => _ClientInfoPageState();
}

class _ClientInfoPageState extends State<ClientInfoPage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161F2C);
  final Color surfaceColor = const Color(0xFF1E2838);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color accentAmber = const Color(0xFFFFB74D);

  bool _isLoading = true;
  UserDataSheet? _dataSheet;
  Map<String, dynamic>? _userDocData;

  @override
  void initState() {
    super.initState();
    _loadClientInfo();
  }

  Future<void> _loadClientInfo() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BiometricsService.getDataSheet(widget.clientId),
        FirebaseFirestore.instance.collection('users').doc(widget.clientId).get(),
      ]);

      if (mounted) {
        setState(() {
          _dataSheet = results[0] as UserDataSheet?;
          final doc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
          _userDocData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ficha del cliente: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Sin registro";
    try {
      return DateFormat("d 'de' MMMM, yyyy", "es").format(date);
    } catch (_) {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  double? _calculateBMI(double? weight, double? height) {
    if (weight == null || height == null || weight <= 0 || height <= 0) return null;
    final hInMeters = height / 100.0;
    return weight / (hInMeters * hInMeters);
  }

  MapEntry<String, Color> _getBmiCategory(double bmi) {
    if (bmi < 18.5) return const MapEntry("Bajo peso", Colors.blueAccent);
    if (bmi < 25.0) return MapEntry("Peso saludable", primaryColor);
    if (bmi < 30.0) return const MapEntry("Sobrepeso", Colors.orangeAccent);
    return const MapEntry("Obesidad", Colors.redAccent);
  }

  @override
  Widget build(BuildContext context) {
    final bio = _dataSheet?.biometrics;
    final assess = _dataSheet?.assessment;
    final hasSheet = _dataSheet != null && _dataSheet!.isComplete;
    final bmi = _calculateBMI(bio?.weight, bio?.height);

    final isActive = _userDocData?['isActive'] == true;
    final activeUntilTs = _userDocData?['activeUntil'] as Timestamp?;
    final activeUntil = activeUntilTs?.toDate();
    final isActiveNow = isActive && activeUntil != null && activeUntil.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        centerTitle: true,
        title: const Text(
          "FICHA DEL CLIENTE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Color(0xFFFDA4AF)),
            tooltip: "Tabla de Registro & Series",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientTrackingSheetPage(
                    clientId: widget.clientId,
                    clientName: widget.clientName,
                    clientEmail: widget.clientEmail,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: "Actualizar",
            onPressed: _loadClientInfo,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tarjeta Resumen del Cliente
                  _buildClientHeaderCard(isActiveNow, activeUntil),

                  const SizedBox(height: 16),

                  // Alerta si la planilla está incompleta
                  if (!hasSheet)
                    _buildPendingDataAlert(),

                  const SizedBox(height: 16),

                  // 2. SECCIÓN: ESQUELETO Y MEDIDAS ANATÓMICAS
                  _buildSectionHeader(
                    title: "ANATOMÍA & MEDIDAS DEL CLIENTE",
                    subtitle: "Esqueleto anatómico y medidas antropométricas registradas",
                    icon: Icons.accessibility_new_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Esqueleto interactivo de medidas
                  BodyScanWidget(
                    biometrics: bio,
                  ),

                  const SizedBox(height: 16),

                  // Resumen de Métricas Clave (IMC, Cintura, Bíceps, Muslo, etc.)
                  if (bio != null) _buildKeyMetricsGrid(bio, bmi),

                  const SizedBox(height: 24),

                  // 3. SECCIÓN: ENCUESTA DE SALUD Y ANTECEDENTES
                  _buildSectionHeader(
                    title: "SALUD & ANTECEDENTES MÉDICOS",
                    subtitle: "Historial clínico, cirugías, lesiones y medicación habitual",
                    icon: Icons.health_and_safety_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildHealthQuestions(assess),

                  const SizedBox(height: 24),

                  // 4. SECCIÓN: ESTILO DE VIDA Y HÁBITOS
                  _buildSectionHeader(
                    title: "ESTILO DE VIDA & ALIMENTACIÓN",
                    subtitle: "Nivel de actividad, horas de descanso y patrón de alimentación",
                    icon: Icons.restaurant_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildLifestyleQuestions(assess),

                  const SizedBox(height: 24),

                  // 5. SECCIÓN: ENTRENAMIENTO Y METAS
                  _buildSectionHeader(
                    title: "OBJETIVOS & ENTRENAMIENTO",
                    subtitle: "Experiencia, días disponibles, metas y motivaciones",
                    icon: Icons.emoji_events_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildTrainingQuestions(assess),

                  const SizedBox(height: 32),

                  // Botón de acción: Ir a la Tabla de Registro & Contador Muscular
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientTrackingSheetPage(
                              clientId: widget.clientId,
                              clientName: widget.clientName,
                              clientEmail: widget.clientEmail,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.table_chart_rounded),
                      label: const Text(
                        "TABLA DE REGISTRO & CONTADOR MUSCULAR",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF881337),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF881337).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFFDA4AF), width: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botón de acción: Ir al Calendario y Rutinas del Cliente
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientRoutinesPage(
                              clientId: widget.clientId,
                              clientName: widget.clientName,
                              clientEmail: widget.clientEmail,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text(
                        "GESTIONAR RUTINAS & CALENDARIO",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: backgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildClientHeaderCard(bool isActiveNow, DateTime? activeUntil) {
    final nameParts = widget.clientName.trim().split(' ');
    String initials = "CL";
    if (nameParts.length >= 2) {
      initials = "${nameParts[0][0]}${nameParts[1][0]}".toUpperCase();
    } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      initials = nameParts[0].substring(0, nameParts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clientName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.clientEmail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActiveNow
                            ? primaryColor.withValues(alpha: 0.15)
                            : Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActiveNow
                              ? primaryColor.withValues(alpha: 0.3)
                              : Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        isActiveNow ? "MEMBRESÍA ACTIVA" : "MEMBRESÍA EXPIRADA",
                        style: TextStyle(
                          color: isActiveNow ? primaryColor : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (activeUntil != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "Hasta ${_formatDate(activeUntil)}",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDataAlert() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.assignment_late_outlined, color: Colors.amber, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ficha y Encuestas Pendientes",
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Este cliente aún no ha completado la totalidad de sus medidas corporales o encuesta de salud. Los campos que no hayan sido respondidos se mostrarán vacíos.",
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMetricsGrid(UserBiometrics bio, double? bmi) {
    return Column(
      children: [
        Row(
          children: [
            if (bmi != null) ...[
              Expanded(
                child: _buildMetricTile(
                  label: "IMC (Índice Masa)",
                  value: bmi.toStringAsFixed(1),
                  unit: _getBmiCategory(bmi).key,
                  accentColor: _getBmiCategory(bmi).value,
                  icon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _buildMetricTile(
                label: "Edad",
                value: bio.age != null ? "${bio.age}" : "--",
                unit: "años",
                accentColor: primaryColor,
                icon: Icons.cake_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                label: "Estatura",
                value: bio.height != null ? bio.height!.toStringAsFixed(0) : "--",
                unit: "cm",
                accentColor: primaryColor,
                icon: Icons.height_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: accentColor, size: 14),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthQuestions(HealthLifestyleAssessment? a) {
    return Column(
      children: [
        _buildSurveyCard(
          question: "¿Tienes alguna condición de salud?",
          hint: "SOP, hipotiroidismo, síndrome metabólico, asma, diabetes, convulsiones, otros.",
          answer: a?.healthConditions,
          icon: Icons.coronavirus_outlined,
          isAlert: a?.healthConditions != null &&
              a!.healthConditions.trim().isNotEmpty &&
              a.healthConditions.trim().toLowerCase() != 'no' &&
              a.healthConditions.trim().toLowerCase() != 'ninguna',
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "Antecedentes quirúrgicos",
          hint: "¿Fue operado alguna vez? Detalle de cirugía y fecha.",
          answer: a?.surgicalHistory,
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "¿Tienes alguna lesión o limitación?",
          hint: "Lesiones que no permitan realizar ejercicio o requieran modificaciones específicas.",
          answer: a?.injuries,
          icon: Icons.healing_outlined,
          isAlert: a?.injuries != null &&
              a!.injuries.trim().isNotEmpty &&
              a.injuries.trim().toLowerCase() != 'no' &&
              a.injuries.trim().toLowerCase() != 'ninguna',
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "¿Toma medicación de manera habitual o tratamiento?",
          hint: "Fármacos, suplementos recetados o tratamientos continuos.",
          answer: a?.medications,
          icon: Icons.medication_outlined,
        ),
      ],
    );
  }

  Widget _buildLifestyleQuestions(HealthLifestyleAssessment? a) {
    return Column(
      children: [
        _buildSurveyCard(
          question: "¿Cómo es tu nivel de actividad física actualmente?",
          hint: "Sedentario / Leve / Moderado / Activo / Deporte",
          answer: a?.physicalActivityLevel,
          icon: Icons.directions_run_outlined,
          badgeColor: primaryColor,
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "¿Cuántas horas duerme en promedio por la noche?",
          hint: "Tiempo promedio de descanso nocturno",
          answer: a?.sleepHours,
          icon: Icons.nightlight_outlined,
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "¿Cómo es tu alimentación normalmente?",
          hint: "Descripción detallada de comidas de la mayoría de los días",
          answer: a?.dietDescription,
          icon: Icons.restaurant_menu_rounded,
        ),
      ],
    );
  }

  Widget _buildTrainingQuestions(HealthLifestyleAssessment? a) {
    return Column(
      children: [
        _buildSurveyCard(
          question: "Experiencia previa entrenando",
          hint: "¿Ha entrenado fuerza, hipertrofia o funcional antes?",
          answer: a?.trainingExperience,
          icon: Icons.fitness_center_outlined,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSurveyCard(
                question: "Lugar de entrenamiento",
                hint: "Gimnasio o Casa",
                answer: a?.trainingLocation,
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSurveyCard(
                question: "Días disponibles",
                hint: "Frecuencia semanal",
                answer: a?.trainingDaysPerWeek,
                icon: Icons.date_range_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "Objetivos principales",
          hint: "¿Qué busca lograr con su plan?",
          answer: a?.trainingGoals,
          icon: Icons.track_changes_rounded,
          badgeColor: primaryColor,
        ),
        const SizedBox(height: 10),
        _buildSurveyCard(
          question: "¿Cuál es tu mayor motivación?",
          hint: "Propósito personal o razón de cambio",
          answer: a?.motivation,
          icon: Icons.local_fire_department_outlined,
        ),
        if (a?.extraComments != null && a!.extraComments.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSurveyCard(
            question: "Comentarios o aclaraciones adicionales",
            hint: "Mensaje directo para la entrenadora",
            answer: a.extraComments,
            icon: Icons.chat_bubble_outline_rounded,
          ),
        ],
      ],
    );
  }

  Widget _buildSurveyCard({
    required String question,
    required String hint,
    required String? answer,
    required IconData icon,
    bool isAlert = false,
    Color? badgeColor,
  }) {
    final hasAnswer = answer != null && answer.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert
            ? Colors.redAccent.withValues(alpha: 0.08)
            : cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? Colors.redAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.07),
          width: isAlert ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isAlert ? Colors.redAccent : (badgeColor ?? primaryColor),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    color: isAlert ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "ATENCIÓN",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasAnswer
                    ? (isAlert ? Colors.redAccent.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.2))
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Text(
              hasAnswer ? answer : "No especificado / Sin respuesta",
              style: TextStyle(
                color: hasAnswer ? Colors.white : Colors.white38,
                fontSize: 13,
                height: 1.4,
                fontStyle: hasAnswer ? FontStyle.normal : FontStyle.italic,
                fontWeight: hasAnswer ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
