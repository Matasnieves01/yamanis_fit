import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';

class CreateWorkoutPage extends StatefulWidget {
  final String? workoutId;
  final Map<String, dynamic>? initialData;

  const CreateWorkoutPage({super.key, this.workoutId, this.initialData});

  @override
  State<CreateWorkoutPage> createState() => _CreateWorkoutPageState();
}

class _CreateWorkoutPageState extends State<CreateWorkoutPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  YoutubePlayerController? _youtubeController;

  bool isLoading = false;
  bool isEditing = false;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    isEditing = widget.workoutId != null;
    if (isEditing && widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      _descController.text = widget.initialData!['description'] ?? '';
      _videoUrlController.text = widget.initialData!['videoUrl'] ?? '';
      _onUrlChanged();
    }
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
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'videoUrl': _videoUrlController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEditing) {
        await FirebaseFirestore.instance.collection('workouts').doc(widget.workoutId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('workouts').add(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Ejercicio actualizado!' : 'Ejercicio guardado!')),
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
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: TextStyle(color: primaryColor),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'EDITAR EJERCICIO' : 'CREAR EJERCICIO', 
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? "Editar Detalles" : "Detalles del Ejercicio",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'Nombre del Ejercicio',
                hint: 'ej., Sentadilla con Barra',
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'Descripción',
                hint: 'Explica la técnica...',
                icon: Icons.description_rounded,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _videoUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                label: 'URL de Video YouTube',
                hint: 'Pega el enlace aquí',
                icon: Icons.play_circle_fill_rounded,
              ),
            ),
            const SizedBox(height: 24),
            if (_youtubeController != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: primaryColor,
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: backgroundColor)
                    : Text(
                        isEditing ? 'ACTUALIZAR' : 'GUARDAR',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
