import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:yamanis_fit/core/constants/muscle_constants.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';
import 'package:yamanis_fit/core/services/routine_plan_service.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/client_tracking_sheet_page.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/client_tracking_sheet_page.dart';
import 'create_workout_page.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';

class RoutineExercise {
  String workoutId;
  String workoutName;
  String reps;
  String weight;
  String description;

  RoutineExercise({
    required this.workoutId,
    required this.workoutName,
    this.reps = '',
    this.weight = '',
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'workoutName': workoutName,
      'reps': reps,
      'weight': weight,
      if (description.isNotEmpty) 'description': description,
    };
  }

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      workoutId: (map['workoutId'] ?? '').toString(),
      workoutName: (map['workoutName'] ?? '').toString(),
      reps: (map['reps'] ?? '').toString(),
      weight: (map['weight'] ?? '').toString(),
      description: (map['description'] ?? map['notes'] ?? '').toString(),
    );
  }
}

class RoutineWorkout {
  String sets;
  List<RoutineExercise> exercises;

  RoutineWorkout({
    this.sets = '',
    required this.exercises,
  });

  Map<String, dynamic> toMap() {
    return {
      'sets': sets,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      if (exercises.isNotEmpty) ...{
        'workoutId': exercises[0].workoutId,
        'workoutName': exercises[0].workoutName,
        'reps': exercises[0].reps,
        'weight': exercises[0].weight,
        if (exercises[0].description.isNotEmpty)
          'description': exercises[0].description,
      }
    };
  }
}

class RoutineDayPlan {
  String name;
  List<String> muscleFocus;
  String intensity;
  String level;
  List<RoutineWorkout> workouts;
  String nutritionPlanUrl;
  String notes;

  RoutineDayPlan({
    required this.name,
    required this.muscleFocus,
    required this.intensity,
    required this.level,
    required this.workouts,
    this.nutritionPlanUrl = '',
    this.notes = '',
  });
}

class CreateRoutinePage extends StatefulWidget {
  final String clientId;
  final String clientEmail;
  final String? initialRoutineId;
  final Map<String, dynamic>? initialRoutineData;

  const CreateRoutinePage({
    super.key,
    required this.clientId,
    required this.clientEmail,
    this.initialRoutineId,
    this.initialRoutineData,
  });

