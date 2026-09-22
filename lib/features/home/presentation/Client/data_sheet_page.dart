import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/models/user_data_sheet.dart';

class DataSheetPage extends StatefulWidget {
  final bool isRequiredForRoutine;

  const DataSheetPage({
    super.key,
    this.isRequiredForRoutine = false,
  });

  @override
  State<DataSheetPage> createState() => _DataSheetPageState();
}

class _DataSheetPageState extends State<DataSheetPage> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers - Sección 1: Medidas
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _neckController = TextEditingController();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipsController = TextEditingController();
  final _bicepsController = TextEditingController();
  final _thighController = TextEditingController();
  final _calvesController = TextEditingController();

  // Controllers - Sección 2: Salud
  final _healthConditionsController = TextEditingController();
  final _surgicalHistoryController = TextEditingController();
  final _injuriesController = TextEditingController();
  final _medicationsController = TextEditingController();

  // Controllers - Sección 3: Estilo de Vida
  String? _selectedActivityLevel;
  final _otherActivityController = TextEditingController();
  final _sleepHoursController = TextEditingController();
  final _dietController = TextEditingController();

  // Controllers - Sección 4: Experiencia y Objetivos
  final _trainingExperienceController = TextEditingController();
  String? _selectedLocation;
  String? _selectedDaysPerWeek;
  final _goalsController = TextEditingController();
  final _motivationController = TextEditingController();
  final _extraCommentsController = TextEditingController();

  String _userEmail = '';
  String _userName = '';

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF192230);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color accentPink = const Color(0xFFD81B60);

  final List<String> _activityLevels = [
    'Sedentario: no hago ningún tipo de actividad física',
    'Leve: no hago actividad física pero por mi trabajo estoy varias horas en movimiento',
    'Moderado: mínimo 3 días a la semana realizo actividad física',
    'Activo: mínimo 5 días a la semana realizo actividad física',
    'Practico un deporte',
    'Otro',
  ];

  final List<String> _trainingLocations = [
    'Casa o al aire libre',
    'Gimnasio',
  ];

  final List<String> _daysOptions = ['2 días', '3 días', '4 días', '5 días', '6 días', 'Todos los días'];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _neckController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    _bicepsController.dispose();
    _thighController.dispose();
    _calvesController.dispose();
    _healthConditionsController.dispose();
    _surgicalHistoryController.dispose();
    _injuriesController.dispose();
    _medicationsController.dispose();
    _otherActivityController.dispose();
    _sleepHoursController.dispose();
    _dietController.dispose();
    _trainingExperienceController.dispose();
    _goalsController.dispose();
    _motivationController.dispose();
    _extraCommentsController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _userEmail = user.email ?? '';
    _userName = user.displayName ?? '';

    try {
      final sheet = await BiometricsService.getDataSheet(user.uid);
      if (sheet != null && mounted) {
        final b = sheet.biometrics;
        final a = sheet.assessment;

        if (b.age != null) _ageController.text = b.age.toString();
        if (b.weight != null) _weightController.text = b.weight!.toStringAsFixed(1);
        if (b.height != null) _heightController.text = b.height!.toStringAsFixed(1);
        if (b.neck != null) _neckController.text = b.neck!.toStringAsFixed(1);
        if (b.chest != null) _chestController.text = b.chest!.toStringAsFixed(1);
        if (b.waist != null) _waistController.text = b.waist!.toStringAsFixed(1);
        if (b.hips != null) _hipsController.text = b.hips!.toStringAsFixed(1);
        if (b.biceps != null) _bicepsController.text = b.biceps!.toStringAsFixed(1);
        if (b.thigh != null) _thighController.text = b.thigh!.toStringAsFixed(1);
        if (b.calves != null) _calvesController.text = b.calves!.toStringAsFixed(1);

        _healthConditionsController.text = a.healthConditions;
        _surgicalHistoryController.text = a.surgicalHistory;
        _injuriesController.text = a.injuries;
        _medicationsController.text = a.medications;

        if (_activityLevels.contains(a.physicalActivityLevel)) {
          _selectedActivityLevel = a.physicalActivityLevel;
        } else if (a.physicalActivityLevel.isNotEmpty) {
          _selectedActivityLevel = 'Otro';
          _otherActivityController.text = a.physicalActivityLevel;
        }

        _sleepHoursController.text = a.sleepHours;
        _dietController.text = a.dietDescription;
        _trainingExperienceController.text = a.trainingExperience;

        if (_trainingLocations.contains(a.trainingLocation)) {
          _selectedLocation = a.trainingLocation;
        }

        if (_daysOptions.contains(a.trainingDaysPerWeek)) {
          _selectedDaysPerWeek = a.trainingDaysPerWeek;
        }

        _goalsController.text = a.trainingGoals;
        _motivationController.text = a.motivation;
        _extraCommentsController.text = a.extraComments;
      }
    } catch (e) {
      debugPrint("Error loading data sheet: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _parse(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos obligatorios (*)'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedActivityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona tu nivel de actividad física actual'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, indica si entrenarías en casa o gimnasio'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedDaysPerWeek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, indica cuántos días a la semana podrás entrenar'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final activity = _selectedActivityLevel == 'Otro'
          ? _otherActivityController.text.trim()
          : _selectedActivityLevel!;

      final biometrics = UserBiometrics(
        age: int.tryParse(_ageController.text.trim()),
        weight: _parse(_weightController.text),
        height: _parse(_heightController.text),
        neck: _parse(_neckController.text),
        chest: _parse(_chestController.text),
        waist: _parse(_waistController.text),
        hips: _parse(_hipsController.text),
        biceps: _parse(_bicepsController.text),
        thigh: _parse(_thighController.text),
        calves: _parse(_calvesController.text),
        updatedAt: DateTime.now(),
      );

      final assessment = HealthLifestyleAssessment(
        healthConditions: _healthConditionsController.text.trim(),
        surgicalHistory: _surgicalHistoryController.text.trim(),
        injuries: _injuriesController.text.trim(),
        medications: _medicationsController.text.trim(),
        physicalActivityLevel: activity,
        sleepHours: _sleepHoursController.text.trim(),
        dietDescription: _dietController.text.trim(),
        trainingExperience: _trainingExperienceController.text.trim(),
        trainingLocation: _selectedLocation!,
        trainingDaysPerWeek: _selectedDaysPerWeek!,
        trainingGoals: _goalsController.text.trim(),
        motivation: _motivationController.text.trim(),
        extraComments: _extraCommentsController.text.trim(),
      );

      final dataSheet = UserDataSheet(
        userId: user.uid,
        fullName: _userName.isNotEmpty ? _userName : (user.displayName ?? 'Usuario'),
        email: _userEmail.isNotEmpty ? _userEmail : (user.email ?? ''),
        biometrics: biometrics,
        assessment: assessment,
        isComplete: true,
        updatedAt: DateTime.now(),
      );

      await BiometricsService.saveDataSheet(user.uid, dataSheet);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.black),
              SizedBox(width: 8),
              Expanded(child: Text('¡Planilla de Datos guardada exitosamente!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            ],
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMeasurementGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.straighten_rounded, color: primaryColor),
            const SizedBox(width: 8),
            const Text(
              "Guía de Medición",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideItem("Cuello", "Mide en el punto medio del cuello, justo debajo de la manzana de Adán."),
              _buildGuideItem("Pecho / Tórax", "Mide en la parte más prominente del busto/tórax, con la cinta horizontal."),
              _buildGuideItem("Cintura", "Mide en la parte más estrecha del abdomen, usualmente 2 cm sobre el ombligo."),
              _buildGuideItem("Cadera / Glúteos", "Mide en la zona más ancha de los glúteos con los pies juntos."),
              _buildGuideItem("Bíceps", "Mide en el punto medio entre el hombro y el codo con el brazo relajado."),
              _buildGuideItem("Muslo", "Mide en la parte media o superior del muslo con la pierna relajada."),
              _buildGuideItem("Gemelo", "Mide en la parte más ancha de la pantorrilla."),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: backgroundColor),
            child: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• $title", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    String? suffix,
    bool isNumeric = false,
    bool isRequired = true,
    int maxLines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              children: [
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            validator: (val) {
              if (isRequired && (val == null || val.trim().isEmpty)) {
                return 'Este campo es requerido';
              }
              if (isNumeric && val != null && val.trim().isNotEmpty) {
                final n = _parse(val);
                if (n == null || n <= 0) return 'Ingresa un valor numérico válido';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              suffixText: suffix,
              suffixStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              prefixIcon: icon != null ? Icon(icon, color: primaryColor.withValues(alpha: 0.7), size: 18) : null,
              filled: true,
              fillColor: const Color(0xFF131B27),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "PLANILLA DE DATOS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 15),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        actions: [
          IconButton(
            onPressed: _showMeasurementGuideDialog,
            icon: Icon(Icons.info_outline_rounded, color: primaryColor),
            tooltip: "Guía de Medición",
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card con información legal y de confidencialidad
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentPink.withValues(alpha: 0.25),
                            const Color(0xFF1D1B2E),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: accentPink.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentPink,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "YP FIT",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "CONFIDENCIAL",
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Planilla de Datos de Evaluación",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "En este documento se recogerán todos los datos necesarios para poder personalizar tu plan de entrenamiento. Estos datos son confidenciales, sólo serán utilizados para el desarrollo de los programas de entrenamiento más convenientes en base a su situación personal y nivel de salud. Es importante que complete el formulario teniendo en cuenta responder de la manera más honesta posible.",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.45),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "* Indica campo requerido",
                            style: TextStyle(color: accentPink.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // SECCIÓN 1: MEDIDAS CORPORALES & BIOMETRÍA
                    _buildSectionCard(
                      title: "1. Medidas & Antropometría",
                      subtitle: "Indica tus medidas con cinta métrica flexible",
                      icon: Icons.accessibility_new_rounded,
                      trailing: TextButton.icon(
                        onPressed: _showMeasurementGuideDialog,
                        icon: const Icon(Icons.help_outline, size: 14),
                        label: const Text("Ver Guía", style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: primaryColor),
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _ageController,
                                label: "Edad",
                                hint: "ej. 24",
                                suffix: "años",
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _heightController,
                                label: "Altura",
                                hint: "ej. 175",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        _buildTextField(
                          controller: _weightController,
                          label: "Peso Corporal",
                          hint: "ej. 75.2",
                          suffix: "kg",
                          icon: Icons.scale_rounded,
                          isNumeric: true,
                        ),
                        const Divider(color: Colors.white12, height: 26),
                        const Text(
                          "CONTORNOS CORPORALES (en centímetros)",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _neckController,
                                label: "Cuello",
                                hint: "ej. 38",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _chestController,
                                label: "Pecho / Tórax",
                                hint: "ej. 104",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _waistController,
                                label: "Cintura",
                                hint: "ej. 82",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _hipsController,
                                label: "Cadera / Glúteos",
                                hint: "ej. 98",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _bicepsController,
                                label: "Bíceps (medio)",
                                hint: "ej. 38.5",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _thighController,
                                label: "Muslo",
                                hint: "ej. 60",
                                suffix: "cm",
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        _buildTextField(
                          controller: _calvesController,
                          label: "Gemelo (pantorrilla)",
                          hint: "ej. 39",
                          suffix: "cm",
                          isNumeric: true,
                        ),
                      ],
                    ),

                    // SECCIÓN 2: SALUD Y ANTECEDENTES MÉDICOS
                    _buildSectionCard(
                      title: "2. Salud & Antecedentes",
                      subtitle: "Condiciones físicas relevantes para tu seguridad",
                      icon: Icons.medical_services_outlined,
                      children: [
                        _buildTextField(
                          controller: _healthConditionsController,
                          label: "¿Tienes alguna condición de salud?",
                          hint: "ej. SOP, hipotiroidismo, asma, diabetes, ninguna...",
                          helper: "SOP, hipotiroidismo, síndrome metabólico, asma, diabetes, convulsiones, otros. Si no tienes, escribe 'Ninguna'.",
                          maxLines: 2,
                        ),
                        _buildTextField(
                          controller: _surgicalHistoryController,
                          label: "Antecedentes quirúrgicos",
                          hint: "Detalle de cirugías y fechas aproximadas, o 'Ninguna'.",
                          helper: "¿Fue operado alguna vez? Detalle de cirugía y fecha.",
                          maxLines: 2,
                        ),
                        _buildTextField(
                          controller: _injuriesController,
                          label: "¿Tienes alguna lesión actual o pasada?",
                          hint: "ej. Menisco rodilla derecha, lumbalgia, ninguna...",
                          helper: "Lesión que impida o requiera modificaciones en el ejercicio.",
                          maxLines: 2,
                        ),
                        _buildTextField(
                          controller: _medicationsController,
                          label: "¿Tomas medicación habitual o tratamiento?",
                          hint: "Nombre del medicamento o 'Ninguno'.",
                          maxLines: 2,
                        ),
                      ],
                    ),

                    // SECCIÓN 3: ESTILO DE VIDA Y HÁBITOS
                    _buildSectionCard(
                      title: "3. Estilo de Vida & Hábitos",
                      subtitle: "Tu rutina diaria, descanso y nutrición",
                      icon: Icons.nightlife_rounded,
                      children: [
                        const Text(
                          "¿Cómo es tu nivel de actividad física actualmente? *",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ..._activityLevels.map((lvl) {
                          final isSelected = _selectedActivityLevel == lvl;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isSelected ? primaryColor.withValues(alpha: 0.15) : const Color(0xFF131B27),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: RadioListTile<String>(
                                value: lvl,
                                groupValue: _selectedActivityLevel,
                                activeColor: primaryColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: Text(
                                  lvl,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() => _selectedActivityLevel = val);
                                },
                              ),
                            ),
                          );
                        }),
                        if (_selectedActivityLevel == 'Otro')
                          _buildTextField(
                            controller: _otherActivityController,
                            label: "Especifica tu nivel de actividad",
                            hint: "Describe brevemente tu actividad diaria...",
                          ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _sleepHoursController,
                          label: "¿Cuántas horas duermes en promedio por la noche?",
                          hint: "ej. 7 horas",
                          icon: Icons.bedtime_outlined,
                        ),
                        _buildTextField(
                          controller: _dietController,
                          label: "¿Cómo es tu alimentación normalmente?",
                          hint: "ej. Mañanas: 2 tostadas y huevos. Almuerzo: arroz, pollo, ensalada...",
                          helper: "Describe un día típico con el mayor detalle posible (desayuno, snacks, almuerzo, cena).",
                          maxLines: 4,
                        ),
                      ],
                    ),

                    // SECCIÓN 4: EXPERIENCIA, LOGÍSTICA Y OBJETIVOS
                    _buildSectionCard(
                      title: "4. Objetivos & Entrenamiento",
                      subtitle: "Metas, disponibilidad y motivación",
                      icon: Icons.fitness_center_rounded,
                      children: [
                        _buildTextField(
                          controller: _trainingExperienceController,
                          label: "Experiencia previa con el entrenamiento",
                          hint: "Cuándo empezaste, qué tipo de actividad, uso de máquinas...",
                          helper: "¿Cuándo comenzó? ¿Frecuencia semanal previa? ¿Conoce máquinas de gimnasio?",
                          maxLines: 3,
                        ),
                        const Text(
                          "¿Entrenarías en casa o gimnasio? *",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _trainingLocations.map((loc) {
                            final isSel = _selectedLocation == loc;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedLocation = loc),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSel ? primaryColor.withValues(alpha: 0.18) : const Color(0xFF131B27),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? primaryColor : Colors.white.withValues(alpha: 0.08),
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    loc,
                                    style: TextStyle(
                                      color: isSel ? primaryColor : Colors.white70,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "¿Cuántos días a la semana podrás entrenar? *",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _daysOptions.map((day) {
                            final isSel = _selectedDaysPerWeek == day;
                            return FilterChip(
                              label: Text(day),
                              selected: isSel,
                              onSelected: (_) => setState(() => _selectedDaysPerWeek = day),
                              backgroundColor: const Color(0xFF131B27),
                              selectedColor: primaryColor.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: isSel ? primaryColor : Colors.white70,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: isSel ? primaryColor : Colors.white.withValues(alpha: 0.08),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _goalsController,
                          label: "¿Cuáles son tus objetivos de entrenamiento?",
                          hint: "ej. Pérdida de grasa, ganancia muscular, salud, resistencia...",
                          maxLines: 2,
                        ),
                        _buildTextField(
                          controller: _motivationController,
                          label: "¿Qué es lo que más te motiva para alcanzar estos objetivos?",
                          hint: "ej. Sentirme con más energía, superarme, salud, confianza...",
                          maxLines: 2,
                        ),
                        _buildTextField(
                          controller: _extraCommentsController,
                          label: "Comentario extra (opcional)",
                          hint: "Cualquier detalle que quieras que la entrenadora sepa...",
                          isRequired: false,
                          maxLines: 2,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Botón Guardar Planilla
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: backgroundColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? CircularProgressIndicator(color: backgroundColor)
                            : const Text(
                                "GUARDAR PLANILLA DE DATOS",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
