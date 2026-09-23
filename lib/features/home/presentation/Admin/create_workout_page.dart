import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/core/constants/muscle_constants.dart';

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

  List<String> _selectedGeneralMuscles = [];
  List<String> _selectedSpecificMuscles = [];

  bool isLoading = false;
  bool isEditing = false;

  final Color backgroundColor = const Color(0xFF11152C);
  final Color surfaceColor = const Color(0xFF55769C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    isEditing = widget.workoutId != null;
    if (isEditing) {
      if (widget.initialData != null) {
        _populateFields(widget.initialData!);
      } else {
        _fetchInitialData();
      }
    }
    _videoUrlController.addListener(_onUrlChanged);
  }

  void _populateFields(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _descController.text = data['description'] ?? '';
    _videoUrlController.text = data['videoUrl'] ?? '';
    if (data['generalMuscles'] is List) {
      _selectedGeneralMuscles = List<String>.from(data['generalMuscles']);
    } else if (data['muscleFocus'] is List) {
      _selectedGeneralMuscles = List<String>.from(data['muscleFocus']);
    }
    if (data['specificMuscles'] is List) {
      _selectedSpecificMuscles = List<String>.from(data['specificMuscles']);
    }
    _onUrlChanged();
  }

  Future<void> _fetchInitialData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('workouts').doc(widget.workoutId).get();
      if (doc.exists && mounted) {
        setState(() {
          _populateFields(doc.data()!);
        });
      }
    } catch (e) {
      debugPrint('Error loading workout: $e');
    }
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
        const SnackBar(content: Text('Por favor, completa todos los campos principales')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'videoUrl': _videoUrlController.text.trim(),
        'generalMuscles': _selectedGeneralMuscles,
        'specificMuscles': _selectedSpecificMuscles,
        'muscleFocus': _selectedGeneralMuscles,
        'muscles': {..._selectedGeneralMuscles, ..._selectedSpecificMuscles}.toList(),
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

      Navigator.pop(context, true);
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

  Widget _buildMuscleSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fitness_center_rounded, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              "MÚSCULOS GENERALES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Selecciona los grupos musculares principales trabajados",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MuscleConstants.generalMuscles.map((general) {
            final isSelected = _selectedGeneralMuscles.contains(general);
            return FilterChip(
              label: Text(general),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedGeneralMuscles.add(general);
                  } else {
                    _selectedGeneralMuscles.remove(general);
                  }
                });
              },
              backgroundColor: surfaceColor.withValues(alpha: 0.15),
              selectedColor: primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? backgroundColor : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.1),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Icon(Icons.scatter_plot_rounded, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              "MÚSCULOS ESPECÍFICOS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Etiqueta con precisión la musculatura que se activa",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        const SizedBox(height: 14),
        ...MuscleConstants.musclesByCategory.entries.map((entry) {
          final category = entry.key;
          final muscles = entry.value;
          final isParentSelected = _selectedGeneralMuscles.contains(category);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isParentSelected
                      ? primaryColor.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: isParentSelected ? primaryColor : Colors.white60,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isParentSelected)
                        Icon(Icons.check_circle_rounded, color: primaryColor, size: 13),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: muscles.map((muscle) {
                      final isSelected = _selectedSpecificMuscles.contains(muscle);
                      return FilterChip(
                        label: Text(muscle),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSpecificMuscles.add(muscle);
                              // Auto-seleccionar el grupo general si no está activo
                              final general = MuscleConstants.getGeneralForSpecific(muscle);
                              if (general != null && !_selectedGeneralMuscles.contains(general)) {
                                _selectedGeneralMuscles.add(general);
                              }
                            } else {
                              _selectedSpecificMuscles.remove(muscle);
                            }
                          });
                        },
                        backgroundColor: surfaceColor.withValues(alpha: 0.1),
                        selectedColor: primaryColor.withValues(alpha: 0.85),
                        labelStyle: TextStyle(
                          color: isSelected ? backgroundColor : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            if (_youtubeController != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildMuscleSelectionSection(),
            const SizedBox(height: 28),
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
