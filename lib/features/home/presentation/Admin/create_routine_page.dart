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
      // Keep flat fields for backward compatibility/simpler queries if only one exercise
      if (exercises.length == 1) ...{
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

  final Map<DateTime, List<Map<String, dynamic>>> _clientRoutines = {};
  final Set<String> _completedRoutineIds = {};
  bool _loadingRoutines = false;

  final List<String> _muscleGroups = [
    'Legs', 'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Abs', 'Cardio', 'Full Body'
  ];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool isLoading = false;

  // Kinetic Theme Colors
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  DateTime _dateOnlyLocal(DateTime date) => DateTime(date.year, date.month, date.day);

  // Store at midday to avoid timezone rollover to previous/next day.
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
      
      if (map['exercises'] != null) {
        exercises = (map['exercises'] as List).map((e) => RoutineExercise.fromMap(e as Map<String, dynamic>)).toList();
      } else {
        // Fallback for old data structure
        exercises = [
          RoutineExercise(
            workoutId: (map['workoutId'] ?? '').toString(),
            workoutName: (map['workoutName'] ?? '').toString(),
            reps: (map['reps'] ?? '').toString(),
            weight: (map['weight'] ?? '').toString(),
          )
        ];
      }

      return RoutineWorkout(
        sets: (map['sets'] ?? '').toString(),
        exercises: exercises,
      );
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
    setState(() {
      availableWorkouts = snapshot.docs;
    });
  }

  Future<void> _fetchClientRoutines() async {
    setState(() => _loadingRoutines = true);

    try {
      // Fetch all routines for this client
      final routinesSnapshot = await FirebaseFirestore.instance
          .collection('routines')
          .where('clientId', isEqualTo: widget.clientId)
          .get();

      // Fetch all completed routine logs for this client
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('routine_logs')
          .where('userId', isEqualTo: widget.clientId)
          .get();

      final completedIds = <String>{};
      for (var logDoc in logsSnapshot.docs) {
        final logData = logDoc.data();
        final routineId = logData['routineId'];
        if (routineId != null) {
          completedIds.add(routineId);
        }
      }

      final Map<DateTime, List<Map<String, dynamic>>> newRoutines = {};

      for (var doc in routinesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final Timestamp timestamp = data['date'];
        final DateTime date = timestamp.toDate();
        final DateTime normalizedDate = _dateOnlyLocal(date);

        if (newRoutines[normalizedDate] == null) {
          newRoutines[normalizedDate] = [];
        }
        newRoutines[normalizedDate]!.add(data);
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
      debugPrint("Error fetching client routines: $e");
      if (!mounted) return;
      setState(() => _loadingRoutines = false);
    }
  }

  void _addWorkoutToRoutine(String workoutId, String workoutName) {
    setState(() {
      selectedWorkouts.add(
        RoutineWorkout(
          exercises: [
            RoutineExercise(
              workoutId: workoutId,
              workoutName: workoutName,
            )
          ],
        ),
      );
    });
  }

  void _addExerciseToSuperset(int index, String workoutId, String workoutName) {
    if (selectedWorkouts[index].exercises.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 exercises per set')),
      );
      return;
    }
    setState(() {
      selectedWorkouts[index].exercises.add(
        RoutineExercise(workoutId: workoutId, workoutName: workoutName),
      );
    });
  }

  Future<void> _saveRoutine() async {
    final user = FirebaseAuth.instance.currentUser;

    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a day')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty || selectedWorkouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill routine name and add workouts')),
      );
      return;
    }

    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final DateTime selectedDate = _dateOnlyLocal(_selectedDay!);
      final DateTime storageDate = _dateForStorage(selectedDate);
      final DateTime dayStart = selectedDate;
      final DateTime dayEnd = selectedDate.add(const Duration(days: 1));

      final List<Map<String, dynamic>> workoutData = selectedWorkouts.map((workout) {
        return workout.toMap();
      }).toList();

      final dataToSave = {
        'name': _nameController.text.trim(),
        'workouts': workoutData,
        'muscleFocus': _selectedMuscles,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      if (widget.initialRoutineId != null) {
        await FirebaseFirestore.instance
            .collection('routines')
            .doc(widget.initialRoutineId)
            .update({
          ...dataToSave,
          'date': Timestamp.fromDate(storageDate),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine updated successfully')),
        );
      } else {
        final existingRoutines = await FirebaseFirestore.instance
            .collection('routines')
            .where('clientId', isEqualTo: widget.clientId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('date', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        if (existingRoutines.docs.isNotEmpty) {
          final String docId = existingRoutines.docs.first.id;
          await FirebaseFirestore.instance.collection('routines').doc(docId).update(dataToSave);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Existing routine updated for this day')),
          );
        } else {
          await FirebaseFirestore.instance.collection('routines').add({
            ...dataToSave,
            'clientId': widget.clientId,
            'createdBy': user.uid,
            'date': Timestamp.fromDate(storageDate),
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Routine saved successfully')),
          );
        }
      }

      setState(() {
        selectedWorkouts.clear();
        _nameController.clear();
        _selectedMuscles.clear();
        isLoading = false;
      });

      _fetchClientRoutines();

    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);

      if (e is FirebaseException && e.code == 'failed-precondition') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firestore index missing for routine date query. Create the index in Firebase Console and try again.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving routine: $e')),
      );
    }
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
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: TextStyle(color: primaryColor),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
    );
  }

  Widget _buildSelectedDayRoutinesList() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final routines = _clientRoutines[_selectedDay!] ?? [];

    if (routines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaceColor.withOpacity(0.2)),
        ),
        child: Text(
          'No routines scheduled for this day',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        final isCompleted = _completedRoutineIds.contains(routine['id']);
        final workouts = routine['workouts'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isCompleted ? Colors.greenAccent.withOpacity(0.1) : surfaceColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted ? Colors.greenAccent.withOpacity(0.3) : surfaceColor.withOpacity(0.2),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      routine['name'] ?? 'Untitled Routine',
                      style: TextStyle(
                        color: isCompleted ? Colors.greenAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                      ),
                      child: const Text(
                        '✓ COMPLETED',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sets/Supersets (${workouts.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...workouts.map((workout) {
                        final exercises = (workout['exercises'] as List?) ?? [workout];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sets: ${workout['sets'] ?? '-'}', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              ...exercises.map((ex) => Padding(
                                padding: const EdgeInsets.only(left: 8.0, top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.fitness_center, color: primaryColor, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ex['workoutName'] ?? 'Unknown',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '${ex['reps'] ?? '-'} reps @ ${ex['weight'] ?? '-'}kg',
                                      style: TextStyle(color: primaryColor, fontSize: 11),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                      if (!isCompleted)
                        const Text(
                          'Status: Pending Completion',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.initialRoutineId == null ? 'CREATE ROUTINE' : 'EDIT ROUTINE',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Routine for ${widget.clientEmail}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Select a date, focus areas, and workouts to build a personalized routine.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 32),
            // Calendar Container
            Container(
              decoration: BoxDecoration(
                color: surfaceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: surfaceColor.withOpacity(0.2)),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  final routines = _clientRoutines[_dateOnlyLocal(day)] ?? [];
                  return routines;
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = _dateOnlyLocal(selectedDay);
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: const TextStyle(color: Colors.white70),
                  outsideDaysVisible: false,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
                  rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    // Check if all routines for this date are completed
                    final allCompleted = (events as List<Map<String, dynamic>>).every(
                      (routine) => _completedRoutineIds.contains(routine['id']),
                    );
                    if (!allCompleted) return null;

                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Display routines for selected day
            if (_selectedDay != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Routines for ${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: primaryColor),
                        onPressed: _fetchClientRoutines,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _loadingRoutines
                      ? Center(child: CircularProgressIndicator(color: primaryColor))
                      : _buildSelectedDayRoutinesList(),
                  const SizedBox(height: 32),
                ],
              ),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'Routine Name',
                hint: 'e.g., Upper Body Power',
                icon: Icons.edit_rounded,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Muscle Focus",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _muscleGroups.map((muscle) {
                final isSelected = _selectedMuscles.contains(muscle);
                return FilterChip(
                  label: Text(muscle),
                  selected: isSelected,
                  selectedColor: primaryColor.withOpacity(0.3),
                  checkmarkColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? primaryColor : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: surfaceColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? primaryColor : surfaceColor.withOpacity(0.2),
                    ),
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedMuscles.add(muscle);
                      } else {
                        _selectedMuscles.remove(muscle);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Available Workouts",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateWorkoutPage()),
                    ).then((_) => loadWorkouts());
                  },
                  icon: Icon(Icons.add, color: primaryColor),
                  label: Text("New", style: TextStyle(color: primaryColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableWorkouts.length,
                itemBuilder: (context, index) {
                  final workout = availableWorkouts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      backgroundColor: surfaceColor.withOpacity(0.1),
                      label: Text(workout['name'], style: const TextStyle(color: Colors.white)),
                      side: BorderSide(color: surfaceColor.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onPressed: () => _addWorkoutToRoutine(workout.id, workout['name']),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Selected Workouts",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedWorkouts.length,
              itemBuilder: (context, index) {
                final item = selectedWorkouts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: surfaceColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSmallField(
                            label: 'Sets',
                            initialValue: item.sets,
                            onChanged: (v) => item.sets = v,
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () => setState(() => selectedWorkouts.removeAt(index)),
                          )
                        ],
                      ),
                      const Divider(height: 32, color: Colors.white10),
                      ...item.exercises.asMap().entries.map((entry) {
                        final exIndex = entry.key;
                        final exercise = entry.value;
                        return Column(
                          children: [
                            if (exIndex > 0) const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("SUPERSET", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    exercise.workoutName.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                  ),
                                ),
                                if (item.exercises.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                    onPressed: () => setState(() => item.exercises.removeAt(exIndex)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildSmallField(
                                  label: 'Reps',
                                  initialValue: exercise.reps,
                                  onChanged: (v) => exercise.reps = v,
                                ),
                                const SizedBox(width: 12),
                                _buildSmallField(
                                  label: 'Weight',
                                  initialValue: exercise.weight,
                                  onChanged: (v) => exercise.weight = v,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                      if (item.exercises.length < 2)
                        TextButton.icon(
                          onPressed: () => _showAddExerciseToSupersetDialog(index),
                          icon: Icon(Icons.add, color: secondaryColor, size: 16),
                          label: Text("ADD SUPERSET EXERCISE", style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: backgroundColor),
                      )
                    : const Text(
                        'SAVE ROUTINE',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseToSupersetDialog(int routineIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Superset Exercise", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: availableWorkouts.length,
                  itemBuilder: (context, index) {
                    final workout = availableWorkouts[index];
                    return ListTile(
                      title: Text(workout['name'], style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        _addExerciseToSuperset(routineIndex, workout.id, workout['name']);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmallField({required String label, required String initialValue, required Function(String) onChanged}) {
    return Expanded(
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          labelStyle: TextStyle(color: primaryColor, fontSize: 12),
        ),
      ),
    );
  }
}
