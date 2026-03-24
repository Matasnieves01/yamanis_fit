import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'create_workout_page.dart';

class RoutineWorkout {
  final String workoutId;
  final String workoutName;
  String reps;
  String sets;
  String weight;

  RoutineWorkout({
    required this.workoutId,
    required this.workoutName,
    this.reps = '',
    this.sets = '',
    this.weight = '',
  });
}

class CreateRoutinePage extends StatefulWidget {
  final String clientId;
  final String clientEmail;

  const CreateRoutinePage({
    super.key,
    required this.clientId,
    required this.clientEmail,
  });

  @override
  State<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends State<CreateRoutinePage> {
  final TextEditingController _nameController = TextEditingController();

  List<DocumentSnapshot> availableWorkouts = [];
  List<RoutineWorkout> selectedWorkouts = [];
  List<String> _selectedMuscles = [];

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime.utc(now.year, now.month, now.day);
    loadWorkouts();
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

  void _addWorkoutToRoutine(String workoutId, String workoutName) {
    setState(() {
      selectedWorkouts.add(
        RoutineWorkout(
          workoutId: workoutId,
          workoutName: workoutName,
        ),
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
      final DateTime finalDate = _selectedDay!;

      final List<Map<String, dynamic>> workoutData = selectedWorkouts.map((workout) {
        return {
          'workoutId': workout.workoutId,
          'workoutName': workout.workoutName,
          'reps': workout.reps,
          'sets': workout.sets,
          'weight': workout.weight,
        };
      }).toList();

      final dataToSave = {
        'name': _nameController.text.trim(),
        'workouts': workoutData,
        'muscleFocus': _selectedMuscles,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      final existingRoutines = await FirebaseFirestore.instance
          .collection('routines')
          .where('clientId', isEqualTo: widget.clientId)
          .where('date', isEqualTo: Timestamp.fromDate(finalDate))
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
          'date': Timestamp.fromDate(finalDate),
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine saved successfully')),
        );
      }

      setState(() {
        selectedWorkouts.clear();
        _nameController.clear();
        _selectedMuscles.clear();
        isLoading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('CREATE ROUTINE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
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
              ),
            ),
            const SizedBox(height: 32),
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
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: surfaceColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.workoutName.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            onPressed: () => setState(() => selectedWorkouts.removeAt(index)),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildSmallField(
                            label: 'Sets',
                            onChanged: (v) => item.sets = v,
                          ),
                          const SizedBox(width: 12),
                          _buildSmallField(
                            label: 'Reps',
                            onChanged: (v) => item.reps = v,
                          ),
                          const SizedBox(width: 12),
                          _buildSmallField(
                            label: 'Weight',
                            onChanged: (v) => item.weight = v,
                          ),
                        ],
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

  Widget _buildSmallField({required String label, required Function(String) onChanged}) {
    return Expanded(
      child: TextField(
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
