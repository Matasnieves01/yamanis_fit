import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/home/presentation/Client/view_workout_page.dart';

import 'create_workout_page.dart';

class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> getWorkouts() {
    return FirebaseFirestore.instance
        .collection('workouts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getWorkouts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load workouts'));
          }

          final workouts = snapshot.data?.docs ?? [];

          if (workouts.isEmpty) {
            return const Center(child: Text('No workouts found'));
          }

          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workoutDoc = workouts[index];
              final workout = workoutDoc.data();

              final name = (workout['name'] as String?)?.trim();
              final description = (workout['description'] as String?)?.trim();

              return ListTile(
                title: Text(name == null || name.isEmpty ? 'No name' : name),
                subtitle: Text(
                  description == null || description.isEmpty
                      ? 'No description'
                      : description,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewWorkoutPage(workoutId: workoutDoc.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateWorkoutPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}