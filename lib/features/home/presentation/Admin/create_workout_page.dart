import 'package:flutter/material.dart';

class CreateWorkoutPage extends StatelessWidget{
  const CreateWorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Create Workout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}