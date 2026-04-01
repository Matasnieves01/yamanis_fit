import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/features/home/presentation/Client/view_workout_page.dart';
import 'create_workout_page.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('EJERCICIOS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar ejercicios por nombre...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: surfaceColor.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: getWorkouts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar ejercicios', style: TextStyle(color: Colors.white70)));
                }

                final allWorkouts = snapshot.data?.docs ?? [];
                final filteredWorkouts = allWorkouts.where((doc) {
                  final name = (doc.data()['name'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredWorkouts.isEmpty) {
                  return const Center(child: Text('No se encontraron ejercicios', style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredWorkouts.length,
                  itemBuilder: (context, index) {
                    final workoutDoc = filteredWorkouts[index];
                    final workout = workoutDoc.data();
                    final name = (workout['name'] as String?)?.trim() ?? 'Sin nombre';
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
          ),
        ],
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
