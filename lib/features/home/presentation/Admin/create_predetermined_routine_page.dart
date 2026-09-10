import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_workout_page.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/models/predetermined_routine.dart';

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
      description: (map['description'] ?? '').toString(),
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

class CreatePredeterminedRoutinePage extends StatefulWidget {
  final PredeterminedRoutine? routineToEdit;

  const CreatePredeterminedRoutinePage({super.key, this.routineToEdit});

  @override
  State<CreatePredeterminedRoutinePage> createState() =>
      _CreatePredeterminedRoutinePageState();
}

class _CreatePredeterminedRoutinePageState
    extends State<CreatePredeterminedRoutinePage> {
  // Campos promocionales extras
  final TextEditingController _promoTitleController = TextEditingController();
  final TextEditingController _promoDescController = TextEditingController();
  final TextEditingController _coverImageUrlController = TextEditingController();
  final TextEditingController _promoTagController = TextEditingController();

  // Campos del constructor de rutina (idénticos a CreateRoutinePage)
  final TextEditingController _dayNameController = TextEditingController();
  final TextEditingController _nutritionPlanUrlController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<DocumentSnapshot> availableWorkouts = [];
  List<DocumentSnapshot> filteredWorkouts = [];
  List<RoutineWorkout> selectedWorkouts = [];
  List<String> _selectedMuscles = [];
  String _workoutSearchQuery = '';

  String _selectedIntensity = 'Alta';
  String _selectedLevel = 'Intermedio';

  final List<String> _muscleGroups = [
    'Piernas',
    'Pecho',
    'Espalda',
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Abdominales',
    'Cardio',
    'Cuerpo Completo'
  ];

  final List<String> _intensities = ['Baja', 'Media', 'Alta'];
  final List<String> _levels = ['Principiante', 'Intermedio', 'Avanzado'];

  final Set<int> _selectedWeekdays = {};
  final Map<int, RoutineDayPlan> _weekdayPlans = {};
  int? _activeWeekday;

  int _durationWeeks = 4;
  static const List<int> _durationOptions = [1, 2, 4, 8, 12];
  static const List<MapEntry<int, String>> _weekdays = [
    MapEntry(DateTime.monday, 'Lunes'),
    MapEntry(DateTime.tuesday, 'Martes'),
    MapEntry(DateTime.wednesday, 'Miércoles'),
    MapEntry(DateTime.thursday, 'Jueves'),
    MapEntry(DateTime.friday, 'Viernes'),
    MapEntry(DateTime.saturday, 'Sábado'),
    MapEntry(DateTime.sunday, 'Domingo'),
  ];

  bool isLoading = false;
  bool _isLoadingWorkouts = false;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  bool get _isEditMode => widget.routineToEdit != null;

  @override
  void initState() {
    super.initState();
    _initDefaultState();
    loadWorkouts();
  }

  void _initDefaultState() {
    if (_isEditMode) {
      _prefillForEdit(widget.routineToEdit!);
    } else {
      _selectedWeekdays.add(DateTime.monday);
      _activeWeekday = DateTime.monday;
      _weekdayPlans[_activeWeekday!] = _emptyPlan();
    }
  }

  void _prefillForEdit(PredeterminedRoutine routine) {
    _promoTitleController.text = routine.name;
    _promoDescController.text = routine.description;
    _coverImageUrlController.text = routine.coverImageUrl;
    _promoTagController.text = routine.promoTag;
    _durationWeeks = routine.durationWeeks;

    for (final dayPlan in routine.days) {
      final weekday = dayPlan.targetWeekday;
      _selectedWeekdays.add(weekday);

      final workouts = dayPlan.workouts.map((w) {
        final sets = (w['sets'] ?? '4').toString();
        final rawExercises = w['exercises'] as List<dynamic>?;
        List<RoutineExercise> exercises = [];

        if (rawExercises != null && rawExercises.isNotEmpty) {
          exercises = rawExercises
              .whereType<Map<String, dynamic>>()
              .map((e) => RoutineExercise.fromMap(e))
              .toList();
        } else {
          exercises = [
            RoutineExercise(
              workoutId: (w['workoutId'] ?? '').toString(),
              workoutName: (w['workoutName'] ?? 'Ejercicio').toString(),
              reps: (w['reps'] ?? '12').toString(),
              weight: (w['weight'] ?? '').toString(),
              description: (w['description'] ?? w['notes'] ?? '').toString(),
            )
          ];
        }

        return RoutineWorkout(sets: sets, exercises: exercises);
      }).toList();

      _weekdayPlans[weekday] = RoutineDayPlan(
        name: dayPlan.name,
        muscleFocus: List<String>.from(dayPlan.muscleFocus),
        intensity: dayPlan.intensity,
        level: dayPlan.level,
        workouts: workouts,
        nutritionPlanUrl: dayPlan.nutritionPlanUrl,
        notes: dayPlan.notes,
      );
    }

    if (_selectedWeekdays.isNotEmpty) {
      _activeWeekday = _selectedWeekdays.first;
      _loadPlanIntoEditor(_weekdayPlans[_activeWeekday!]!);
    }
  }

  @override
  void dispose() {
    _promoTitleController.dispose();
    _promoDescController.dispose();
    _coverImageUrlController.dispose();
    _promoTagController.dispose();

    _dayNameController.dispose();
    _nutritionPlanUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
    return 'Día $weekday';
  }

  RoutineDayPlan _captureEditorPlan() {
    return RoutineDayPlan(
      name: _dayNameController.text.trim(),
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
    if (_activeWeekday == null) return;
    _weekdayPlans[_activeWeekday!] = _captureEditorPlan();
  }

  void _loadPlanIntoEditor(RoutineDayPlan plan) {
    _dayNameController.text = plan.name;
    _selectedMuscles = List<String>.from(plan.muscleFocus);
    _selectedIntensity = plan.intensity;
    _selectedLevel = plan.level;
    selectedWorkouts = _cloneWorkouts(plan.workouts);
    _nutritionPlanUrlController.text = plan.nutritionPlanUrl;
    _notesController.text = plan.notes;
  }

  void _setActiveWeekday(int weekday) {
    _saveActiveDayDraft();
    _activeWeekday = weekday;
    _loadPlanIntoEditor(_ensureDayPlan(weekday));
  }

  String? _validatePlan(RoutineDayPlan plan, String dayLabel) {
    if (plan.name.trim().isEmpty) {
      return 'Ingresa un nombre para la rutina de $dayLabel';
    }
    if (plan.muscleFocus.isEmpty) {
      return 'Selecciona enfoque muscular para $dayLabel';
    }
    if (plan.workouts.isEmpty) {
      return 'Añade al menos un ejercicio para $dayLabel';
    }

    for (var workout in plan.workouts) {
      if (workout.sets.trim().isEmpty) {
        return 'Ingresa series para todos los ejercicios de $dayLabel';
      }
      for (var exercise in workout.exercises) {
        if (exercise.reps.trim().isEmpty) {
          return 'Completa repeticiones en $dayLabel (${exercise.workoutName})';
        }
      }
    }

    return null;
  }

  bool _hasPlanData(int weekday) {
    final plan = _weekdayPlans[weekday];
    if (plan == null) return false;
    return plan.name.trim().isNotEmpty ||
        plan.muscleFocus.isNotEmpty ||
        plan.workouts.isNotEmpty;
  }

  Future<void> loadWorkouts() async {
    setState(() => _isLoadingWorkouts = true);
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('workouts').orderBy('name').get();
      if (!mounted) return;
      setState(() {
        availableWorkouts = snapshot.docs;
        _filterWorkouts();
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error cargando ejercicios: $e');
    } finally {
      if (mounted) setState(() => _isLoadingWorkouts = false);
    }
  }

  void _filterWorkouts() {
    if (_workoutSearchQuery.isEmpty) {
      filteredWorkouts = availableWorkouts;
    } else {
      final query = _workoutSearchQuery.toLowerCase();
      filteredWorkouts = availableWorkouts
          .where((workout) =>
              (workout['name'] as String).toLowerCase().contains(query))
          .toList();
    }
  }

  void _addWorkoutToRoutine(String workoutId, String workoutName) {
    setState(() {
      selectedWorkouts.add(
        RoutineWorkout(
          sets: '4',
          exercises: [
            RoutineExercise(
              workoutId: workoutId,
              workoutName: workoutName,
              reps: '12',
              weight: '',
            )
          ],
        ),
      );
    });
  }

  void _addExerciseToSuperset(int index, String workoutId, String workoutName) {
    if (selectedWorkouts[index].exercises.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo 2 ejercicios por serie'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      selectedWorkouts[index].exercises.add(
        RoutineExercise(
          workoutId: workoutId,
          workoutName: workoutName,
          reps: '12',
          weight: '',
        ),
      );
    });
  }

  Future<void> _savePromotion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final promoTitle = _promoTitleController.text.trim();
    if (promoTitle.isEmpty) {
      _showErrorSnackBar('Ingresa un título para la promoción');
      return;
    }

    if (_selectedWeekdays.isEmpty) {
      _showErrorSnackBar('Selecciona al menos un día de la semana');
      return;
    }

    _saveActiveDayDraft();

    // Validar cada día activo
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

    setState(() => isLoading = true);

    try {
      final orderedWeekdays = _selectedWeekdays.toList()..sort();
      final List<PredeterminedDayPlan> daysList = [];
      final Set<String> allMuscles = {};
      String generalIntensity = _selectedIntensity;
      String generalLevel = _selectedLevel;

      int dayNum = 1;
      for (final weekday in orderedWeekdays) {
        final plan = _weekdayPlans[weekday]!;
        allMuscles.addAll(plan.muscleFocus);
        generalIntensity = plan.intensity;
        generalLevel = plan.level;

        final workoutData = plan.workouts.map((w) => w.toMap()).toList();

        daysList.add(
          PredeterminedDayPlan(
            dayNumber: dayNum++,
            name: plan.name,
            targetWeekday: weekday,
            muscleFocus: plan.muscleFocus,
            intensity: plan.intensity,
            level: plan.level,
            workouts: workoutData,
            nutritionPlanUrl: plan.nutritionPlanUrl,
            notes: plan.notes,
          ),
        );
      }

      final dataToSave = {
        'name': promoTitle,
        'description': _promoDescController.text.trim(),
        'coverImageUrl': _coverImageUrlController.text.trim(),
        'promoTag': _promoTagController.text.trim(),
        'durationWeeks': _durationWeeks,
        'level': generalLevel,
        'intensity': generalIntensity,
        'muscleFocus': allMuscles.toList(),
        'days': daysList.map((d) => d.toMap()).toList(),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditMode) {
        await FirebaseFirestore.instance
            .collection('predetermined_routines')
            .doc(widget.routineToEdit!.id)
            .update(dataToSave);
      } else {
        await FirebaseFirestore.instance
            .collection('predetermined_routines')
            .add({
          ...dataToSave,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      _showSuccessSnackBar(
        _isEditMode ? 'Promoción actualizada con éxito' : 'Promoción creada con éxito',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );

  void _showSuccessSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

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
    final baseColor = isSelected ? primaryColor : Colors.white60;

    return GestureDetector(
      onTap: () => _toggleWeekdaySelection(entry.key, !isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 95,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withValues(alpha: 0.22)
              : isSelected
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? primaryColor
                : isSelected
                    ? primaryColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 2 : 1,
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
                Icon(_weekdayIcon(entry.key),
                    size: 14, color: baseColor.withValues(alpha: isSelected ? 1 : 0.7)),
                if (isConfigured)
                  Icon(Icons.check_circle,
                      size: 14, color: Colors.greenAccent.withValues(alpha: 0.95)),
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

  Future<void> _toggleWeekdaySelection(int weekday, bool selected) async {
    if (selected) {
      setState(() {
        _selectedWeekdays.add(weekday);
        _setActiveWeekday(weekday);
      });
      return;
    }

    if (_selectedWeekdays.length <= 1) {
      _showErrorSnackBar('Debe haber al menos un día en el plan');
      return;
    }

    final shouldConfirm = _hasPlanData(weekday);
    if (shouldConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          title: const Text('Quitar día', style: TextStyle(color: Colors.white)),
          content: Text(
            'Si quitas ${_weekdayLabel(weekday)} se perderá su configuración.',
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
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _selectedWeekdays.remove(weekday);
      _weekdayPlans.remove(weekday);
      if (_activeWeekday == weekday) {
        if (_selectedWeekdays.isNotEmpty) {
          _setActiveWeekday(_selectedWeekdays.first);
        } else {
          _activeWeekday = null;
        }
      }
    });
  }

  Widget _buildActiveDayBanner() {
    if (_activeWeekday == null) return const SizedBox();

    final orderedDays = _weekdays
        .where((entry) => _selectedWeekdays.contains(entry.key))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.15),
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
                    'EDITANDO DÍA DEL PROGRAMA',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    _weekdayLabel(_activeWeekday!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
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
                          color: isActive
                              ? primaryColor
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? primaryColor
                                : Colors.white.withValues(alpha: 0.12),
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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
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
              'Duración del plan promocional',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'La estructura configurada se multiplicará por el total de semanas al asignarla.',
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

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: TextStyle(color: primaryColor),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((i) => DropdownMenuItem(
                  value: i, child: Text(i, style: const TextStyle(color: Colors.white))))
              .toList(),
          onChanged: onChanged,
          dropdownColor: backgroundColor,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: primaryColor),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallField({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return Expanded(
      child: TextFormField(
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          labelStyle: TextStyle(color: primaryColor, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildNumericStepper({
    required String label,
    required String value,
    String? suffix,
    required Function(String) onChanged,
  }) {
    final controller = TextEditingController(text: value);
    int current = int.tryParse(value) ?? 0;
    return Expanded(
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
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
                current = int.tryParse(v) ?? current;
                if (mounted) setState(() {});
              },
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
                suffixText: suffix,
                suffixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: TextStyle(color: primaryColor, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
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
                : availableWorkouts
                    .where((w) => (w['name'] as String)
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                    .toList();

            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "AÑADIR AL SUPERSET",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
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
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: surfaceColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: surfaceColor.withValues(alpha: 0.2)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.fitness_center_rounded,
                                        color: primaryColor, size: 20),
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
                                        _addExerciseToSuperset(
                                            routineIndex, workout.id, workout['name']);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                  onTap: () {
                                    _addExerciseToSuperset(
                                        routineIndex, workout.id, workout['name']);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "CANCELAR",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'EDITAR PROMOCIÓN' : 'NUEVA PROMOCIÓN',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // SECCIÓN 1: DATOS EXTRAS DE LA PROMOCIÓN
            // ==========================================
            _buildSectionTitle(
              'Información de la Promoción',
              subtitle: 'Nombre comercial, descripción y portada que verán los clientes',
              icon: Icons.local_offer_rounded,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _promoTitleController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'Título de la Promoción',
                hint: 'Ej: Rutina Glúteos y Piernas 4 Semanas',
                icon: Icons.title_rounded,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promoDescController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              minLines: 2,
              decoration: _buildInputDecoration(
                label: 'Descripción de la Promoción',
                hint: 'Explica el objetivo, a quién va dirigida y beneficios del programa...',
                icon: Icons.description_rounded,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _coverImageUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      label: 'Imagen de Portada (URL)',
                      hint: 'https://...',
                      icon: Icons.image_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _promoTagController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      label: 'Etiqueta / Badge',
                      hint: 'Ej: 50% OFF',
                      icon: Icons.label_rounded,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ==========================================
            // SECCIÓN 2: DÍAS Y DURACIÓN (RUTINA)
            // ==========================================
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
                  _buildSectionTitle(
                    'Días de Entrenamiento Semanales',
                    subtitle: 'Selecciona los días que compondrán el programa de la promoción',
                    icon: Icons.view_week_rounded,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekdays.map(_buildWeekdayTile).toList(),
                  ),
                  const SizedBox(height: 20),
                  _buildDurationSelector(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Banner para cambiar de día activo
            _buildActiveDayBanner(),

            const SizedBox(height: 20),

            // ==========================================
            // SECCIÓN 3: RUTINA DEL DÍA ACTIVO
            // ==========================================
            _buildSectionTitle(
              'Rutina para ${_activeWeekday != null ? _weekdayLabel(_activeWeekday!) : ""}',
              subtitle: 'Configura nombre, ejercicios, series, reps y pesos',
              icon: Icons.assignment_rounded,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dayNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'Nombre de la Rutina del Día',
                hint: 'Ej: Pierna & Glúteo / Tren Superior',
                icon: Icons.edit_rounded,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nutritionPlanUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'PDF Plan de Alimentación (Opcional)',
                hint: 'Ej: https://drive.google.com/...',
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
                label: 'Notas / Indicaciones del día (Opcional)',
                hint: 'Ej: Realizar calentamiento articular previo, descanso 60s...',
                icon: Icons.sticky_note_2_rounded,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Intensidad',
                    value: _selectedIntensity,
                    items: _intensities,
                    onChanged: (v) => setState(() => _selectedIntensity = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Nivel',
                    value: _selectedLevel,
                    items: _levels,
                    onChanged: (v) => setState(() => _selectedLevel = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Enfoque Muscular', icon: Icons.accessibility_new_rounded),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _muscleGroups.map((muscle) {
                final isSelected = _selectedMuscles.contains(muscle);
                return FilterChip(
                  label: Text(muscle),
                  selected: isSelected,
                  onSelected: (s) => setState(() =>
                      s ? _selectedMuscles.add(muscle) : _selectedMuscles.remove(muscle)),
                  selectedColor: primaryColor.withValues(alpha: 0.3),
                  checkmarkColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? primaryColor : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: surfaceColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? primaryColor
                          : surfaceColor.withValues(alpha: 0.2),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // SECCIÓN 4: EJERCICIOS DEL DÍA
            // ==========================================
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
                child: const Text(
                  'Sin ejercicios seleccionados para este día. Elige de la lista abajo.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedWorkouts.length,
                itemBuilder: (context, index) {
                  final item = selectedWorkouts[index];
                  return Container(
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
                        // Header con series y eliminar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bloque de Ejercicio ${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildSmallField(
                                    label: 'Series',
                                    initialValue: item.sets,
                                    onChanged: (v) => item.sets = v,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () =>
                                  setState(() => selectedWorkouts.removeAt(index)),
                              tooltip: 'Eliminar ejercicio',
                            ),
                          ],
                        ),
                        const Divider(height: 32, color: Colors.white10),

                        // Ejercicios individuales / supersets
                        ...item.exercises.asMap().entries.map((entry) {
                          final exIdx = entry.key;
                          final ex = entry.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (exIdx > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
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
                                      Icon(Icons.link,
                                          color: Colors.orangeAccent, size: 14),
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
                                    child: Text(
                                      ex.workoutName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (item.exercises.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                          () => item.exercises.removeAt(exIdx)),
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
                                    label: 'Reps',
                                    value: ex.reps,
                                    onChanged: (v) => setState(() => ex.reps = v),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildNumericStepper(
                                    label: 'Peso',
                                    value: ex.weight,
                                    suffix: 'kg',
                                    onChanged: (v) => setState(() => ex.weight = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: TextFormField(
                                  initialValue: ex.description,
                                  maxLines: 2,
                                  minLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  onChanged: (v) => ex.description = v,
                                  decoration: InputDecoration(
                                    labelText: 'Descripción / indicación opcional',
                                    labelStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                    hintText: 'Ej: Pausa de 2 segundos en contracción...',
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
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: primaryColor.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
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
                              icon: Icon(Icons.add, color: secondaryColor, size: 18),
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

            // ==========================================
            // SECCIÓN 5: CATÁLOGO DE EJERCICIOS
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionTitle(
                    'Ejercicios Disponibles',
                    icon: Icons.fitness_center_rounded,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateWorkoutPage()),
                    );
                    loadWorkouts();
                  },
                  icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
                  label: Text(
                    "CREAR NUEVO",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
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
                child: const Text(
                  'No hay ejercicios creados todavía. Usa "CREAR NUEVO".',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              Column(
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _workoutSearchQuery = value;
                        _filterWorkouts();
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar ejercicios para añadir...',
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
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      height: 380,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.35,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredWorkouts.length,
                        itemBuilder: (context, index) {
                          final workout = filteredWorkouts[index];
                          return GestureDetector(
                            onTap: () =>
                                _addWorkoutToRoutine(workout.id, workout['name']),
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
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
                                              color:
                                                  primaryColor.withValues(alpha: 0.6),
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

            const SizedBox(height: 32),

            // Botón Guardar Promoción
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _savePromotion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'GUARDAR CAMBIOS' : 'GUARDAR PROMOCIÓN',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
