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

  RoutineExercise({
    required this.workoutId,
    required this.workoutName,
    this.reps = '',
    this.weight = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'workoutName': workoutName,
      'reps': reps,
      'weight': weight,
    };
  }

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      workoutId: (map['workoutId'] ?? '').toString(),
      workoutName: (map['workoutName'] ?? '').toString(),
      reps: (map['reps'] ?? '').toString(),
      weight: (map['weight'] ?? '').toString(),
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
  List<RoutineWorkout> selectedWorkouts = [];
  List<String> _selectedMuscles = [];

  String _selectedIntensity = 'Alta';
  String _selectedLevel = 'Intermedio';

  final Map<DateTime, List<Map<String, dynamic>>> _clientRoutines = {};
  final Set<String> _completedRoutineIds = {};
  bool _loadingRoutines = false;

  final List<String> _muscleGroups = [
    'Piernas', 'Pecho', 'Espalda', 'Hombros', 'Bíceps', 'Tríceps', 'Abdominales', 'Cardio', 'Cuerpo Completo'
  ];

  final List<String> _intensities = ['Baja', 'Media', 'Alta'];
  final List<String> _levels = ['Principiante', 'Intermedio', 'Avanzado'];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool isLoading = false;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  DateTime _dateOnlyLocal(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime _dateForStorage(DateTime date) => DateTime(date.year, date.month, date.day, 12);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = _dateOnlyLocal(now);
    _prefillForEdit();
    loadWorkouts();
    _fetchClientRoutines();
  }

  void _prefillForEdit() {
    final initial = widget.initialRoutineData;
    if (initial == null) return;

    _nameController.text = (initial['name'] ?? '').toString();
    _selectedMuscles = List<String>.from((initial['muscleFocus'] as List<dynamic>? ?? []).map((e) => e.toString()));
    
    if (initial['intensity'] != null) _selectedIntensity = initial['intensity'];
    if (initial['level'] != null) _selectedLevel = initial['level'];

    final dateTs = initial['date'] as Timestamp?;
    if (dateTs != null) {
      final date = dateTs.toDate();
      final normalized = _dateOnlyLocal(date);
      _selectedDay = normalized;
      _focusedDay = normalized;
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> loadWorkouts() async {
    final snapshot = await FirebaseFirestore.instance.collection('workouts').get();
    if (!mounted) return;
    setState(() => availableWorkouts = snapshot.docs);
  }

  Future<void> _fetchClientRoutines() async {
    setState(() => _loadingRoutines = true);
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
        _loadingRoutines = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoutines = false);
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

    if (_selectedDay == null) { _showErrorSnackBar('Selecciona un día en el calendario'); return; }
    if (_nameController.text.trim().isEmpty) { _showErrorSnackBar('Ingresa un nombre para la rutina'); return; }
    if (_selectedMuscles.isEmpty) { _showErrorSnackBar('Selecciona al menos un enfoque muscular'); return; }
    if (selectedWorkouts.isEmpty) { _showErrorSnackBar('Añade al menos un ejercicio'); return; }

    for (var workout in selectedWorkouts) {
      if (workout.sets.trim().isEmpty) {
        _showErrorSnackBar('Ingresa el número de series para todos los ejercicios');
        return;
      }
      for (var exercise in workout.exercises) {
        if (exercise.reps.trim().isEmpty || exercise.weight.trim().isEmpty) {
          _showErrorSnackBar('Completa repeticiones y peso para ${exercise.workoutName}');
          return;
        }
      }
    }

    setState(() => isLoading = true);
    try {
      final DateTime selectedDate = _dateOnlyLocal(_selectedDay!);
      final DateTime storageDate = _dateForStorage(selectedDate);
      final workoutData = selectedWorkouts.map((workout) => workout.toMap()).toList();

      final dataToSave = {
        'name': _nameController.text.trim(),
        'workouts': workoutData,
        'muscleFocus': _selectedMuscles,
        'intensity': _selectedIntensity,
        'level': _selectedLevel,
        'clientId': widget.clientId,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      if (widget.initialRoutineId != null) {
        await FirebaseFirestore.instance.collection('routines').doc(widget.initialRoutineId).update({...dataToSave, 'date': Timestamp.fromDate(storageDate)});
        if (!mounted) return;
        _showSuccessSnackBar('Rutina actualizada');
      } else {
        final dayStart = selectedDate;
        final dayEnd = selectedDate.add(const Duration(days: 1));
        final existing = await FirebaseFirestore.instance.collection('routines').where('clientId', isEqualTo: widget.clientId).where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart)).where('date', isLessThan: Timestamp.fromDate(dayEnd)).get();

        if (existing.docs.isNotEmpty) {
          await FirebaseFirestore.instance.collection('routines').doc(existing.docs.first.id).update(dataToSave);
          if (!mounted) return;
          _showSuccessSnackBar('Rutina existente actualizada para este día');
        } else {
          await FirebaseFirestore.instance.collection('routines').add({...dataToSave, 'createdBy': user.uid, 'date': Timestamp.fromDate(storageDate), 'createdAt': FieldValue.serverTimestamp()});
          if (!mounted) return;
          _showSuccessSnackBar('Rutina guardada');
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  void _showSuccessSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));

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
            Text("Rutina para ${widget.clientEmail}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(color: surfaceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: surfaceColor.withOpacity(0.2))),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => _clientRoutines[_dateOnlyLocal(day)] ?? [],
                onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = _dateOnlyLocal(selectedDay); _focusedDay = focusedDay; }),
                calendarStyle: CalendarStyle(selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: secondaryColor.withOpacity(0.3), shape: BoxShape.circle), defaultTextStyle: const TextStyle(color: Colors.white)),
                headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor), rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor)),
              ),
            ),
            const SizedBox(height: 32),
            TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration(label: 'Nombre de la Rutina', hint: 'Ej: Empuje Potencia', icon: Icons.edit_rounded)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildDropdownField(label: 'Intensidad', value: _selectedIntensity, items: _intensities, onChanged: (v) => setState(() => _selectedIntensity = v!))),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdownField(label: 'Nivel', value: _selectedLevel, items: _levels, onChanged: (v) => setState(() => _selectedLevel = v!))),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Enfoque Muscular", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: _muscleGroups.map((muscle) {
                final isSelected = _selectedMuscles.contains(muscle);
                return FilterChip(
                  label: Text(muscle), selected: isSelected, onSelected: (s) => setState(() => s ? _selectedMuscles.add(muscle) : _selectedMuscles.remove(muscle)),
                  selectedColor: primaryColor.withOpacity(0.3), checkmarkColor: primaryColor, labelStyle: TextStyle(color: isSelected ? primaryColor : Colors.white70),
                  backgroundColor: surfaceColor.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? primaryColor : surfaceColor.withOpacity(0.2))),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Text("Ejercicios Seleccionados", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: selectedWorkouts.length,
              itemBuilder: (context, index) {
                final item = selectedWorkouts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: surfaceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: surfaceColor.withOpacity(0.2))),
                  child: Column(
                    children: [
                      Row(children: [ _buildSmallField(label: 'Series', initialValue: item.sets, onChanged: (v) => item.sets = v), const SizedBox(width: 20), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => selectedWorkouts.removeAt(index)))]),
                      const Divider(height: 32, color: Colors.white10),
                      ...item.exercises.asMap().entries.map((entry) {
                        final exIdx = entry.key; final ex = entry.value;
                        return Column(children: [
                          if (exIdx > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("SUPERSET", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                          Row(children: [Expanded(child: Text(ex.workoutName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))), if (item.exercises.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18), onPressed: () => setState(() => item.exercises.removeAt(exIdx)))]),
                          const SizedBox(height: 12),
                          Row(children: [_buildSmallField(label: 'Reps', initialValue: ex.reps, onChanged: (v) => ex.reps = v), const SizedBox(width: 12), _buildSmallField(label: 'Peso', initialValue: ex.weight, onChanged: (v) => ex.weight = v)]),
                          const SizedBox(height: 16),
                        ]);
                      }),
                      if (item.exercises.length < 2) TextButton.icon(onPressed: () => _showAddExerciseToSupersetDialog(index), icon: Icon(Icons.add, color: secondaryColor, size: 16), label: Text("AÑADIR SUPERSET", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Ejercicios Disponibles", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, itemCount: availableWorkouts.length,
                itemBuilder: (context, index) {
                  final workout = availableWorkouts[index];
                  return Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(backgroundColor: surfaceColor.withOpacity(0.1), label: Text(workout['name'], style: const TextStyle(color: Colors.white)), onPressed: () => _addWorkoutToRoutine(workout.id, workout['name'])));
                },
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: isLoading ? null : _saveRoutine, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: backgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black)) : const Text('GUARDAR RUTINA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: primaryColor), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)), labelStyle: TextStyle(color: primaryColor));
  }

  Widget _buildDropdownField({required String label, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white)))).toList(), onChanged: onChanged,
          dropdownColor: backgroundColor, decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: primaryColor), border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildSmallField({required String label, required String initialValue, required Function(String) onChanged}) {
    return Expanded(child: TextFormField(initialValue: initialValue, keyboardType: TextInputType.text, style: const TextStyle(color: Colors.white, fontSize: 14), onChanged: onChanged, decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))), labelStyle: TextStyle(color: primaryColor, fontSize: 12))));
  }

  void _showAddExerciseToSupersetDialog(int routineIndex) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) {
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
              const SizedBox(height: 12),
              Text("Selecciona un segundo ejercicio para esta serie", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableWorkouts.length,
                  itemBuilder: (context, index) {
                    final workout = availableWorkouts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: surfaceColor.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.fitness_center_rounded, color: primaryColor, size: 20),
                        ),
                        title: Text(workout['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCELAR", style: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold))),
            ],
          ),
        );
      }
    );
  }
}
