import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CreateWorkoutPage extends StatefulWidget {
  const CreateWorkoutPage({super.key});

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  YoutubePlayerController? _youtubeController;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _videoUrlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    final url = _videoUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _youtubeController?.dispose();
        _youtubeController = null;
      });
      return;
    }

    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      if (_youtubeController != null && _youtubeController!.initialVideoId == videoId) {
        return;
      }
      setState(() {
        _youtubeController?.dispose();
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
          ),
        );
      });
    } else {
      setState(() {
        _youtubeController?.dispose();
        _youtubeController = null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _videoUrlController.removeListener(_onUrlChanged);
    _videoUrlController.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> saveWorkout() async {
    if (_nameController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty ||
        _videoUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('workouts').add({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'videoUrl': _videoUrlController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout saved successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
      prefixIcon: Icon(icon, color: Colors.blueAccent),
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
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.blueAccent),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Workout'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "New Workout Details",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Fill in the information below to add a new workout to your collection.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: _buildInputDecoration(
                label: 'Workout Name',
                hint: 'e.g., Morning Yoga',
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: _buildInputDecoration(
                label: 'Description',
                hint: 'Describe the exercises and sets...',
                icon: Icons.description_rounded,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _videoUrlController,
              decoration: _buildInputDecoration(
                label: 'YouTube Video URL',
                hint: 'https://youtube.com/watch?v=...',
                icon: Icons.play_circle_fill_rounded,
              ),
            ),
            const SizedBox(height: 20),
            if (_youtubeController != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.blueAccent,
                ),
              )
            else
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_rounded, 
                      color: Colors.white.withOpacity(0.2), size: 48),
                    const SizedBox(height: 8),
                    Text("Video preview will appear here",
                      style: TextStyle(color: Colors.white.withOpacity(0.3))),
                  ],
                ),
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: Colors.blueAccent.withOpacity(0.4),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SAVE WORKOUT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
