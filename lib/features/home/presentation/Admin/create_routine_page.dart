import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'create_workout_page.dart';

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

  RoutineDayPlan({
    required this.name,
    required this.muscleFocus,
    required this.intensity,
    required this.level,
    required this.workouts,
    this.nutritionPlanUrl = '',
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
  TextEditingController _nutritionPlanUrlController = TextEditingController();

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

  static const int _repeatWeeks = 4;
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
  }

  void _clearEditorForCreateMode() {
    _nameController.clear();
    _selectedMuscles = [];
    _selectedIntensity = 'Alta';
    _selectedLevel = 'Intermedio';
    selectedWorkouts = [];
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

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        ],
      ],
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
  }

   void _prefillForEdit() {
     final initial = widget.initialRoutineData;
     if (initial == null) return;

     _nameController.text = (initial['name'] ?? '').toString();
     _nutritionPlanUrlController.text = (initial['nutritionPlanUrl'] ?? '').toString();
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
      filteredWorkouts = availableWorkouts
          .where((workout) =>
              (workout['name'] as String).toLowerCase().contains(query))
          .toList();
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
      for (var doc in routinesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final DateTime date = (data['date'] as Timestamp).toDate();
        final DateTime normalizedDate = _dateOnlyLocal(date);
        newRoutines.putIfAbsent(normalizedDate, () => []).add(data);
      }
      if (!mounted) return;
      setState(() {
        _clientRoutines.clear();
        _clientRoutines.addAll(newRoutines);
        _completedRoutineIds.clear();
        _completedRoutineIds.addAll(completedIds);
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_friendlyErrorMessage(e));
    }
  }

  void _addWorkoutToRoutine(String workoutId, String workoutName) {
    setState(() {
      selectedWorkouts.add(RoutineWorkout(exercises: [RoutineExercise(workoutId: workoutId, workoutName: workoutName)]));
    });
  }

  void _addExerciseToSuperset(int index, String workoutId, String workoutName) {
    if (selectedWorkouts[index].exercises.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máximo 2 ejercicios por serie'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() {
      selectedWorkouts[index].exercises.add(RoutineExercise(workoutId: workoutId, workoutName: workoutName));
    });
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
          'clientId': widget.clientId,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        };

        final DateTime selectedDate = _dateOnlyLocal(_selectedDay!);
        final DateTime storageDate = _dateForStorage(selectedDate);
        await FirebaseFirestore.instance.collection('routines').doc(widget.initialRoutineId).update({...dataToSave, 'date': Timestamp.fromDate(storageDate)});
        if (!mounted) return;
        _showSuccessSnackBar('Rutina actualizada');
      } else {
        final datesToCreate = _buildDatesForFourWeeks(_startDate, _selectedWeekdays);
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

        for (final day in datesToCreate) {
          final key = _dateKey(day);
          final storageDate = _dateForStorage(day);
          final existingId = existingByDay[key];
          final plan = _weekdayPlans[day.weekday]!;
           final dataToSave = {
             'name': plan.name,
             'workouts': plan.workouts.map((workout) => workout.toMap()).toList(),
             'muscleFocus': plan.muscleFocus,
             'intensity': plan.intensity,
             'level': plan.level,
             'clientId': widget.clientId,
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

  List<DateTime> _buildDatesForFourWeeks(DateTime startDate, Set<int> weekdays) {
    if (weekdays.isEmpty) return [];

    final start = _dateOnlyLocal(startDate);
    final endExclusive = start.add(const Duration(days: _repeatWeeks * 7));
    final dates = <DateTime>[];

    for (DateTime day = start; day.isBefore(endExclusive); day = day.add(const Duration(days: 1))) {
      if (weekdays.contains(day.weekday)) {
        dates.add(_dateOnlyLocal(day));
      }
    }

    return dates;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.initialRoutineId == null ? 'CREAR RUTINA' : 'EDITAR RUTINA', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Rutina para ${widget.clientEmail}'),
            const SizedBox(height: 32),
            if (widget.initialRoutineId != null)
              Container(
                decoration: BoxDecoration(color: surfaceColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: surfaceColor.withValues(alpha: 0.2))),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
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
                    _buildSectionTitle('Dias de la semana'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekdays.map(_buildWeekdayTile).toList(),
                    ),
                    if (_selectedWeekdays.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekdays
                            .where((entry) => _selectedWeekdays.contains(entry.key))
                            .map((entry) {
                          final isActive = _activeWeekday == entry.key;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive) ...[
                                  Icon(Icons.edit, size: 14, color: primaryColor),
                                  const SizedBox(width: 6),
                                ],
                                Text(entry.value),
                              ],
                            ),
                            selected: isActive,
                            onSelected: (_) {
                              setState(() {
                                _setActiveWeekday(entry.key);
                              });
                            },
                            selectedColor: primaryColor.withValues(alpha: 0.25),
                            labelStyle: TextStyle(color: isActive ? primaryColor : Colors.white70),
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            side: BorderSide(
                              color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
                    const SizedBox(height: 4),
                  ],
                ),
              ),
             const SizedBox(height: 32),
             _buildSectionTitle('Datos de la rutina'),
             const SizedBox(height: 8),
             TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration(label: 'Nombre de la Rutina', hint: 'Ej: Empuje Potencia', icon: Icons.edit_rounded)),
             const SizedBox(height: 16),
             TextField(
               controller: _nutritionPlanUrlController,
               style: const TextStyle(color: Colors.white),
               decoration: _buildInputDecoration(
                 label: 'PDF Plan de Alimentación (Opcional)',
                 hint: 'Ej: https://ejemplo.com/plan.pdf',
                 icon: Icons.file_download_rounded,
               ),
             ),
             const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildDropdownField(label: 'Intensidad', value: _selectedIntensity, items: _intensities, onChanged: (v) => setState(() => _selectedIntensity = v!))),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdownField(label: 'Nivel', value: _selectedLevel, items: _levels, onChanged: (v) => setState(() => _selectedLevel = v!))),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Enfoque Muscular'),
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
            const SizedBox(height: 32),
            _buildSectionTitle('Ejercicios Seleccionados'),
            const SizedBox(height: 16),
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
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
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
                                onPressed: () => setState(() => selectedWorkouts.removeAt(index)),
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
                                        onPressed: () => setState(() => item.exercises.removeAt(exIdx)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Eliminar del superset',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildSmallField(
                                      label: 'Reps',
                                      initialValue: ex.reps,
                                      onChanged: (v) => ex.reps = v,
                                    ),
                                    const SizedBox(width: 12),
                                    _buildSmallField(
                                      label: 'Peso',
                                      initialValue: ex.weight,
                                      onChanged: (v) => ex.weight = v,
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
                                      initialValue: ex.description,
                                      maxLines: 2,
                                      minLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      onChanged: (v) => ex.description = v,
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
             const SizedBox(height: 32),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildSectionTitle('Ejercicios Disponibles'),
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
                       hintText: 'Buscar ejercicios...',
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
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: isLoading ? null : _saveRoutine, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: backgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black)) : Text(_isCreateMode ? 'GUARDAR RUTINAS' : 'GUARDAR RUTINA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)))),
            const SizedBox(height: 40),
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

  Widget _buildSmallField({required String label, required String initialValue, required Function(String) onChanged}) {
    return Expanded(child: TextFormField(initialValue: initialValue, keyboardType: TextInputType.text, style: const TextStyle(color: Colors.white, fontSize: 14), onChanged: onChanged, decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))), labelStyle: TextStyle(color: primaryColor, fontSize: 12))));
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
                    .where((w) =>
                        (w['name'] as String).toLowerCase().contains(searchQuery.toLowerCase()))
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
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: surfaceColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                                ),
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
