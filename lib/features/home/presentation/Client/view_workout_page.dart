import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ViewWorkoutPage extends StatefulWidget {
  final String workoutId;

  const ViewWorkoutPage({
    super.key,
    required this.workoutId,
  });

  @override
  State<ViewWorkoutPage> createState() => _ViewWorkoutPageState();
}

class _ViewWorkoutPageState extends State<ViewWorkoutPage> {
  Map<String, dynamic>? workoutData;
  bool isLoading = true;
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    loadWorkout();
  }

  Future<void> loadWorkout() async {
    final doc = await FirebaseFirestore.instance
        .collection('workouts')
        .doc(widget.workoutId)
        .get();

    if (doc.exists) {
      workoutData = doc.data();

      final videoId = YoutubePlayer.convertUrlToId(
          workoutData!['videoUrl']
      );
      _controller = YoutubePlayerController(
        initialVideoId: videoId ?? "",
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
        ),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (workoutData == null) {
      return const Scaffold(
        body: Center(child: Text("Workout not found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(workoutData!['name']),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
            ),

            const SizedBox(height: 20),

            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    workoutData!['description'],
                    style: const TextStyle(fontSize: 16),
                ),
            ),
          ],
        ),
      ),
    );
  }
}