  @override
  State<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends State<CreateRoutinePage> {
  final TextEditingController _nameController = TextEditingController();

  List<DocumentSnapshot> availableWorkouts = [];
  List<DocumentSnapshot> filteredWorkouts = [];
  List<RoutineWorkout> selectedWorkouts = [];
  List<String> _selectedMuscles = [];
  String _workoutSearchQuery = '';
  final TextEditingController _nutritionPlanUrlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedIntensity = 'Alta';
  String _selectedLevel = 'Intermedio';

  final Map<DateTime, List<Map<String, dynamic>>> _clientRoutines = {};
  final Set<String> _completedRoutineIds = {};

  final List<String> _muscleGroups = [
    'Piernas', 'Pecho', 'Espalda', 'Hombros', 'Bíceps', 'Tríceps', 'Abdominales', 'Cardio', 'Cuerpo Completo'
  ];

  final List<String> _intensities = ['Baja', 'Media', 'Alta'];
  final List<String> _levels = ['Principiante', 'Intermedio', 'Avanzado'];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime _startDate = DateTime.now();
  final Set<int> _selectedWeekdays = {};
  final Map<int, RoutineDayPlan> _weekdayPlans = {};
  int? _activeWeekday;
  bool isLoading = false;
  bool _isLoadingWorkouts = false;
  bool? _clientHasCompletedDataSheet;
  bool _showWeeklyCounterInCard = true;
  RoutinePlanModel? _editingPlan;
  int _editingCurrentWeek = 1;
  int _editingTotalWeeks = 1;
  final Set<int> _selectedEditWeeks = {1};
  bool _showWeeklyCounterInCard = true;
  RoutinePlanModel? _editingPlan;
  int _editingCurrentWeek = 1;
  int _editingTotalWeeks = 1;
  final Set<int> _selectedEditWeeks = {1};

  int _durationWeeks = 4;
  static const List<int> _durationOptions = [1, 2, 4, 8, 12];
  static const List<MapEntry<int, String>> _weekdays = [
    MapEntry(DateTime.monday, 'Lunes'),
    MapEntry(DateTime.tuesday, 'Martes'),
    MapEntry(DateTime.wednesday, 'Miercoles'),
    MapEntry(DateTime.thursday, 'Jueves'),
    MapEntry(DateTime.friday, 'Viernes'),
    MapEntry(DateTime.saturday, 'Sabado'),
    MapEntry(DateTime.sunday, 'Domingo'),
  ];

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  DateTime _dateOnlyLocal(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime _dateForStorage(DateTime date) => DateTime(date.year, date.month, date.day, 12);
  bool get _isCreateMode => widget.initialRoutineId == null;

  RoutineExercise _cloneExercise(RoutineExercise ex) {
    return RoutineExercise(
      workoutId: ex.workoutId,
      workoutName: ex.workoutName,
      reps: ex.reps,
      weight: ex.weight,
      description: ex.description,
    );
  }

  RoutineWorkout _cloneWorkout(RoutineWorkout workout) {
    return RoutineWorkout(
      sets: workout.sets,
      exercises: workout.exercises.map(_cloneExercise).toList(),
    );
  }

  List<RoutineWorkout> _cloneWorkouts(List<RoutineWorkout> workouts) {
    return workouts.map(_cloneWorkout).toList();
  }

  String _weekdayLabel(int weekday) {
    for (final entry in _weekdays) {
      if (entry.key == weekday) return entry.value;
    }
    return 'Dia';
  }

  RoutineDayPlan _captureEditorPlan() {
    return RoutineDayPlan(
      name: _nameController.text.trim(),
      muscleFocus: List<String>.from(_selectedMuscles),
      intensity: _selectedIntensity,
      level: _selectedLevel,
      workouts: _cloneWorkouts(selectedWorkouts),
      nutritionPlanUrl: _nutritionPlanUrlController.text.trim(),
      notes: _notesController.text.trim(),
    );
  }

  RoutineDayPlan _emptyPlan() {
    return RoutineDayPlan(
      name: '',
      muscleFocus: [],
      intensity: 'Alta',
      level: 'Intermedio',
      workouts: [],
      nutritionPlanUrl: '',
      notes: '',
    );
  }

  RoutineDayPlan _ensureDayPlan(int weekday) {
    return _weekdayPlans.putIfAbsent(weekday, _emptyPlan);
  }

  void _saveActiveDayDraft() {
    if (!_isCreateMode || _activeWeekday == null) return;
    _weekdayPlans[_activeWeekday!] = _captureEditorPlan();
  }

  void _loadPlanIntoEditor(RoutineDayPlan plan) {
    _nameController.text = plan.name;
    _selectedMuscles = List<String>.from(plan.muscleFocus);
    _selectedIntensity = plan.intensity;
    _selectedLevel = plan.level;
    selectedWorkouts = _cloneWorkouts(plan.workouts);
    _notesController.text = plan.notes;
  }

  void _clearEditorForCreateMode() {
    _nameController.clear();
    _selectedMuscles = [];
    _selectedIntensity = 'Alta';
    _selectedLevel = 'Intermedio';
    selectedWorkouts = [];
    _notesController.clear();
  }

  void _setActiveWeekday(int weekday) {
    if (!_isCreateMode) return;
    _saveActiveDayDraft();
    _activeWeekday = weekday;
    _loadPlanIntoEditor(_ensureDayPlan(weekday));
  }

  String? _validatePlan(RoutineDayPlan plan, String dayLabel) {
    if (plan.name.trim().isEmpty) return 'Ingresa un nombre para la rutina de $dayLabel';
    if (plan.muscleFocus.isEmpty) return 'Selecciona enfoque muscular para $dayLabel';
    if (plan.workouts.isEmpty) return 'Añade al menos un ejercicio para $dayLabel';

    for (var workout in plan.workouts) {
      if (workout.sets.trim().isEmpty) {
        return 'Ingresa series para todos los ejercicios de $dayLabel';
      }
      for (var exercise in workout.exercises) {
        if (exercise.reps.trim().isEmpty || exercise.weight.trim().isEmpty) {
          return 'Completa reps y peso en $dayLabel (${exercise.workoutName})';
        }
      }
    }

    return null;
  }

  bool _hasPlanData(int weekday) {
    final plan = _weekdayPlans[weekday];
    if (plan == null) return false;
    return plan.name.trim().isNotEmpty || plan.muscleFocus.isNotEmpty || plan.workouts.isNotEmpty;
  }

  String _friendlyErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'No tienes permisos para esta accion.';
        case 'unavailable':
          return 'Servicio temporalmente no disponible. Intenta de nuevo.';
        case 'deadline-exceeded':
          return 'La operacion tardo demasiado. Revisa tu conexion.';
        default:
          return error.message ?? 'Error inesperado en la base de datos.';
      }
    }
    return 'Ocurrio un error inesperado. Intenta nuevamente.';
  }

  Future<bool> _confirmRemoveWeekday(int weekday) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Quitar dia', style: TextStyle(color: Colors.white)),
        content: Text(
          'Si quitas ${_weekdayLabel(weekday)} se perdera su configuracion.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('QUITAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _toggleWeekdaySelection(int weekday, bool selected) async {
    if (selected) {
      if (!mounted) return;
      setState(() {
        _selectedWeekdays.add(weekday);
        _setActiveWeekday(weekday);
      });
      return;
    }

    final shouldConfirm = _hasPlanData(weekday);
    if (shouldConfirm) {
      final confirmed = await _confirmRemoveWeekday(weekday);
      if (!confirmed || !mounted) return;
    }

    if (!mounted) return;
    setState(() {
      _selectedWeekdays.remove(weekday);
      _weekdayPlans.remove(weekday);
      if (_activeWeekday == weekday) {
        if (_selectedWeekdays.isNotEmpty) {
          _setActiveWeekday(_selectedWeekdays.first);
        } else {
          _activeWeekday = null;
          _clearEditorForCreateMode();
        }
      }
    });
  }

  Widget _buildSectionTitle(String title, {String? subtitle, IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: icon != null ? 38 : 22,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat_rounded, color: primaryColor, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Duración del plan',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'La Semana 1 que configures se duplicará automáticamente.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _durationOptions.map((weeks) {
            final isSelected = _durationWeeks == weeks;
            return GestureDetector(
              onTap: () => setState(() => _durationWeeks = weeks),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  weeks == 1 ? '1 semana' : '$weeks semanas',
                  style: TextStyle(
                    color: isSelected ? backgroundColor : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlanSummary() {
    final daysPerWeek = _selectedWeekdays.length;
    final totalSessions = _buildDatesForPlan(_startDate, _selectedWeekdays, _durationWeeks).length;
    final endDate = _planEndDate(_startDate, _durationWeeks);

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    Widget row(IconData icon, String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: secondaryColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'RESUMEN DEL PLAN',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row(Icons.repeat_rounded, 'Duración',
              _durationWeeks == 1 ? '1 semana' : '$_durationWeeks semanas'),
          row(Icons.event_repeat_rounded, 'Días por semana', '$daysPerWeek'),
          row(Icons.fitness_center_rounded, 'Sesiones totales', '$totalSessions'),
          row(Icons.play_circle_outline_rounded, 'Inicia', fmt(_startDate)),
          row(Icons.timer_off_outlined, 'Cuenta expira', fmt(endDate), valueColor: Colors.orangeAccent),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: secondaryColor, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Al guardar, la cuenta se activará automáticamente y vencerá el ${fmt(endDate)}.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDayBanner() {
    if (!_isCreateMode || _activeWeekday == null || _selectedWeekdays.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderedDays = _weekdays.where((e) => _selectedWeekdays.contains(e.key)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withValues(alpha: 0.22), secondaryColor.withValues(alpha: 0.12)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_weekdayIcon(_activeWeekday!), color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EDITANDO SEMANA 1',
                    style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                  Text(
                    _weekdayLabel(_activeWeekday!),
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          if (orderedDays.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: orderedDays.map((entry) {
                  final isActive = _activeWeekday == entry.key;
                  final isConfigured = _hasPlanData(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _setActiveWeekday(entry.key)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isConfigured) ...[
                              Icon(
                                Icons.check_circle,
                                size: 13,
                                color: isActive ? backgroundColor : Colors.greenAccent,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              entry.value.substring(0, 3),
                              style: TextStyle(
                                color: isActive ? backgroundColor : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _weekdayIcon(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return Icons.bolt;
      case DateTime.tuesday:
        return Icons.fitness_center;
      case DateTime.wednesday:
        return Icons.local_fire_department;
      case DateTime.thursday:
        return Icons.sports_gymnastics;
      case DateTime.friday:
        return Icons.trending_up;
      case DateTime.saturday:
        return Icons.self_improvement;
      case DateTime.sunday:
        return Icons.favorite;
      default:
        return Icons.calendar_today;
    }
  }

  Widget _buildWeekdayTile(MapEntry<int, String> entry) {
    final isSelected = _selectedWeekdays.contains(entry.key);
    final isActive = _activeWeekday == entry.key;
    final isConfigured = _hasPlanData(entry.key);

    final baseColor = isSelected ? primaryColor : Colors.white;

    return GestureDetector(
      onTap: () => _toggleWeekdaySelection(entry.key, !isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 102,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withValues(alpha: 0.28),
                    secondaryColor.withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? primaryColor
                : (isSelected ? primaryColor.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.08)),
            width: isActive ? 1.8 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(_weekdayIcon(entry.key), size: 14, color: baseColor.withValues(alpha: isSelected ? 1 : 0.7)),
                if (isConfigured)
                  Icon(Icons.check_circle, size: 14, color: Colors.greenAccent.withValues(alpha: 0.95)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = _dateOnlyLocal(now);
    _startDate = _dateOnlyLocal(now);
    _selectedWeekdays.add(_startDate.weekday);
    _activeWeekday = _startDate.weekday;
    _weekdayPlans[_activeWeekday!] = _emptyPlan();
    _prefillForEdit();
    loadWorkouts();
    _fetchClientRoutines();
    _checkClientDataSheet();
  }

  Future<void> _checkClientDataSheet() async {
    final hasSheet = await BiometricsService.hasCompletedDataSheet(widget.clientId);
    if (mounted) {
      setState(() => _clientHasCompletedDataSheet = hasSheet);
    }
  }

   void _prefillForEdit() {
     final initial = widget.initialRoutineData;
     if (initial == null) return;

     _nameController.text = (initial['name'] ?? '').toString();
     _nutritionPlanUrlController.text = (initial['nutritionPlanUrl'] ?? '').toString();
     _notesController.text = (initial['notes'] ?? '').toString();
     _selectedMuscles = List<String>.from((initial['muscleFocus'] as List<dynamic>? ?? []).map((e) => e.toString()));
     
     if (initial['intensity'] != null) _selectedIntensity = initial['intensity'];
     if (initial['level'] != null) _selectedLevel = initial['level'];

    final dateTs = initial['date'] as Timestamp?;
    if (dateTs != null) {
      final date = dateTs.toDate();
      final normalized = _dateOnlyLocal(date);
      _selectedDay = normalized;
      _focusedDay = normalized;
      _startDate = normalized;
      _selectedWeekdays
        ..clear()
        ..add(normalized.weekday);
    }

    final workouts = initial['workouts'] as List<dynamic>? ?? [];
    selectedWorkouts = workouts.map((w) {
      final map = w as Map<String, dynamic>;
      List<RoutineExercise> exercises = [];
      if (map['exercises'] != null && (map['exercises'] as List).isNotEmpty) {
        exercises = (map['exercises'] as List).map((e) => RoutineExercise.fromMap(e as Map<String, dynamic>)).toList();
      } else if (map['workoutId'] != null || map['workoutName'] != null) {
        exercises = [
          RoutineExercise(
            workoutId: (map['workoutId'] ?? '').toString(),
            workoutName: (map['workoutName'] ?? '').toString(),
            reps: (map['reps'] ?? '').toString(),
            weight: (map['weight'] ?? '').toString(),
            description: (map['description'] ?? map['notes'] ?? '').toString(),
          )
        ];
      }
      return RoutineWorkout(sets: (map['sets'] ?? '').toString(), exercises: exercises);
    }).toList();

    if (_isCreateMode) {
      _weekdayPlans[_activeWeekday ?? _startDate.weekday] = _captureEditorPlan();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nutritionPlanUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> loadWorkouts() async {
    setState(() => _isLoadingWorkouts = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('workouts').get();
      if (!mounted) return;
      setState(() {
        availableWorkouts = snapshot.docs;
        _filterWorkouts();
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoadingWorkouts = false);
    }
  }

  void _filterWorkouts() {
    if (_workoutSearchQuery.isEmpty) {
      filteredWorkouts = availableWorkouts;
    } else {
      final query = _workoutSearchQuery.toLowerCase();
      filteredWorkouts = availableWorkouts.where((workout) {
        final data = workout.data() as Map<String, dynamic>? ?? {};
        final name = (data['name'] as String? ?? '').toLowerCase();
        final general = (data['generalMuscles'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ??
            ((data['muscleFocus'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? []);
        final specific = (data['specificMuscles'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];

        return name.contains(query) ||
            general.any((m) => m.contains(query)) ||
            specific.any((m) => m.contains(query));
      }).toList();
    }
  }

  Future<void> _fetchClientRoutines() async {
    try {
      final routinesSnapshot = await FirebaseFirestore.instance.collection('routines').where('clientId', isEqualTo: widget.clientId).get();
      final logsSnapshot = await FirebaseFirestore.instance.collection('routine_logs').where('userId', isEqualTo: widget.clientId).get();
      final completedIds = <String>{};
      for (var logDoc in logsSnapshot.docs) {
        final routineId = logDoc.data()['routineId'];
        if (routineId != null) completedIds.add(routineId);
      }
      final Map<DateTime, List<Map<String, dynamic>>> newRoutines = {};
      final List<Map<String, dynamic>> allFlatRoutines = [];
      for (var doc in routinesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        allFlatRoutines.add(data);
        final DateTime date = (data['date'] as Timestamp).toDate();
        final DateTime normalizedDate = _dateOnlyLocal(date);
        newRoutines.putIfAbsent(normalizedDate, () => []).add(data);
      }

      RoutinePlanModel? foundEditPlan;
      int editCurrWeek = 1;
      int editTotalWeeks = 1;
      if (!_isCreateMode && widget.initialRoutineId != null) {
        final plans = RoutinePlanService.groupRoutinesIntoPlans(allFlatRoutines);
        for (final p in plans) {
          final match = p.routines.where((r) => r['id']?.toString() == widget.initialRoutineId).toList();
          if (match.isNotEmpty) {
            foundEditPlan = p;
            final targetRoutine = match.first;
            final explicitWeek = targetRoutine['weekNumber'] as int?;
            final rDate = (targetRoutine['date'] as Timestamp?)?.toDate() ?? p.startDate;
            editCurrWeek = explicitWeek ??
                (((_dateOnlyLocal(rDate).difference(_dateOnlyLocal(p.startDate)).inDays) ~/ 7) + 1);
            if (editCurrWeek < 1) editCurrWeek = 1;
            editTotalWeeks = p.durationWeeks < editCurrWeek ? editCurrWeek : p.durationWeeks;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _clientRoutines.clear();
        _clientRoutines.addAll(newRoutines);
        _completedRoutineIds.clear();
        _completedRoutineIds.addAll(completedIds);
        if (foundEditPlan != null) {
          _editingPlan = foundEditPlan;
          _editingCurrentWeek = editCurrWeek;
          _editingTotalWeeks = editTotalWeeks;
          _selectedEditWeeks
            ..clear()
            ..add(editCurrWeek);
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_friendlyErrorMessage(e));
    }
  }

  void _addWorkoutToRoutine(String workoutId, String workoutName) {
    setState(() {
      selectedWorkouts.add(
        RoutineWorkout(
          sets: '4',
          exercises: [RoutineExercise(workoutId: workoutId, workoutName: workoutName)],
        ),
      );
      _saveActiveDayDraft();
    });
  }

  void _addExerciseToSuperset(int index, String workoutId, String workoutName) {
    if (selectedWorkouts[index].exercises.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máximo 2 ejercicios por serie'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() {
      selectedWorkouts[index].exercises.add(RoutineExercise(workoutId: workoutId, workoutName: workoutName));
      _saveActiveDayDraft();
    });
  }

  String _inferMuscleCategory(
    String? workoutId,
    String workoutName,
    List<String> routineMuscleFocus,
  ) {
    if (workoutId != null && workoutId.isNotEmpty) {
      for (final doc in availableWorkouts) {
        if (doc.id == workoutId) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final specific = (data['specificMuscles'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (specific.isNotEmpty) return specific.first;
          final general = (data['generalMuscles'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ((data['muscleFocus'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  []);
          if (general.isNotEmpty) {
            final mapped = MuscleConstants.musclesByCategory[general.first];
            if (mapped != null && mapped.isNotEmpty) return mapped.first;
            return general.first;
          }
          break;
        }
      }
    }

    final lower = workoutName.toLowerCase();
    if (lower.contains('pecho') || lower.contains('bench') || lower.contains('press banca')) {
      return 'Pectoral';
    }
    if (lower.contains('sentadilla') || lower.contains('prensa') || lower.contains('cuad')) {
      return 'Cuádriceps';
    }
    if (lower.contains('bicep') || lower.contains('curl')) return 'Bíceps';
    if (lower.contains('tricep') || lower.contains('fondo') || lower.contains('copa')) {
      return 'Tríceps';
    }
    if (lower.contains('espalda') || lower.contains('remo') || lower.contains('jalon')) {
      return 'Espalda';
    }
    if (lower.contains('glute') || lower.contains('hip thrust')) return 'Glúteo';
    if (lower.contains('isquio') || lower.contains('femor') || lower.contains('peso muerto')) {
      return 'Isquiosurales';
    }
    if (lower.contains('gemelo') || lower.contains('pantorrilla')) return 'Gemelos';
    if (lower.contains('hombro') || lower.contains('militar')) return 'Deltoides anterior';
    if (lower.contains('lateral') || lower.contains('vuelo')) return 'Deltoides lateral';
    if (lower.contains('posterior') || lower.contains('pajaro')) return 'Deltoides posterior';
    if (lower.contains('abdom') || lower.contains('plancha') || lower.contains('crunch')) {
      return 'Abdominales';
    }
    if (lower.contains('abductor')) return 'Abductores';
    if (lower.contains('aductor')) return 'Aductores';

    if (routineMuscleFocus.isNotEmpty) {
      final gen = routineMuscleFocus.first;
      final mapped = MuscleConstants.musclesByCategory[gen];
      if (mapped != null && mapped.isNotEmpty) return mapped.first;
      return gen;
    }

    return 'General';
  }

  Map<int, RoutineDayPlan> _getEffectiveDayPlans() {
    if (!_isCreateMode) {
      final weekday = (_selectedDay ?? DateTime.now()).weekday;
      return {weekday: _captureEditorPlan()};
    }
    final map = <int, RoutineDayPlan>{};
    final orderedWeekdays = _weekdays
        .where((e) => _selectedWeekdays.contains(e.key))
        .map((e) => e.key);
    for (final wd in orderedWeekdays) {
      if (wd == _activeWeekday) {
        map[wd] = _captureEditorPlan();
      } else {
        map[wd] = _ensureDayPlan(wd);
      }
    }
    return map;
  }

  /// Calcula {músculo: {exercises: X, sets: Y}} para un plan de un día o varios días
  Map<String, ({int exercises, int sets})> _computeMuscleStats({
    required bool weeklyScope,
  }) {
    final stats = <String, ({int exercises, int sets})>{};
    final plans = weeklyScope && _isCreateMode
        ? _getEffectiveDayPlans().values.toList()
        : [_captureEditorPlan()];

    for (final plan in plans) {
      for (final workout in plan.workouts) {
        final rawSets = int.tryParse(workout.sets.trim());
        final setsCount = (rawSets != null && rawSets > 0) ? rawSets : 0;
        for (final ex in workout.exercises) {
          final muscle = _inferMuscleCategory(
            ex.workoutId,
            ex.workoutName,
            plan.muscleFocus,
          );
          final prev = stats[muscle] ?? (exercises: 0, sets: 0);
          stats[muscle] = (
            exercises: prev.exercises + 1,
            sets: prev.sets + setsCount,
          );
        }
      }
    }
    return stats;
  }

  Future<void> _saveRoutine() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isCreateMode && _selectedWeekdays.isEmpty) {
      _showErrorSnackBar('Selecciona al menos un dia de la semana');
      return;
    }
    if (!_isCreateMode && _selectedDay == null) { _showErrorSnackBar('Selecciona un día en el calendario'); return; }

    if (_isCreateMode) {
      _saveActiveDayDraft();
      for (final weekday in _selectedWeekdays) {
        final plan = _weekdayPlans[weekday];
        if (plan == null) {
          _showErrorSnackBar('Configura una rutina para ${_weekdayLabel(weekday)}');
          return;
        }
        final error = _validatePlan(plan, _weekdayLabel(weekday));
        if (error != null) {
          _showErrorSnackBar(error);
          return;
        }
      }
    } else {
      final error = _validatePlan(_captureEditorPlan(), 'el dia seleccionado');
      if (error != null) {
        _showErrorSnackBar(error);
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      if (!_isCreateMode) {
        final currentPlan = _captureEditorPlan();
        final workoutData = currentPlan.workouts.map((workout) => workout.toMap()).toList();
        final dataToSave = {
          'name': currentPlan.name,
          'workouts': workoutData,
          'muscleFocus': currentPlan.muscleFocus,
          'intensity': currentPlan.intensity,
          'level': currentPlan.level,
          'notes': currentPlan.notes,
          'clientId': widget.clientId,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        };

        final DateTime selectedDate = _dateOnlyLocal(_selectedDay!);
        final DateTime storageDate = _dateForStorage(selectedDate);
        await FirebaseFirestore.instance.collection('routines').doc(widget.initialRoutineId).update({...dataToSave, 'date': Timestamp.fromDate(storageDate)});

        int extraWeeksUpdated = 0;
        if (_editingPlan != null && _selectedEditWeeks.any((w) => w != _editingCurrentWeek)) {
          final byId = <String, ({String sets, String reps, String weight, String description})>{};
          final byName = <String, ({String sets, String reps, String weight, String description})>{};
          for (final w in currentPlan.workouts) {
            for (final ex in w.exercises) {
              final entry = (
                sets: w.sets,
                reps: ex.reps,
                weight: ex.weight,
                description: ex.description,
              );
              if (ex.workoutId.trim().isNotEmpty) {
                byId[ex.workoutId.trim()] = entry;
              }
              if (ex.workoutName.trim().isNotEmpty) {
                byName[ex.workoutName.trim().toLowerCase()] = entry;
              }
            }
          }

          final batch = FirebaseFirestore.instance.batch();
          int batchCount = 0;

          for (final r in _editingPlan!.routines) {
            final rId = r['id']?.toString();
            if (rId == null || rId.isEmpty || rId == widget.initialRoutineId) continue;

            final explicitWeek = r['weekNumber'] as int?;
            final rDate = (r['date'] as Timestamp?)?.toDate() ?? _editingPlan!.startDate;
            int rWeek = explicitWeek ??
                (((_dateOnlyLocal(rDate).difference(_dateOnlyLocal(_editingPlan!.startDate)).inDays) ~/ 7) + 1);
            if (rWeek < 1) rWeek = 1;

            if (!_selectedEditWeeks.contains(rWeek)) continue;

            final rWorkoutsRaw = (r['workouts'] as List<dynamic>? ?? []);
            final updatedWorkouts = <Map<String, dynamic>>[];
            bool changedInRoutine = false;

            for (final rw in rWorkoutsRaw) {
              final rwMap = Map<String, dynamic>.from(rw as Map);
              final exListRaw = rwMap['exercises'] as List<dynamic>?;
              if (exListRaw != null && exListRaw.isNotEmpty) {
                final newExList = <Map<String, dynamic>>[];
                for (int i = 0; i < exListRaw.length; i++) {
                  final exMap = Map<String, dynamic>.from(exListRaw[i] as Map);
                  final exId = (exMap['workoutId'] ?? '').toString().trim();
                  final exName = (exMap['workoutName'] ?? '').toString().trim().toLowerCase();
                  final match = (exId.isNotEmpty ? byId[exId] : null) ??
                      (exName.isNotEmpty ? byName[exName] : null);
                  if (match != null) {
                    exMap['reps'] = match.reps;
                    exMap['weight'] = match.weight;
                    if (match.description.isNotEmpty) {
                      exMap['description'] = match.description;
                    }
                    rwMap['sets'] = match.sets;
                    if (i == 0) {
                      rwMap['reps'] = match.reps;
                      rwMap['weight'] = match.weight;
                    }
                    changedInRoutine = true;
                  }
                  newExList.add(exMap);
                }
                rwMap['exercises'] = newExList;
              } else {
                final exId = (rwMap['workoutId'] ?? '').toString().trim();
                final exName = (rwMap['workoutName'] ?? '').toString().trim().toLowerCase();
                final match = (exId.isNotEmpty ? byId[exId] : null) ??
                    (exName.isNotEmpty ? byName[exName] : null);
                if (match != null) {
                  rwMap['sets'] = match.sets;
                  rwMap['reps'] = match.reps;
                  rwMap['weight'] = match.weight;
                  changedInRoutine = true;
                }
              }
              updatedWorkouts.add(rwMap);
            }

            if (changedInRoutine) {
              batch.update(
                FirebaseFirestore.instance.collection('routines').doc(rId),
                {
                  'workouts': updatedWorkouts,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': user.uid,
                },
              );
              batchCount++;
              extraWeeksUpdated++;
            }
          }

          if (batchCount > 0) {
            await batch.commit();
          }
        }

        if (!mounted) return;
        _showSuccessSnackBar(
          extraWeeksUpdated > 0
              ? 'Rutina y ejercicios actualizados en ${_selectedEditWeeks.length} semanas'
              : 'Rutina actualizada',
        );
      } else {
        final datesToCreate = _buildDatesForPlan(_startDate, _selectedWeekdays, _durationWeeks);
        if (datesToCreate.isEmpty) {
          _showErrorSnackBar('No se generaron fechas. Revisa inicio y dias seleccionados.');
          setState(() => isLoading = false);
          return;
        }

        final start = datesToCreate.first;
        final endExclusive = datesToCreate.last.add(const Duration(days: 1));

        final existingSnapshot = await FirebaseFirestore.instance
            .collection('routines')
            .where('clientId', isEqualTo: widget.clientId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(endExclusive))
            .get();

        final existingByDay = <String, String>{};
        for (final doc in existingSnapshot.docs) {
          final ts = doc.data()['date'] as Timestamp?;
          if (ts == null) continue;
          final key = _dateKey(_dateOnlyLocal(ts.toDate()));
          existingByDay[key] = doc.id;
        }

        int created = 0;
        int updated = 0;
        final routines = FirebaseFirestore.instance.collection('routines');
        final planId = 'plan_${_dateKey(_startDate)}_${DateTime.now().millisecondsSinceEpoch}';
        final planStartStorage = _dateForStorage(_startDate);

        for (final day in datesToCreate) {
          final key = _dateKey(day);
          final storageDate = _dateForStorage(day);
          final existingId = existingByDay[key];
          final plan = _weekdayPlans[day.weekday]!;
          final weekNumber = ((day.difference(start).inDays) ~/ 7) + 1;
          final dataToSave = {
            'name': plan.name,
            'workouts': plan.workouts.map((workout) => workout.toMap()).toList(),
            'muscleFocus': plan.muscleFocus,
            'intensity': plan.intensity,
            'level': plan.level,
            'notes': plan.notes,
            'clientId': widget.clientId,
            'planId': planId,
            'durationWeeks': _durationWeeks,
            'planStartDate': Timestamp.fromDate(planStartStorage),
            'weekNumber': weekNumber,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': user.uid,
            if (plan.nutritionPlanUrl.isNotEmpty) 'nutritionPlanUrl': plan.nutritionPlanUrl,
          };

          if (existingId != null) {
            await routines.doc(existingId).update({...dataToSave, 'date': Timestamp.fromDate(storageDate)});
            updated++;
          } else {
            await routines.add({
              ...dataToSave,
              'createdBy': user.uid,
              'date': Timestamp.fromDate(storageDate),
              'createdAt': FieldValue.serverTimestamp(),
            });
            created++;
          }
        }

        // Activación automática + expiración dinámica ligada a la duración del plan.
        await _autoActivateClient(_startDate, _durationWeeks, user.uid, planId: planId);

        if (!mounted) return;
        _showSuccessSnackBar('Rutinas generadas: $created nuevas, $updated actualizadas');
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  void _showSuccessSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));

  String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Fecha en la que expira el plan: inicio + (semanas * 7 días).
  DateTime _planEndDate(DateTime startDate, int weeks) {
    return _dateOnlyLocal(startDate).add(Duration(days: weeks * 7));
  }

  List<DateTime> _buildDatesForPlan(DateTime startDate, Set<int> weekdays, int weeks) {
    if (weekdays.isEmpty) return [];

    final start = _dateOnlyLocal(startDate);
    final endExclusive = start.add(Duration(days: weeks * 7));
    final dates = <DateTime>[];

    for (DateTime day = start; day.isBefore(endExclusive); day = day.add(const Duration(days: 1))) {
      if (weekdays.contains(day.weekday)) {
        dates.add(_dateOnlyLocal(day));
      }
    }

    return dates;
  }

  /// Activa la cuenta del cliente automáticamente al asignarle su primer plan y
  /// fija la expiración según la duración del plan (inicio + semanas * 7 días).
  /// Nunca acorta una suscripción vigente más larga: usa la fecha mayor.
  Future<void> _autoActivateClient(
    DateTime startDate,
    int weeks,
    String adminUid, {
    String? planId,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.clientId);
    // Fin regular del plan + 1 semana adicional de gracia antes del bloqueo de ejercicios
    final planEnd = _dateForStorage(_planEndDate(startDate, weeks).add(const Duration(days: 7)));

    DateTime activeUntil = planEnd;
    try {
      final snapshot = await userRef.get();
      final existing = (snapshot.data()?['activeUntil'] as Timestamp?)?.toDate();
      // No recortar una suscripción vigente que termina más tarde.
      if (existing != null && existing.isAfter(activeUntil)) {
        activeUntil = existing;
      }
    } catch (_) {
      // Si falla la lectura usamos el fin del plan calculado.
    }

    await userRef.set({
      'isActive': true,
      'activeUntil': Timestamp.fromDate(activeUntil),
      'planDurationWeeks': weeks,
      'planStartDate': Timestamp.fromDate(_dateForStorage(startDate)),
      if (planId != null) 'currentPlanId': planId,
      'activatedAt': FieldValue.serverTimestamp(),
      'activatedBy': adminUid,
      'autoActivated': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _startDate = _dateOnlyLocal(picked);
      _focusedDay = _startDate;
    });
  }

  Widget _buildEditMultiWeekSelector() {
    final bool isOnlyCurrent = _selectedEditWeeks.length == 1 && _selectedEditWeeks.contains(_editingCurrentWeek);
    final bool isRestSelected = _editingCurrentWeek <= _editingTotalWeeks &&
        _selectedEditWeeks.length == (_editingTotalWeeks - _editingCurrentWeek + 1) &&
        List.generate(_editingTotalWeeks - _editingCurrentWeek + 1, (i) => _editingCurrentWeek + i)
            .every(_selectedEditWeeks.contains);
    final bool isAllSelected = _selectedEditWeeks.length == _editingTotalWeeks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'APLICAR REPS Y PESO EN SEMANAS SELECCIONADAS',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sem $_editingCurrentWeek / $_editingTotalWeeks',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Elige en qué semanas del plan aplicar los cambios de series, reps y peso de estos ejercicios al guardar:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                backgroundColor: isOnlyCurrent ? primaryColor : Colors.white.withValues(alpha: 0.06),
                side: BorderSide(color: isOnlyCurrent ? primaryColor : Colors.white24),
                label: Text(
                  'Solo Sem $_editingCurrentWeek',
                  style: TextStyle(
                    color: isOnlyCurrent ? backgroundColor : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedEditWeeks
                      ..clear()
                      ..add(_editingCurrentWeek);
                  });
                },
              ),
              if (_editingCurrentWeek < _editingTotalWeeks)
                ActionChip(
                  backgroundColor: isRestSelected ? primaryColor : Colors.white.withValues(alpha: 0.06),
                  side: BorderSide(color: isRestSelected ? primaryColor : Colors.white24),
                  label: Text(
                    'Resto (Sem $_editingCurrentWeek-$_editingTotalWeeks)',
                    style: TextStyle(
                      color: isRestSelected ? backgroundColor : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedEditWeeks
                        ..clear()
                        ..addAll(List.generate(
                          _editingTotalWeeks - _editingCurrentWeek + 1,
                          (i) => _editingCurrentWeek + i,
                        ));
                    });
                  },
                ),
              ActionChip(
                backgroundColor: isAllSelected ? primaryColor : Colors.white.withValues(alpha: 0.06),
                side: BorderSide(color: isAllSelected ? primaryColor : Colors.white24),
                label: Text(
                  'Todas (1-$_editingTotalWeeks)',
                  style: TextStyle(
                    color: isAllSelected ? backgroundColor : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedEditWeeks
                      ..clear()
                      ..addAll(List.generate(_editingTotalWeeks, (i) => i + 1));
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_editingTotalWeeks, (idx) {
              final wNum = idx + 1;
              final isSelected = _selectedEditWeeks.contains(wNum);
              return FilterChip(
                selected: isSelected,
                showCheckmark: true,
                checkmarkColor: backgroundColor,
                selectedColor: primaryColor,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                side: BorderSide(color: isSelected ? primaryColor : Colors.white24),
                label: Text(
                  'Sem $wNum',
                  style: TextStyle(
                    color: isSelected ? backgroundColor : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedEditWeeks.add(wNum);
                    } else if (_selectedEditWeeks.length > 1 && wNum != _editingCurrentWeek) {
                      _selectedEditWeeks.remove(wNum);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMuscleCounterCard() {
    final bool useWeekly = _isCreateMode && _selectedWeekdays.length > 1 && _showWeeklyCounterInCard;
    final stats = _computeMuscleStats(weeklyScope: useWeekly);
    final entries = stats.entries.toList()
      ..sort((a, b) {
        final bySets = b.value.sets.compareTo(a.value.sets);
        if (bySets != 0) return bySets;
        return b.value.exercises.compareTo(a.value.exercises);
      });

    final int totalExercises = entries.fold<int>(0, (s, e) => s + e.value.exercises);
    final int totalSets = entries.fold<int>(0, (s, e) => s + e.value.sets);
    final int totalMuscles = entries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF881337).withValues(alpha: 0.28),
            const Color(0xFF161F2C),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTADOR MUSCULAR EN TIEMPO REAL',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      useWeekly
                          ? 'Acumulado de la semana (${_selectedWeekdays.length} días)'
                          : (_isCreateMode && _activeWeekday != null
                              ? 'Conteo de ${_weekdayLabel(_activeWeekday!)}'
                              : 'Conteo de la rutina actual'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showLiveTrackingAndCounterSheet,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF881337),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.table_chart_rounded, size: 14),
                label: const Text(
                  'Ver Tabla',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_isCreateMode && _selectedWeekdays.length > 1) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showWeeklyCounterInCard = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_showWeeklyCounterInCard
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _activeWeekday != null
                              ? 'Solo ${_weekdayLabel(_activeWeekday!)}'
                              : 'Este Día',
                          style: TextStyle(
                            color: !_showWeeklyCounterInCard
                                ? backgroundColor
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showWeeklyCounterInCard = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _showWeeklyCounterInCard
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Toda la Semana (${_selectedWeekdays.length}d)',
                          style: TextStyle(
                            color: _showWeeklyCounterInCard
                                ? backgroundColor
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickMetricChip(
                icon: Icons.fitness_center_rounded,
                label: 'Ejercicios',
                value: '$totalExercises',
              ),
              const SizedBox(width: 8),
              _buildQuickMetricChip(
                icon: Icons.repeat_rounded,
                label: 'Series totales',
                value: '$totalSets',
                highlight: true,
              ),
              const SizedBox(width: 8),
              _buildQuickMetricChip(
                icon: Icons.accessibility_new_rounded,
                label: 'Músculos',
                value: '$totalMuscles',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Añade ejercicios abajo para ver cuántos ejercicios y series lleva cada músculo en tiempo real.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11.5,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((entry) {
                final muscle = entry.key;
                final exCount = entry.value.exercises;
                final setsCount = entry.value.sets;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        muscle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${exCount}ej • ${setsCount}s',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickMetricChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: highlight ? primaryColor : Colors.white60,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: highlight ? primaryColor : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveTrackingAndCounterSheet() {
    _saveActiveDayDraft();
    final dayPlans = _getEffectiveDayPlans();
    final orderedDays = dayPlans.entries.toList();

    // Calcular matriz por músculo: {músculo: {exercisesTotal, setsByDay, setsTotal}}
    final allMuscles = <String>{
      ...MuscleConstants.specificMuscles,
    };

    for (final entry in orderedDays) {
      final plan = entry.value;
      for (final w in plan.workouts) {
        for (final ex in w.exercises) {
          allMuscles.add(_inferMuscleCategory(ex.workoutId, ex.workoutName, plan.muscleFocus));
        }
      }
    }

    final Map<String, List<int>> setsMatrix = {};
    final Map<String, int> exercisesCountByMuscle = {};
    for (final m in allMuscles) {
      setsMatrix[m] = List.generate(orderedDays.length, (_) => 0);
      exercisesCountByMuscle[m] = 0;
    }

    for (int d = 0; d < orderedDays.length; d++) {
      final plan = orderedDays[d].value;
      for (final w in plan.workouts) {
        final sCount = int.tryParse(w.sets.trim()) ?? 0;
        for (final ex in w.exercises) {
          final muscle = _inferMuscleCategory(ex.workoutId, ex.workoutName, plan.muscleFocus);
          setsMatrix[muscle]![d] += sCount;
          exercisesCountByMuscle[muscle] = (exercisesCountByMuscle[muscle] ?? 0) + 1;
        }
      }
    }

    final sortedMuscles = allMuscles.toList()
      ..sort((a, b) {
        final exA = exercisesCountByMuscle[a] ?? 0;
        final exB = exercisesCountByMuscle[b] ?? 0;
        if ((exA > 0) != (exB > 0)) return exB.compareTo(exA);
        final setsA = setsMatrix[a]?.fold<int>(0, (s, v) => s + v) ?? 0;
        final setsB = setsMatrix[b]?.fold<int>(0, (s, v) => s + v) ?? 0;
        return setsB.compareTo(setsA);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF11151C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TABLA Y CONTADOR MUSCULAR EN VIVO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              'Resumen en tiempo real de la rutina que estás armando',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientTrackingSheetPage(
                                clientId: widget.clientId,
                                clientName: widget.clientEmail.split('@').first,
                                clientEmail: widget.clientEmail,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text(
                          'Historial',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicatorColor: primaryColor,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    tabs: const [
                      Tab(text: 'Contador Muscular'),
                      Tab(text: 'Tabla por Día'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: CONTADOR MUSCULAR (EJERCICIOS + SERIES POR DÍA + TOTAL)
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF881337)),
                              headingRowHeight: 38,
                              dataRowMinHeight: 34,
                              dataRowMaxHeight: 38,
                              columnSpacing: 16,
                              horizontalMargin: 12,
                              border: TableBorder.all(color: const Color(0xFF334155), width: 0.8),
                              columns: [
                                const DataColumn(
                                  label: Text(
                                    'MÚSCULO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                  ),
                                ),
                                const DataColumn(
                                  label: Center(
                                    child: Text(
                                      'EJERCICIOS',
                                      style: TextStyle(color: Color(0xFFAEE084), fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                ),
                                for (int d = 0; d < orderedDays.length; d++)
                                  DataColumn(
                                    label: Center(
                                      child: Text(
                                        _weekdayLabel(orderedDays[d].key).substring(0, 3).toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                const DataColumn(
                                  label: Center(
                                    child: Text(
                                      'TOTAL SERIES',
                                      style: TextStyle(color: Color(0xFFAEE084), fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                              rows: [
                                ...sortedMuscles.map((muscle) {
                                  final exCount = exercisesCountByMuscle[muscle] ?? 0;
                                  final daySeries = setsMatrix[muscle] ?? [];
                                  final totalSeries = daySeries.fold<int>(0, (s, v) => s + v);
                                  final isActive = exCount > 0 || totalSeries > 0;

                                  return DataRow(
                                    color: isActive
                                        ? WidgetStateProperty.all(primaryColor.withValues(alpha: 0.06))
                                        : null,
                                    cells: [
                                      DataCell(
                                        Text(
                                          muscle,
                                          style: TextStyle(
                                            color: isActive ? Colors.white : Colors.white54,
                                            fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            '$exCount ej',
                                            style: TextStyle(
                                              color: isActive ? Colors.white : Colors.white30,
                                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (int d = 0; d < orderedDays.length; d++)
                                        DataCell(
                                          Center(
                                            child: Text(
                                              '${daySeries.length > d ? daySeries[d] : 0}',
                                              style: TextStyle(
                                                color: (daySeries.length > d && daySeries[d] > 0)
                                                    ? primaryColor
                                                    : Colors.white24,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            '$totalSeries',
                                            style: TextStyle(
                                              color: isActive ? primaryColor : Colors.white30,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // TAB 2: TABLA ESTRUCTURADA POR DÍA
                      ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: orderedDays.length,
                        itemBuilder: (context, idx) {
                          final weekday = orderedDays[idx].key;
                          final plan = orderedDays[idx].value;
                          final flatRows = <({String muscle, RoutineExercise ex, String sets})>[];
                          for (final w in plan.workouts) {
                            for (final ex in w.exercises) {
                              flatRows.add((
                                muscle: _inferMuscleCategory(ex.workoutId, ex.workoutName, plan.muscleFocus),
                                ex: ex,
                                sets: w.sets.isEmpty ? '0' : w.sets,
                              ));
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161F2C),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF881337),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_weekdayLabel(weekday).toUpperCase()}: ${plan.name.isEmpty ? "SIN NOMBRE" : plan.name.toUpperCase()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${flatRows.length} ejercicios',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (flatRows.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text(
                                      'Aún no has añadido ejercicios a este día.',
                                      style: TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  )
                                else
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowHeight: 32,
                                      dataRowMinHeight: 34,
                                      dataRowMaxHeight: 40,
                                      columnSpacing: 16,
                                      horizontalMargin: 12,
                                      columns: const [
                                        DataColumn(label: Text('Músculo', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Ejercicio', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Series', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Reps', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Peso', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                      ],
                                      rows: flatRows.map((row) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFBE123C).withValues(alpha: 0.22),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  row.muscle,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(row.ex.workoutName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5))),
                                            DataCell(Text(row.sets, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 12))),
                                            DataCell(Text(row.ex.reps.isEmpty ? '--' : row.ex.reps, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                            DataCell(Text(row.ex.weight.isEmpty ? '--' : '${row.ex.weight}kg', style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveMuscleCounterCard() {
    final bool useWeekly = _isCreateMode && _selectedWeekdays.length > 1 && _showWeeklyCounterInCard;
    final stats = _computeMuscleStats(weeklyScope: useWeekly);
    final entries = stats.entries.toList()
      ..sort((a, b) {
        final bySets = b.value.sets.compareTo(a.value.sets);
        if (bySets != 0) return bySets;
        return b.value.exercises.compareTo(a.value.exercises);
      });

    final int totalExercises = entries.fold<int>(0, (s, e) => s + e.value.exercises);
    final int totalSets = entries.fold<int>(0, (s, e) => s + e.value.sets);
    final int totalMuscles = entries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF881337).withValues(alpha: 0.28),
            const Color(0xFF161F2C),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTADOR MUSCULAR EN TIEMPO REAL',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      useWeekly
                          ? 'Acumulado de la semana (${_selectedWeekdays.length} días)'
                          : (_isCreateMode && _activeWeekday != null
                              ? 'Conteo de ${_weekdayLabel(_activeWeekday!)}'
                              : 'Conteo de la rutina actual'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showLiveTrackingAndCounterSheet,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF881337),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.table_chart_rounded, size: 14),
                label: const Text(
                  'Ver Tabla',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_isCreateMode && _selectedWeekdays.length > 1) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showWeeklyCounterInCard = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_showWeeklyCounterInCard
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _activeWeekday != null
                              ? 'Solo ${_weekdayLabel(_activeWeekday!)}'
                              : 'Este Día',
                          style: TextStyle(
                            color: !_showWeeklyCounterInCard
                                ? backgroundColor
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showWeeklyCounterInCard = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _showWeeklyCounterInCard
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Toda la Semana (${_selectedWeekdays.length}d)',
                          style: TextStyle(
                            color: _showWeeklyCounterInCard
                                ? backgroundColor
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickMetricChip(
                icon: Icons.fitness_center_rounded,
                label: 'Ejercicios',
                value: '$totalExercises',
              ),
              const SizedBox(width: 8),
              _buildQuickMetricChip(
                icon: Icons.repeat_rounded,
                label: 'Series totales',
                value: '$totalSets',
                highlight: true,
              ),
              const SizedBox(width: 8),
              _buildQuickMetricChip(
                icon: Icons.accessibility_new_rounded,
                label: 'Músculos',
                value: '$totalMuscles',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Añade ejercicios abajo para ver cuántos ejercicios y series lleva cada músculo en tiempo real.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11.5,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((entry) {
                final muscle = entry.key;
                final exCount = entry.value.exercises;
                final setsCount = entry.value.sets;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        muscle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${exCount}ej • ${setsCount}s',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickMetricChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: highlight ? primaryColor : Colors.white60,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: highlight ? primaryColor : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveTrackingAndCounterSheet() {
    _saveActiveDayDraft();
    final dayPlans = _getEffectiveDayPlans();
    final orderedDays = dayPlans.entries.toList();

    // Calcular matriz por músculo: {músculo: {exercisesTotal, setsByDay, setsTotal}}
    final allMuscles = <String>{
      ...MuscleConstants.specificMuscles,
    };

    for (final entry in orderedDays) {
      final plan = entry.value;
      for (final w in plan.workouts) {
        for (final ex in w.exercises) {
          allMuscles.add(_inferMuscleCategory(ex.workoutId, ex.workoutName, plan.muscleFocus));
        }
      }
    }

    final Map<String, List<int>> setsMatrix = {};
    final Map<String, int> exercisesCountByMuscle = {};
    for (final m in allMuscles) {
      setsMatrix[m] = List.generate(orderedDays.length, (_) => 0);
      exercisesCountByMuscle[m] = 0;
    }

    for (int d = 0; d < orderedDays.length; d++) {
      final plan = orderedDays[d].value;
      for (final w in plan.workouts) {
        final sCount = int.tryParse(w.sets.trim()) ?? 0;
        for (final ex in w.exercises) {
          final muscle = _inferMuscleCategory(ex.workoutId, ex.workoutName, plan.muscleFocus);
          setsMatrix[muscle]![d] += sCount;
          exercisesCountByMuscle[muscle] = (exercisesCountByMuscle[muscle] ?? 0) + 1;
        }
      }
    }

    final sortedMuscles = allMuscles.toList()
      ..sort((a, b) {
        final exA = exercisesCountByMuscle[a] ?? 0;
        final exB = exercisesCountByMuscle[b] ?? 0;
        if ((exA > 0) != (exB > 0)) return exB.compareTo(exA);
        final setsA = setsMatrix[a]?.fold<int>(0, (s, v) => s + v) ?? 0;
        final setsB = setsMatrix[b]?.fold<int>(0, (s, v) => s + v) ?? 0;
        return setsB.compareTo(setsA);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF11151C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TABLA Y CONTADOR MUSCULAR EN VIVO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              'Resumen en tiempo real de la rutina que estás armando',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientTrackingSheetPage(
                                clientId: widget.clientId,
                                clientName: widget.clientEmail.split('@').first,
                                clientEmail: widget.clientEmail,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text(
                          'Historial',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicatorColor: primaryColor,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    tabs: const [
                      Tab(text: 'Contador Muscular'),
                      Tab(text: 'Tabla por Día'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: CONTADOR MUSCULAR (EJERCICIOS + SERIES POR DÍA + TOTAL)
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF881337)),
                              headingRowHeight: 38,
                              dataRowMinHeight: 34,
                              dataRowMaxHeight: 38,
                              columnSpacing: 16,
                              horizontalMargin: 12,
                              border: TableBorder.all(color: const Color(0xFF334155), width: 0.8),
                              columns: [
                                const DataColumn(
                                  label: Text(
                                    'MÚSCULO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                                  ),
                                ),
                                const DataColumn(
                                  label: Center(
                                    child: Text(
                                      'EJERCICIOS',
                                      style: TextStyle(color: Color(0xFFAEE084), fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                ),
                                for (int d = 0; d < orderedDays.length; d++)
                                  DataColumn(
                                    label: Center(
                                      child: Text(
                                        _weekdayLabel(orderedDays[d].key).substring(0, 3).toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                const DataColumn(
                                  label: Center(
                                    child: Text(
                                      'TOTAL SERIES',
                                      style: TextStyle(color: Color(0xFFAEE084), fontWeight: FontWeight.w900, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                              rows: [
                                ...sortedMuscles.map((muscle) {
                                  final exCount = exercisesCountByMuscle[muscle] ?? 0;
                                  final daySeries = setsMatrix[muscle] ?? [];
                                  final totalSeries = daySeries.fold<int>(0, (s, v) => s + v);
                                  final isActive = exCount > 0 || totalSeries > 0;

                                  return DataRow(
                                    color: isActive
                                        ? WidgetStateProperty.all(primaryColor.withValues(alpha: 0.06))
                                        : null,
                                    cells: [
                                      DataCell(
                                        Text(
                                          muscle,
                                          style: TextStyle(
                                            color: isActive ? Colors.white : Colors.white54,
                                            fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            '$exCount ej',
                                            style: TextStyle(
                                              color: isActive ? Colors.white : Colors.white30,
                                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (int d = 0; d < orderedDays.length; d++)
                                        DataCell(
                                          Center(
                                            child: Text(
                                              '${daySeries.length > d ? daySeries[d] : 0}',
                                              style: TextStyle(
                                                color: (daySeries.length > d && daySeries[d] > 0)
                                                    ? primaryColor
                                                    : Colors.white24,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            '$totalSeries',
                                            style: TextStyle(
                                              color: isActive ? primaryColor : Colors.white30,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // TAB 2: TABLA ESTRUCTURADA POR DÍA
                      ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: orderedDays.length,
                        itemBuilder: (context, idx) {
                          final weekday = orderedDays[idx].key;
                          final plan = orderedDays[idx].value;
                          final flatRows = <({String muscle, RoutineExercise ex, String sets})>[];
                          for (final w in plan.workouts) {
                            for (final ex in w.exercises) {
                              flatRows.add((
                                muscle: _inferMuscleCategory(ex.workoutId, ex.workoutName, plan.muscleFocus),
                                ex: ex,
                                sets: w.sets.isEmpty ? '0' : w.sets,
                              ));
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161F2C),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF881337),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_weekdayLabel(weekday).toUpperCase()}: ${plan.name.isEmpty ? "SIN NOMBRE" : plan.name.toUpperCase()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${flatRows.length} ejercicios',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (flatRows.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text(
                                      'Aún no has añadido ejercicios a este día.',
                                      style: TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  )
                                else
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowHeight: 32,
                                      dataRowMinHeight: 34,
                                      dataRowMaxHeight: 40,
                                      columnSpacing: 16,
                                      horizontalMargin: 12,
                                      columns: const [
                                        DataColumn(label: Text('Músculo', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Ejercicio', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Series', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Reps', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                        DataColumn(label: Text('Peso', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11))),
                                      ],
                                      rows: flatRows.map((row) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFBE123C).withValues(alpha: 0.22),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  row.muscle,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(row.ex.workoutName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5))),
                                            DataCell(Text(row.sets, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 12))),
                                            DataCell(Text(row.ex.reps.isEmpty ? '--' : row.ex.reps, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                            DataCell(Text(row.ex.weight.isEmpty ? '--' : '${row.ex.weight}kg', style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.initialRoutineId == null ? 'CREAR RUTINA' : 'EDITAR RUTINA', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        actions: [
          IconButton(
            onPressed: _showLiveTrackingAndCounterSheet,
            icon: const Icon(Icons.table_chart_rounded, color: Color(0xFFF43F5E)),
            tooltip: 'Ver Tabla y Contador Muscular',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_clientHasCompletedDataSheet == false) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Medidas iniciales pendientes del cliente',
                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Puedes crear y guardar la rutina con normalidad. Al cliente se le solicitarán sus medidas obligatorias cuando inicie su plan por primera vez.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _buildSectionTitle('Rutina para ${widget.clientEmail}'),
            const SizedBox(height: 24),
            if (widget.initialRoutineId != null)
              Container(
                decoration: BoxDecoration(color: surfaceColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: surfaceColor.withValues(alpha: 0.2))),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => _clientRoutines[_dateOnlyLocal(day)] ?? [],
                  onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = _dateOnlyLocal(selectedDay); _focusedDay = focusedDay; }),
                  calendarStyle: CalendarStyle(selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: secondaryColor.withValues(alpha: 0.3), shape: BoxShape.circle), defaultTextStyle: const TextStyle(color: Colors.white)),
                  headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor), rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Días de la Semana 1', subtitle: 'Define la estructura; se duplicará por todo el plan', icon: Icons.view_week_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekdays.map(_buildWeekdayTile).toList(),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: primaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Fecha de inicio: ${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Icon(Icons.edit_calendar, color: secondaryColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDurationSelector(),
                    const SizedBox(height: 16),
                    _buildPlanSummary(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
             const SizedBox(height: 20),
             _buildActiveDayBanner(),
             const SizedBox(height: 20),
             _buildSectionTitle('Datos de la rutina', icon: Icons.assignment_rounded),
             const SizedBox(height: 12),
             TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration(label: 'Nombre de la Rutina', hint: 'Ej: Empuje Potencia', icon: Icons.edit_rounded)),
             const SizedBox(height: 12),
             TextField(
               controller: _nutritionPlanUrlController,
               style: const TextStyle(color: Colors.white),
               decoration: _buildInputDecoration(
                 label: 'PDF Plan de Alimentación (Opcional)',
                 hint: 'Ej: https://ejemplo.com/plan.pdf',
                 icon: Icons.file_download_rounded,
               ),
             ),
             const SizedBox(height: 12),
             TextField(
               controller: _notesController,
               style: const TextStyle(color: Colors.white),
               maxLines: 3,
               minLines: 2,
               decoration: _buildInputDecoration(
                 label: 'Notas de la entrenadora (Opcional)',
                 hint: 'Ej: Enfócate en la técnica, descansa 60s entre series...',
                 icon: Icons.sticky_note_2_rounded,
               ),
             ),
             const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDropdownField(label: 'Intensidad', value: _selectedIntensity, items: _intensities, onChanged: (v) => setState(() => _selectedIntensity = v!))),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdownField(label: 'Nivel', value: _selectedLevel, items: _levels, onChanged: (v) => setState(() => _selectedLevel = v!))),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Enfoque Muscular', icon: Icons.accessibility_new_rounded),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: _muscleGroups.map((muscle) {
                final isSelected = _selectedMuscles.contains(muscle);
                return FilterChip(
                  label: Text(muscle), selected: isSelected, onSelected: (s) => setState(() => s ? _selectedMuscles.add(muscle) : _selectedMuscles.remove(muscle)),
                  selectedColor: primaryColor.withValues(alpha: 0.3), checkmarkColor: primaryColor, labelStyle: TextStyle(color: isSelected ? primaryColor : Colors.white70),
                  backgroundColor: surfaceColor.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? primaryColor : surfaceColor.withValues(alpha: 0.2))),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _buildLiveMuscleCounterCard(),
            if (!_isCreateMode && _editingTotalWeeks > 1) ...[
              const SizedBox(height: 20),
              _buildEditMultiWeekSelector(),
            ],
            const SizedBox(height: 20),
            _buildLiveMuscleCounterCard(),
            const SizedBox(height: 20),
            _buildSectionTitle('Ejercicios Seleccionados', icon: Icons.checklist_rounded),
            const SizedBox(height: 12),
            if (selectedWorkouts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                ),
                child: const Text('Sin ejercicios seleccionados.', style: TextStyle(color: Colors.white70)),
              )
             else
               ListView.builder(
                 shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: selectedWorkouts.length,
                  itemBuilder: (context, index) {
                    final item = selectedWorkouts[index];
                    return Container(
                      key: ObjectKey(item),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con series y botón eliminar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ejercicio ${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildSmallField(
                                      key: ValueKey('sets_${identityHashCode(item)}'),
                                      label: 'Series',
                                      initialValue: item.sets,
                                      onChanged: (v) {
                                        setState(() {
                                          item.sets = v;
                                          _saveActiveDayDraft();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => setState(() {
                                  selectedWorkouts.removeAt(index);
                                  _saveActiveDayDraft();
                                }),
                                tooltip: 'Eliminar ejercicio',
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Colors.white10),
                          // Ejercicios (incluyendo supersets)
                          ...item.exercises.asMap().entries.map((entry) {
                            final exIdx = entry.key;
                            final ex = entry.value;
                            return Column(
                              key: ObjectKey(ex),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (exIdx > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orangeAccent.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.link, color: Colors.orangeAccent, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          "SUPERSET",
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            ex.workoutName.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _inferMuscleCategory(ex.workoutId, ex.workoutName, _selectedMuscles),
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.exercises.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() {
                                          item.exercises.removeAt(exIdx);
                                          _saveActiveDayDraft();
                                        }),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Eliminar del superset',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildNumericStepper(
                                      key: ValueKey('reps_${identityHashCode(ex)}'),
                                      label: 'Reps',
                                      value: ex.reps,
                                      onChanged: (v) => setState(() => ex.reps = v),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildNumericStepper(
                                      key: ValueKey('weight_${identityHashCode(ex)}'),
                                      label: 'Peso',
                                      value: ex.weight,
                                      suffix: 'kg',
                                      onChanged: (v) => setState(() => ex.weight = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                // Campo de descripción
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: TextFormField(
                                      key: ValueKey('desc_${identityHashCode(ex)}'),
                                      initialValue: ex.description,
                                      maxLines: 2,
                                      minLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      onChanged: (v) {
                                        final wasEmpty = ex.description.isEmpty;
                                        ex.description = v;
                                        if (wasEmpty != v.isEmpty) {
                                          setState(() {});
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Descripción opcional',
                                        labelStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                        hintText: 'Ej: En el último set con reducción...',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          fontSize: 11,
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: primaryColor.withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        suffixIcon: ex.description.isNotEmpty
                                            ? Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.note_rounded,
                                                  color: primaryColor.withValues(alpha: 0.6),
                                                  size: 18,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }),
                          if (item.exercises.length < 2)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: secondaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: secondaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: TextButton.icon(
                                onPressed: () => _showAddExerciseToSupersetDialog(index),
                                icon: Icon(
                                  Icons.add,
                                  color: secondaryColor,
                                  size: 18,
                                ),
                                label: Text(
                                  "AÑADIR SUPERSET",
                                  style: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
             const SizedBox(height: 24),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(child: _buildSectionTitle('Ejercicios Disponibles', icon: Icons.fitness_center_rounded)),
                 TextButton.icon(
                   onPressed: () async {
                     await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateWorkoutPage()));
                     loadWorkouts();
                   },
                   icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
                   label: Text("CREAR NUEVO", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                 ),
               ],
             ),
             const SizedBox(height: 12),
             if (_isLoadingWorkouts)
               Center(child: CircularProgressIndicator(color: primaryColor))
             else if (availableWorkouts.isEmpty)
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: surfaceColor.withValues(alpha: 0.08),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                 ),
                 child: const Text('No hay ejercicios creados todavia. Usa "CREAR NUEVO".', style: TextStyle(color: Colors.white70)),
               )
             else
               Column(
                 children: [
                   // Barra de búsqueda
                   TextField(
                     onChanged: (value) {
                       setState(() {
                         _workoutSearchQuery = value;
                         _filterWorkouts();
                       });
                     },
                     style: const TextStyle(color: Colors.white),
                     decoration: InputDecoration(
                       hintText: 'Buscar por nombre o músculo...',
                       hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                       prefixIcon: Icon(Icons.search, color: primaryColor),
                       suffixIcon: _workoutSearchQuery.isNotEmpty
                           ? IconButton(
                               icon: const Icon(Icons.clear, color: Colors.white),
                               onPressed: () {
                                 setState(() {
                                   _workoutSearchQuery = '';
                                   _filterWorkouts();
                                 });
                               },
                             )
                           : null,
                       filled: true,
                       fillColor: Colors.white.withValues(alpha: 0.05),
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(14),
                         borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                       ),
                       enabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(14),
                         borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                       ),
                       focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(14),
                         borderSide: BorderSide(color: primaryColor, width: 1.5),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   // Lista de ejercicios mejorada
                   if (filteredWorkouts.isEmpty)
                     Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: surfaceColor.withValues(alpha: 0.08),
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                       ),
                        child: Text(
                          'No se encontraron ejercicios con "$_workoutSearchQuery"',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                     )
                   else
                     SizedBox(
                       height: 400,
                       child: GridView.builder(
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                           crossAxisCount: 2,
                           childAspectRatio: 1.3,
                           crossAxisSpacing: 12,
                           mainAxisSpacing: 12,
                         ),
                         itemCount: filteredWorkouts.length,
                         itemBuilder: (context, index) {
                           final workout = filteredWorkouts[index];
                           return GestureDetector(
                             onTap: () => _addWorkoutToRoutine(workout.id, workout['name']),
                             child: Container(
                               decoration: BoxDecoration(
                                 color: surfaceColor.withValues(alpha: 0.15),
                                 borderRadius: BorderRadius.circular(16),
                                 border: Border.all(
                                   color: primaryColor.withValues(alpha: 0.3),
                                   width: 1.5,
                                 ),
                               ),
                               child: Stack(
                                 children: [
                                   // Fondo decorativo
                                   Positioned(
                                     right: -20,
                                     top: -20,
                                     child: Container(
                                       width: 80,
                                       height: 80,
                                       decoration: BoxDecoration(
                                         color: primaryColor.withValues(alpha: 0.08),
                                         shape: BoxShape.circle,
                                       ),
                                     ),
                                   ),
                                   // Contenido
                                   Padding(
                                     padding: const EdgeInsets.all(12),
                                     child: Column(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Row(
                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                           children: [
                                             Expanded(
                                               child: Text(
                                                 workout['name'],
                                                 style: const TextStyle(
                                                   color: Colors.white,
                                                   fontWeight: FontWeight.bold,
                                                   fontSize: 13,
                                                 ),
                                                 maxLines: 2,
                                                 overflow: TextOverflow.ellipsis,
                                               ),
                                             ),
                                           ],
                                         ),
                                         Row(
                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                           children: [
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                               decoration: BoxDecoration(
                                                 color: primaryColor.withValues(alpha: 0.2),
                                                 borderRadius: BorderRadius.circular(8),
                                               ),
                                               child: Text(
                                                 'Añadir',
                                                 style: TextStyle(
                                                   color: primaryColor,
                                                   fontSize: 11,
                                                   fontWeight: FontWeight.bold,
                                                 ),
                                               ),
                                             ),
                                             Icon(
                                               Icons.fitness_center_rounded,
                                               color: primaryColor.withValues(alpha: 0.6),
                                               size: 18,
                                             ),
                                           ],
                                         ),
                                       ],
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           );
                         },
                       ),
                     ),
                 ],
               ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: isLoading ? null : _saveRoutine, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: backgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black)) : Text(_isCreateMode ? 'GUARDAR RUTINAS' : 'GUARDAR RUTINA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: primaryColor), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)), labelStyle: TextStyle(color: primaryColor));
  }

  Widget _buildDropdownField({required String label, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: value, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white)))).toList(), onChanged: onChanged,
          dropdownColor: backgroundColor, decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: primaryColor), border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildSmallField({Key? key, required String label, required String initialValue, required Function(String) onChanged}) {
    return Expanded(
      key: key,
      child: TextFormField(
        key: key != null ? ValueKey('field_${key.toString()}') : null,
        initialValue: initialValue,
        keyboardType: TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          labelStyle: TextStyle(color: primaryColor, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildNumericStepper({Key? key, required String label, required String value, String? suffix, required Function(String) onChanged}) {
    // Use a TextEditingController created on the fly to keep the UI simple; rebuilds will reset cursor but keep data consistent.
    final controller = TextEditingController(text: value);
    int current = int.tryParse(value) ?? 0;
    return Expanded(
      key: key,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
              onPressed: () {
                current = (int.tryParse(controller.text) ?? current) - 1;
                if (current < 0) current = 0;
                controller.text = current.toString();
                onChanged(controller.text);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) {
                onChanged(v);
                // update local current
                current = int.tryParse(v) ?? current;
                if (mounted) setState(() {});
              },
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                suffixText: suffix,
                suffixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: TextStyle(color: primaryColor, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white70, size: 18),
              onPressed: () {
                current = (int.tryParse(controller.text) ?? current) + 1;
                controller.text = current.toString();
                onChanged(controller.text);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseToSupersetDialog(int routineIndex) {
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = searchQuery.isEmpty
                ? availableWorkouts
                : availableWorkouts.where((w) {
                    final data = w.data() as Map<String, dynamic>? ?? {};
                    final name = (data['name'] as String? ?? '').toLowerCase();
                    final general = (data['generalMuscles'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ??
                        ((data['muscleFocus'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? []);
                    final specific = (data['specificMuscles'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
                    final q = searchQuery.toLowerCase();
                    return name.contains(q) || general.any((m) => m.contains(q)) || specific.any((m) => m.contains(q));
                  }).toList();

            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  const Text("AÑADIR AL SUPERSET", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 18),
                  // Campo de búsqueda
                  TextField(
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar ejercicios...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search, color: primaryColor),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white),
                              onPressed: () {
                                setModalState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: filteredList.isEmpty
                        ? Center(
                            child: Text(
                              searchQuery.isEmpty
                                  ? 'No hay ejercicios disponibles'
                                  : 'No se encontraron ejercicios',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final workout = filteredList[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: surfaceColor.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: surfaceColor.withValues(alpha: 0.2)),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.fitness_center_rounded, color: primaryColor, size: 20),
                                    ),
                                    title: Text(
                                      workout['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    trailing: Container(
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.add, color: primaryColor, size: 20),
                                        onPressed: () {
                                          _addExerciseToSuperset(routineIndex, workout.id, workout['name']);
                                          Navigator.pop(context);
                                        },
                                        iconSize: 20,
                                      ),
                                    ),
                                    onTap: () {
                                      _addExerciseToSuperset(routineIndex, workout.id, workout['name']);
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR", style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.bold))),
                ],
              ),
            );
          },
        );
      }
    );
  }
}
