import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget buildCard(String tittle, IconData icon){
    return Card(
      elevation: 4,
      child: SizedBox(
        width: double.infinity,
        height: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 20),
            Text(
              tittle,
              style: const TextStyle(fontSize: 18),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fitness Trainer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            buildCard('My Workouts', Icons.fitness_center),
            const SizedBox(height: 16,),
            buildCard('My Clients', Icons.people),
            const SizedBox(height: 16,),
            buildCard('Exercise video', Icons.video_library),
          ]
        )
      ),
    );
  }
}