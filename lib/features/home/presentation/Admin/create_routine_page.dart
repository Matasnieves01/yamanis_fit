import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

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
  final TextEditingController _newWorkoutController = TextEditingController();

  List<DocumentSnapshot> workouts = [];
  List<DocumentSnapshot> selectedWorkouts = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isCreatingWorkout = false;

  @override
  void initState() {
    super.initState();
    loadWorkouts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newWorkoutController.dispose();
    super.dispose();
  }

  Future<void> loadWorkouts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('workouts').get();

    if (!mounted) {
      return;
    }

    setState(() {
      workouts = snapshot.docs;
    });
  }

  void toggleWorkout(DocumentSnapshot workout) {
    setState(() {
      if (selectedWorkouts.contains(workout)) {
        selectedWorkouts.remove(workout);
      } else {
        selectedWorkouts.add(workout);
      }
    });
  }

  Future<void> saveRoutine() async {
    final user = FirebaseAuth.instance.currentUser;

    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a day')),
      );
      return;
    }

    if (_nameController.text.isEmpty || selectedWorkouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields')),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in')),
      );
      return;
    }

    final routineRef =
        await FirebaseFirestore.instance.collection('routines').add({
      'name': _nameController.text,
      'clientId': widget.clientId,
      'createdBy': user.uid,
      'date': Timestamp.fromDate(_selectedDay!),
    });

    for (final workout in selectedWorkouts) {
      await routineRef.collection('exercises').add({
        'workoutId': workout.id,
        'name': workout['name'],
        'sets': 3,
        'reps': 10,
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      selectedWorkouts.clear();
      _nameController.clear();
      _selectedDay = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Routine saved')),
    );
  }

  Future<void> _createWorkout() async {
    final name = _newWorkoutController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout name is required')),
      );
      return;
    }

    setState(() {
      _isCreatingWorkout = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final docRef = await FirebaseFirestore.instance.collection('workouts').add({
        'name': name,
        'createdBy': user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final createdWorkout = await docRef.get();

      if (!mounted) {
        return;
      }

      setState(() {
        workouts.insert(0, createdWorkout);
        if (!selectedWorkouts.any((w) => w.id == createdWorkout.id)) {
          selectedWorkouts.add(createdWorkout);
        }
      });

      _newWorkoutController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout created and selected')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create workout')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingWorkout = false;
        });
      }
    }
  }

  void _showCreateWorkoutDialog() {
    _newWorkoutController.clear();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Workout'),
          content: TextField(
            controller: _newWorkoutController,
            decoration: const InputDecoration(labelText: 'Workout name'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isCreatingWorkout ? null : _createWorkout(),
          ),
          actions: [
            TextButton(
              onPressed: _isCreatingWorkout ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isCreatingWorkout ? null : _createWorkout,
              child: _isCreatingWorkout
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Routine for ${widget.clientEmail}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Routine Name'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Workouts',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showCreateWorkoutDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New workout'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  final isSelected = selectedWorkouts.contains(workout);

                  return ListTile(
                    title: Text(workout['name']),
                    trailing: Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                    ),
                    onTap: () => toggleWorkout(workout),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: saveRoutine,
              child: const Text('Save Routine'),
            ),
          ],
        ),
      ),
    );
  }
}