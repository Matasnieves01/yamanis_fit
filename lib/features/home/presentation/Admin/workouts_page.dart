import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/constants/muscle_constants.dart';
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
  String _selectedCategory = "Todos"; // "Todos", "Piernas", "Brazos", etc.
  String? _selectedSpecificMuscle; // Sub-filtro específico

  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161F2C);
  final Color surfaceColor = const Color(0xFF1E2838);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  final Map<String, IconData> _categoryIcons = {
    'Todos': Icons.grid_view_rounded,
    'Piernas': Icons.directions_run_rounded,
    'Brazos': Icons.fitness_center_rounded,
    'Pecho': Icons.shield_outlined,
    'Espalda': Icons.accessibility_new_rounded,
    'Hombros': Icons.accessibility_rounded,
    'Abdomen': Icons.crop_portrait_rounded,
  };

  Stream<QuerySnapshot<Map<String, dynamic>>> getWorkouts() {
    return FirebaseFirestore.instance
        .collection('workouts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    return videoId != null ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg' : null;
  }

  Future<void> _deleteWorkout(String workoutId, String workoutName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'ELIMINAR EJERCICIO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "$workoutName"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('workouts').doc(workoutId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ejercicio eliminado correctamente'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  List<String> _getGeneralMusclesFromDoc(Map<String, dynamic> data) {
    if (data['generalMuscles'] is List) {
      return (data['generalMuscles'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (data['muscleFocus'] is List) {
      return (data['muscleFocus'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  List<String> _getSpecificMusclesFromDoc(Map<String, dynamic> data) {
    if (data['specificMuscles'] is List) {
      return (data['specificMuscles'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'EJERCICIOS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
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
            return Center(
              child: Text(
                'Error al cargar ejercicios: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final allWorkouts = snapshot.data?.docs ?? [];

          // Contar ejercicios por categoría de músculo general
          final Map<String, int> categoryCounts = {
            'Todos': allWorkouts.length,
          };
          for (final m in MuscleConstants.generalMuscles) {
            categoryCounts[m] = 0;
          }

          for (final doc in allWorkouts) {
            final data = doc.data();
            final general = _getGeneralMusclesFromDoc(data);
            final specific = _getSpecificMusclesFromDoc(data);

            for (final m in MuscleConstants.generalMuscles) {
              final matchesGeneral = general.any((g) => g.toLowerCase() == m.toLowerCase());
              // También contar si algún músculo específico pertenece a esta categoría
              final matchesSpecific = specific.any((s) {
                final parent = MuscleConstants.getGeneralForSpecific(s);
                return parent != null && parent.toLowerCase() == m.toLowerCase();
              });

              if (matchesGeneral || matchesSpecific) {
                categoryCounts[m] = (categoryCounts[m] ?? 0) + 1;
              }
            }
          }

          // Filtrar lista según búsqueda, categoría general y músculo específico
          final filteredWorkouts = allWorkouts.where((doc) {
            final data = doc.data();
            final name = (data['name'] as String? ?? '').toLowerCase();
            final description = (data['description'] as String? ?? '').toLowerCase();
            final general = _getGeneralMusclesFromDoc(data);
            final specific = _getSpecificMusclesFromDoc(data);

            // 1. Filtro de búsqueda textual
            if (_searchQuery.isNotEmpty) {
              final matchesText = name.contains(_searchQuery) ||
                  description.contains(_searchQuery) ||
                  general.any((m) => m.toLowerCase().contains(_searchQuery)) ||
                  specific.any((m) => m.toLowerCase().contains(_searchQuery));
              if (!matchesText) return false;
            }

            // 2. Filtro de Categoría General
            if (_selectedCategory != "Todos") {
              final matchesGeneral = general.any((g) => g.toLowerCase() == _selectedCategory.toLowerCase());
              final matchesSpecificParent = specific.any((s) {
                final parent = MuscleConstants.getGeneralForSpecific(s);
                return parent != null && parent.toLowerCase() == _selectedCategory.toLowerCase();
              });

              if (!matchesGeneral && !matchesSpecificParent) return false;
            }

            // 3. Sub-filtro de Músculo Específico
            if (_selectedSpecificMuscle != null && _selectedSpecificMuscle!.isNotEmpty) {
              final matchesSpecific = specific.any((s) => s.toLowerCase() == _selectedSpecificMuscle!.toLowerCase());
              if (!matchesSpecific) return false;
            }

            return true;
          }).toList();

          final availableSpecificMuscles = _selectedCategory != "Todos"
              ? (MuscleConstants.musclesByCategory[_selectedCategory] ?? [])
              : <String>[];

          return Column(
            children: [
              // 1. BUSCADOR INTEGRADO
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Buscar por ejercicio, músculo o técnica...",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              // 2. CATEGORÍAS PRINCIPALES DE MÚSCULOS
              _buildCategorySelector(categoryCounts),

              // 3. SUB-FILTRO DE MÚSCULOS ESPECÍFICOS (SI HAY CATEGORÍA SELECCIONADA)
              if (availableSpecificMuscles.isNotEmpty)
                _buildSpecificMuscleSelector(availableSpecificMuscles),

              // 4. STRIP INFORMATIVO CON CONTADOR
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mostrando ${filteredWorkouts.length} de ${allWorkouts.length} ejercicios",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_selectedCategory != "Todos" || _selectedSpecificMuscle != null || _searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = "Todos";
                            _selectedSpecificMuscle = null;
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                        child: Text(
                          "Restablecer",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 5. LISTA DE TARJETAS DE EJERCICIOS
              Expanded(
                child: filteredWorkouts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filteredWorkouts.length,
                        itemBuilder: (context, index) {
                          final doc = filteredWorkouts[index];
                          final workout = doc.data();
                          final name = (workout['name'] as String?)?.trim() ?? 'Sin nombre';
                          final videoUrl = workout['videoUrl'] as String?;
                          final thumbnailUrl = getThumbnail(videoUrl);
                          final general = _getGeneralMusclesFromDoc(workout);
                          final specific = _getSpecificMusclesFromDoc(workout);

                          return _buildWorkoutCard(
                            workoutId: doc.id,
                            workout: workout,
                            name: name,
                            thumbnailUrl: thumbnailUrl,
                            generalMuscles: general,
                            specificMuscles: specific,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workouts_fab',
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        icon: const Icon(Icons.add_rounded, weight: 900),
        label: const Text(
          "NUEVO EJERCICIO",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateWorkoutPage(
                initialData: _selectedCategory != "Todos"
                    ? {'generalMuscles': [_selectedCategory]}
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildCategorySelector(Map<String, int> counts) {
    final categories = ["Todos", ...MuscleConstants.generalMuscles];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final count = counts[cat] ?? 0;
          final icon = _categoryIcons[cat] ?? Icons.fitness_center_rounded;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _selectedSpecificMuscle = null; // Resetear subfiltro
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? backgroundColor : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? backgroundColor : Colors.white,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? backgroundColor.withValues(alpha: 0.2)
                              : surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$count",
                          style: TextStyle(
                            color: isSelected ? backgroundColor : primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpecificMuscleSelector(List<String> specificMuscles) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Chip "Todos en esta categoría"
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text("Todos ${_selectedCategory.toLowerCase()}"),
                selected: _selectedSpecificMuscle == null,
                onSelected: (_) => setState(() => _selectedSpecificMuscle = null),
                selectedColor: secondaryColor,
                backgroundColor: surfaceColor.withValues(alpha: 0.4),
                labelStyle: TextStyle(
                  color: _selectedSpecificMuscle == null ? backgroundColor : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                showCheckmark: false,
              ),
            ),
            ...specificMuscles.map((muscle) {
              final isSelected = _selectedSpecificMuscle == muscle;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(muscle),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedSpecificMuscle = isSelected ? null : muscle;
                    });
                  },
                  selectedColor: secondaryColor,
                  backgroundColor: cardColor,
                  labelStyle: TextStyle(
                    color: isSelected ? backgroundColor : Colors.white70,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? secondaryColor : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  showCheckmark: false,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard({
    required String workoutId,
    required Map<String, dynamic> workout,
    required String name,
    required String? thumbnailUrl,
    required List<String> generalMuscles,
    required List<String> specificMuscles,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewWorkoutPage(workoutId: workoutId, isAdmin: true),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ZONA DE BANNER / MINIATURA CON ACCIONES RÁPIDAS
                Stack(
                  children: [
                    // Imagen de miniatura o placeholder estilizado
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        image: thumbnailUrl != null
                            ? DecorationImage(
                                image: NetworkImage(thumbnailUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: thumbnailUrl == null
                          ? Center(
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: Colors.white.withValues(alpha: 0.15),
                                size: 50,
                              ),
                            )
                          : null,
                    ),

                    // Gradiente oscuro superior e inferior para legibilidad
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Botón play central si hay video
                    if (thumbnailUrl != null)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryColor.withValues(alpha: 0.6), width: 1.5),
                            ),
                            child: Icon(Icons.play_arrow_rounded, color: primaryColor, size: 28),
                          ),
                        ),
                      ),

                    // Badges y acciones en la barra superior del banner
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge de Categoría Principal
                          if (generalMuscles.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                generalMuscles.first.toUpperCase(),
                                style: TextStyle(
                                  color: backgroundColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          // Botones de Editar y Eliminar
                          Row(
                            children: [
                              Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateWorkoutPage(
                                          workoutId: workoutId,
                                          initialData: workout,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.edit_outlined, color: primaryColor, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _deleteWorkout(workoutId, name),
                                  child: const Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2. DETALLES DEL EJERCICIO
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del ejercicio
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // Etiquetas de Músculos Específicos
                      () {
                        final allTags = <String>[...generalMuscles, ...specificMuscles].toSet().toList();
                        if (allTags.isEmpty) return const SizedBox.shrink();

                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: allTags.take(4).map((tag) {
                            final isGeneral = generalMuscles.contains(tag);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isGeneral
                                    ? primaryColor.withValues(alpha: 0.12)
                                    : surfaceColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isGeneral
                                      ? primaryColor.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: isGeneral ? primaryColor : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList()
                            ..addAll(
                              allTags.length > 4
                                  ? [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '+${allTags.length - 4}',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : [],
                            ),
                        );
                      }(),

                      const SizedBox(height: 12),

                      // Pie de tarjeta con indicación táctil
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.touch_app_outlined, color: Colors.white.withValues(alpha: 0.4), size: 14),
                              const SizedBox(width: 5),
                              Text(
                                "Toca para ver técnica y video",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 13),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center_rounded, color: primaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              "No se encontraron ejercicios",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No hay ejercicios que coincidan con "$_searchQuery".'
                  : 'No hay ejercicios registrados en la categoría ${_selectedCategory.toUpperCase()}.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty || _selectedCategory != "Todos" || _selectedSpecificMuscle != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = "";
                    _searchController.clear();
                    _selectedCategory = "Todos";
                    _selectedSpecificMuscle = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Ver Todos los Ejercicios"),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
          ],
        ),
      ),
    );
  }
}
