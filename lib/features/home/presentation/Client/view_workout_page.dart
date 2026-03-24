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
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    loadWorkout();
  }

  Future<void> loadWorkout() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .get();

      if (doc.exists) {
        workoutData = doc.data();
        final String videoUrl = workoutData?['videoUrl'] ?? "";
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);

        _controller = YoutubePlayerController(
          initialVideoId: videoId ?? "",
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error loading workout: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (workoutData == null || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Workout")),
        body: const Center(child: Text("Workout not found")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF11151C),
      appBar: AppBar(
        title: Text(workoutData?['name'] ?? "Workout"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YoutubePlayer(
              controller: _controller!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFFAEE084),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DESCRIPTION",
                    style: TextStyle(
                      color: Color(0xFFAEE084),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    workoutData?['description'] ?? "No description available.",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
