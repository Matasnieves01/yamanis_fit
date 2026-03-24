import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/home/presentation/Client/view_workout_page.dart';
import 'create_workout_page.dart';

class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key});

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  Stream<QuerySnapshot<Map<String, dynamic>>> getWorkouts() {
    return FirebaseFirestore.instance
        .collection('workouts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String? getThumbnail(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    String? videoId;
    if (uri.host.contains('youtube.com')) {
      videoId = uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }

    return videoId != null ? 'https://img.youtube.com/vi/$videoId/0.jpg' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('WORKOUTS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getWorkouts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load workouts', style: TextStyle(color: Colors.white70)));
          }

          final workouts = snapshot.data?.docs ?? [];

          if (workouts.isEmpty) {
            return const Center(child: Text('No workouts found', style: TextStyle(color: Colors.white70)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workoutDoc = workouts[index];
              final workout = workoutDoc.data();
              final name = (workout['name'] as String?)?.trim() ?? 'No name';
              final videoUrl = workout['videoUrl'] as String?;
              final thumbnailUrl = getThumbnail(videoUrl);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewWorkoutPage(workoutId: workoutDoc.id),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfaceColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(32),
                    image: thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(thumbnailUrl),
                            fit: BoxFit.cover,
                            opacity: 0.4,
                          )
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, backgroundColor.withOpacity(0.9)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 60),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  "EJERCICIO",
                                  style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Toca para ver video",
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              Icon(Icons.play_circle_fill, color: primaryColor, size: 32),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateWorkoutPage()),
          );
        },
        child: const Icon(Icons.add, weight: 900),
      ),
    );
  }
}
