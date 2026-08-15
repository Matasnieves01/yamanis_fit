import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartRoutinePage extends StatefulWidget {
  final Map<String, dynamic> routine;
  final String routineId;

  const StartRoutinePage({
    super.key,
    required this.routine,
    required this.routineId,
  });

  @override
  State<StartRoutinePage> createState() => _StartRoutinePageState();
}

class _StartRoutinePageState extends State<StartRoutinePage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  List<dynamic> workouts = [];
  List<bool> completionStatus = [];
  List<Map<String, dynamic>> resultsList = [];
  Map<String, Map<String, dynamic>> workoutDetailsCache = {};
  bool isLoading = true;
  bool _canStartToday = true;

  DateTime _normalizeDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  /// Get the start of the current week (Monday)
  DateTime _getWeekStart() {
    final now = DateTime.now();
    final today = _normalizeDay(now);
    final daysToMonday = (today.weekday == DateTime.monday)
        ? 0
        : (today.weekday - DateTime.monday);
    return today.subtract(Duration(days: daysToMonday));
  }

  /// Get the end of the current week (Sunday)
  DateTime _getWeekEnd() {
    final now = DateTime.now();
    final today = _normalizeDay(now);
    final daysToSunday = (today.weekday == DateTime.sunday)
        ? 0
        : (DateTime.sunday - today.weekday);
    return today.add(Duration(days: daysToSunday));
  }

  /// Check if a routine is in the current week (Monday-Sunday)
  bool _isRoutineInCurrentWeek() {
    final routineDateTs = widget.routine['date'] as Timestamp?;
    if (routineDateTs == null) return false;
    final routineDay = _normalizeDay(routineDateTs.toDate());
    final weekStart = _getWeekStart();
    final weekEnd = _getWeekEnd();
    return !routineDay.isBefore(weekStart) && !routineDay.isAfter(weekEnd);
  }

  @override
  void initState() {
    super.initState();
    final routineDateTs = widget.routine['date'] as Timestamp?;
    if (routineDateTs != null) {
      final routineDay = _normalizeDay(routineDateTs.toDate());
      final today = _normalizeDay(DateTime.now());
      // Can only start if it's today or earlier AND in the current week
      _canStartToday = !routineDay.isAfter(today) && _isRoutineInCurrentWeek();
    }

    workouts = widget.routine['workouts'] ?? [];
    completionStatus = List.generate(workouts.length, (index) => false);
    resultsList = List.generate(workouts.length, (index) => {});
    _loadAllWorkoutDetails();
  }

  Future<void> _loadAllWorkoutDetails() async {
    for (var workout in workouts) {
      final List exercises = workout['exercises'] ?? [workout];
      for (var ex in exercises) {
        final id = ex['workoutId'];
        if (id != null && !workoutDetailsCache.containsKey(id)) {
          final doc = await FirebaseFirestore.instance
              .collection('workouts')
              .doc(id)
              .get();
          if (doc.exists) {
            workoutDetailsCache[id] = doc.data()!;
          }
        }
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _showWorkoutDetail(int index) {
    final workoutGroup = workouts[index];
    final List exercises = workoutGroup['exercises'] ?? [workoutGroup];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => WorkoutDetailSheet(
        workoutGroup: workoutGroup,
        exercises: exercises,
        detailsCache: workoutDetailsCache,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        routineId: widget.routineId,
        onComplete: (results) {
          setState(() {
            completionStatus[index] = true;
            resultsList[index] = results;
          });
          _checkRoutineCompletion();
        },
      ),
    );
  }

  void _checkRoutineCompletion() {
    if (!_canStartToday) return;
    if (completionStatus.every((status) => status)) {
      _showFinalCommentDialog();
    }
  }

  Future<void> _clearAutosavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saveKey = 'workout_${widget.routineId}_progress';
      await prefs.remove(saveKey);
    } catch (e) {
      debugPrint("Error clearing autosaved progress: $e");
    }
  }

  void _showFinalCommentDialog() {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "¡Rutina Terminada!",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Quieres dejar algún comentario sobre el entrenamiento?",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Escribe aquí (opcional)...",
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                fillColor: Colors.white.withValues(alpha: 0.05),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _finalizeRoutine(commentController.text.trim());
            },
            child: Text(
              "ENVIAR",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeRoutine(String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final clientName =
          "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}"
              .trim();

      final logRef = await FirebaseFirestore.instance
          .collection('routine_logs')
          .add({
            'routineId': widget.routineId,
            'routineName': widget.routine['name'],
            'userId': user.uid,
            'userName': clientName,
            'date': Timestamp.now(),
            'results': resultsList,
            'clientFeedback': comment,
            'completedAt':
                FieldValue.serverTimestamp(), // Add timestamp for grace period
          });

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'routine_completed',
        'title': 'Rutina Completada',
        'message':
            '$clientName ha terminado la rutina: ${widget.routine['name']}${comment.isNotEmpty ? "\nComentario: $comment" : ""}',
        'userId': user.uid,
        'userName': clientName,
        'targetRole': 'admin',
        'logId': logRef.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear autosaved progress after successful completion
      await _clearAutosavedProgress();

      if (!mounted) return;

      setState(() => isLoading = false);
      _showSuccessDialog();
    } catch (e) {
      debugPrint("Error finishing routine: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Error al guardar",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "No pudimos guardar tu progreso. Por favor verifica tu conexión a internet e intenta de nuevo.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                errorMessage.length > 100
                    ? "${errorMessage.substring(0, 100)}..."
                    : errorMessage,
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CERRAR",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalCommentDialog();
            },
            child: Text(
              "REINTENTAR",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("¡Éxito!", style: TextStyle(color: Colors.white)),
        content: Text(
          "Tu progreso ha sido enviado correctamente.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close success dialog
              Navigator.pop(
                context,
                true,
              ); // Go back to dashboard with success indicator
            },
            child: Text(
              "LISTO",
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = completionStatus.where((s) => s).length;
    final progress = workouts.isEmpty ? 0.0 : completedCount / workouts.length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.routine['name']?.toString().toUpperCase() ?? "RUTINA",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: !_canStartToday
          ? _buildNotAvailableView()
          : isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              children: [
                _buildDynamicHeader(progress, completedCount),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    "EJERCICIOS DE HOY",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (int index = 0; index < workouts.length; index++)
                  _buildWorkoutCard(
                    index,
                    completionStatus[index],
                    workouts[index]['exercises'] ?? [workouts[index]],
                    workouts[index],
                  ),
                const SizedBox(height: 20),
                _buildToolkitSection(),
              ],
            ),
    );
  }

  static const List<String> _esWeekdaysFull = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const List<String> _esMonths = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  IconData _muscleIcon() {
    final muscles =
        (widget.routine['muscleFocus'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];
    final m = muscles.isNotEmpty ? muscles.first : '';
    if (m.contains('pierna')) return Icons.directions_walk_rounded;
    if (m.contains('pecho')) return Icons.accessibility_new_rounded;
    if (m.contains('espalda')) return Icons.airline_seat_recline_normal_rounded;
    if (m.contains('hombro')) return Icons.sports_handball_rounded;
    if (m.contains('bícep') || m.contains('trícep') || m.contains('brazo'))
      return Icons.sports_mma_rounded;
    if (m.contains('abdom') || m.contains('core'))
      return Icons.airline_seat_flat_rounded;
    if (m.contains('cardio')) return Icons.directions_run_rounded;
    return Icons.fitness_center_rounded;
  }

  Widget _buildDynamicHeader(double progress, int completed) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Buenos días'
        : now.hour < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    final routineDateTs = widget.routine['date'] as Timestamp?;
    final day = routineDateTs?.toDate() ?? now;
    final dayLabel =
        '${_esWeekdaysFull[day.weekday - 1]} ${day.day} ${_esMonths[day.month - 1]}';
    final total = workouts.length;
    final remaining = total - completed;
    final motivation = progress >= 1.0
        ? '¡Rutina completada! 🔥'
        : completed == 0
        ? '¡A darlo todo hoy! 💪'
        : 'Te falta${remaining == 1 ? '' : 'n'} $remaining ejercicio${remaining == 1 ? '' : 's'} 👊';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.22),
            secondaryColor.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (widget.routine['name'] ?? 'Rutina').toString().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.greenAccent : primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed de $total ejercicios',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(
    int index,
    bool isCompleted,
    List exercises,
    dynamic workoutGroup,
  ) {
    final isSuperset = exercises.length > 1;
    final names = exercises
        .map((e) => (e['workoutName'] ?? 'Ejercicio').toString())
        .join('  +  ');
    final reps = exercises.map((e) => '${e['reps']}').join('/');
    final weight = '${exercises.first['weight'] ?? '-'}';

    return GestureDetector(
      onTap: !isCompleted ? () => _showWorkoutDetail(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCompleted
              ? primaryColor.withValues(alpha: 0.08)
              : const Color(0xFF1A2029),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? primaryColor.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
            width: 1.5,
          ),
          boxShadow: isCompleted
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Miniatura del grupo muscular
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: (isCompleted ? primaryColor : secondaryColor).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _muscleIcon(),
                color: isCompleted
                    ? primaryColor.withValues(alpha: 0.5)
                    : secondaryColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSuperset)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'SUPERSET',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.15,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _miniBadge(
                        Icons.repeat_rounded,
                        '${workoutGroup['sets']} series',
                        primaryColor,
                      ),
                      _miniBadge(
                        Icons.tag_rounded,
                        '$reps reps',
                        secondaryColor,
                      ),
                      _miniBadge(
                        Icons.fitness_center_rounded,
                        '$weight kg',
                        Colors.orangeAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Botón de acción rápido
            _buildActionButton(isCompleted, index),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isCompleted, int index) {
    return GestureDetector(
      onTap: !isCompleted ? () => _showWorkoutDetail(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: isCompleted
              ? LinearGradient(
                  colors: [primaryColor.withValues(alpha: 0.85), primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isCompleted ? null : primaryColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: isCompleted
              ? null
              : Border.all(
                  color: primaryColor.withValues(alpha: 0.4),
                  width: 2,
                ),
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
          color: isCompleted ? backgroundColor : primaryColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildToolkitSection() {
    final notes =
        (widget.routine['notes'] ?? widget.routine['trainerNotes'] ?? '')
            .toString()
            .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "HERRAMIENTAS",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        RestTimerWidget(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        ),
        const SizedBox(height: 12),
        _buildTrainerNotes(notes),
      ],
    );
  }

  Widget _buildTrainerNotes(String notes) {
    final hasNotes = notes.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2029),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: secondaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: secondaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sticky_note_2_rounded,
                  color: secondaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Notas de la entrenadora',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasNotes
                ? notes
                : 'Sin notas para hoy. ¡Concéntrate en tu técnica y respiración! 🎯',
            style: TextStyle(
              color: Colors.white.withValues(alpha: hasNotes ? 0.8 : 0.45),
              fontSize: 13,
              height: 1.5,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotAvailableView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_outlined,
                color: Colors.redAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Próximamente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Esta rutina estará disponible en la fecha programada.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'VOLVER AL INICIO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutDetailSheet extends StatefulWidget {
  final dynamic workoutGroup;
  final List exercises;
  final Map<String, Map<String, dynamic>> detailsCache;
  final Color primaryColor;
  final Color secondaryColor;
  final String routineId;
  final Function(Map<String, dynamic> results) onComplete;

  const WorkoutDetailSheet({
    super.key,
    required this.workoutGroup,
    required this.exercises,
    required this.detailsCache,
    required this.primaryColor,
    required this.secondaryColor,
    required this.routineId,
    required this.onComplete,
  });

  @override
  State<WorkoutDetailSheet> createState() => _WorkoutDetailSheetState();
}

class _WorkoutDetailSheetState extends State<WorkoutDetailSheet> {
  late List<YoutubePlayerController> _ytControllers;
  late List<TextEditingController> _weightControllers;
  late List<TextEditingController> _repsControllers;
  String selectedFeedback = "Good";

  @override
  void initState() {
    super.initState();
    _ytControllers = widget.exercises.map((ex) {
      final details = widget.detailsCache[ex['workoutId']];
      final videoId = YoutubePlayer.convertUrlToId(details?['videoUrl'] ?? "");
      return YoutubePlayerController(
        initialVideoId: videoId ?? "",
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }).toList();

    _weightControllers = widget.exercises.map((ex) {
      return TextEditingController(text: ex['weight']?.toString() ?? "");
    }).toList();

    _repsControllers = widget.exercises.map((ex) {
      return TextEditingController(text: ex['reps']?.toString() ?? "");
    }).toList();

    // Load autosaved progress
    _loadAutosavedProgress();

    // Add listeners to autosave changes
    for (var controller in _weightControllers) {
      controller.addListener(_autosaveProgress);
    }
    for (var controller in _repsControllers) {
      controller.addListener(_autosaveProgress);
    }
  }

  Future<void> _loadAutosavedProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saveKey = 'workout_${widget.routineId}_progress';
      final savedData = prefs.getString(saveKey);

      if (savedData != null) {
        // Parse and restore data
        final parts = savedData.split('|');
        if (parts.length >= 2) {
          final weights = parts[0].split(',');
          final reps = parts[1].split(',');

          for (
            var i = 0;
            i < weights.length && i < _weightControllers.length;
            i++
          ) {
            _weightControllers[i].text = weights[i];
          }
          for (var i = 0; i < reps.length && i < _repsControllers.length; i++) {
            _repsControllers[i].text = reps[i];
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading autosaved progress: $e");
    }
  }

  Future<void> _autosaveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saveKey = 'workout_${widget.routineId}_progress';

      final weights = _weightControllers.map((c) => c.text).join(',');
      final reps = _repsControllers.map((c) => c.text).join(',');
      final data = '$weights|$reps';

      await prefs.setString(saveKey, data);
    } catch (e) {
      debugPrint("Error autosaving progress: $e");
    }
  }

  @override
  void dispose() {
    for (var c in _ytControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    for (var c in _repsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildTrainerFeedbackSection(),
                  ..._buildExerciseDetailsList(),
                  const SizedBox(height: 24),
                  const Text(
                    "¿CÓMO TE SENTISTE?",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _feedbackBtn(
                        "Struggled",
                        Icons.sentiment_very_dissatisfied,
                        Colors.redAccent,
                        "DIFÍCIL",
                      ),
                      _feedbackBtn(
                        "Good",
                        Icons.sentiment_satisfied,
                        widget.primaryColor,
                        "BIEN",
                      ),
                      _feedbackBtn(
                        "Overperformed",
                        Icons.bolt,
                        Colors.orangeAccent,
                        "EXCELENTE",
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final results = {
                          'workoutName': widget.exercises
                              .map((e) => e['workoutName'])
                              .join(' + '),
                          'feedback': selectedFeedback,
                          'exercises': widget.exercises
                              .asMap()
                              .entries
                              .map(
                                (e) => {
                                  'name': e.value['workoutName'],
                                  'plannedWeight': e.value['weight'],
                                  'actualWeight':
                                      _weightControllers[e.key].text,
                                  'plannedReps': e.value['reps'],
                                  'actualReps': _repsControllers[e.key].text,
                                },
                              )
                              .toList(),
                        };
                        Navigator.pop(context);
                        Future.microtask(() => widget.onComplete(results));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "GUARDAR EJERCICIO",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExerciseDetailsList() {
    return widget.exercises.asMap().entries.map((entry) {
      final idx = entry.key;
      final ex = entry.value;
      final details = widget.detailsCache[ex['workoutId']];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (idx > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white10, height: 1),
            ),
          if (idx > 0) const SizedBox(height: 16),
          _buildExerciseCard(idx, ex, details),
        ],
      );
    }).toList();
  }

  Widget _buildExerciseCard(
    int idx,
    dynamic ex,
    Map<String, dynamic>? details,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del ejercicio con nombre y datos principales
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex['workoutName'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSeriesRepsRow(idx, ex),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Video
          if (_ytControllers.isNotEmpty && idx < _ytControllers.length)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: _ytControllers[idx],
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: widget.primaryColor,
                ),
              ),
            )
          else
            Container(
              height: 160,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                color: Colors.white10,
              ),
              child: const Center(
                child: Icon(
                  Icons.videocam_off,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
            ),
          // Descripción y detalles
          if (details?['description'] != null &&
              details!['description'].toString().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "INSTRUCCIONES",
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details['description'],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Peso (discreto)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildWeightInputCompact(
              idx,
              ex['weight']?.toString() ?? "0",
              ex['reps']?.toString() ?? "0",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesRepsRow(int idx, dynamic ex) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, size: 14, color: widget.primaryColor),
              const SizedBox(width: 6),
              Text(
                "${widget.workoutGroup['sets']} SERIES",
                style: TextStyle(
                  color: widget.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.secondaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.secondaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center,
                size: 14,
                color: widget.secondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                "${ex['reps']} REPS",
                style: TextStyle(
                  color: widget.secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightInputCompact(
    int idx,
    String recommendedWeight,
    String recommendedReps,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PESO RECOMENDADO",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$recommendedWeight kg",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "TU PESO",
                      style: TextStyle(
                        color: widget.primaryColor.withValues(alpha: 0.6),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _weightControllers[idx],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "0",
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        suffixText: "kg",
                        suffixStyle: TextStyle(
                          color: widget.primaryColor.withValues(alpha: 0.5),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REPS RECOMENDADAS",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$recommendedReps reps",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.secondaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "TUS REPS",
                      style: TextStyle(
                        color: widget.secondaryColor.withValues(alpha: 0.6),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _repsControllers[idx],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.secondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "0",
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        suffixText: "reps",
                        suffixStyle: TextStyle(
                          color: widget.secondaryColor.withValues(alpha: 0.5),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.exercises.length > 1 ? "SUPERSET" : "SIMPLE",
            style: TextStyle(
              color: widget.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerFeedbackSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('routines')
          .doc(widget.routineId)
          .snapshots(),
      builder: (context, routineSnapshot) {
        String? routineComment;

        // Check for comments in current routine document
        if (routineSnapshot.hasData && routineSnapshot.data != null) {
          final routineData =
              routineSnapshot.data!.data() as Map<String, dynamic>?;
          routineComment = (routineData?['trainerComment'] ?? '')
              .toString()
              .trim();
        }

        // If comment in current routine, show it
        if ((routineComment ?? '').isNotEmpty) {
          return _buildFeedbackCard(routineComment!);
        }

        // Otherwise, show most recent feedback from routine_logs with history
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('routine_logs')
              .where('routineId', isEqualTo: widget.routineId)
              .where('userId', isEqualTo: user.uid)
              .orderBy('date', descending: true)
              .limit(10) // Get last 10 to show history
              .snapshots(),
          builder: (context, logsSnapshot) {
            if (!logsSnapshot.hasData || logsSnapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final allFeedbacks = <String>[];

            // Collect all non-empty trainer feedback from logs
            for (final doc in logsSnapshot.data!.docs) {
              final logData = doc.data() as Map<String, dynamic>;
              final trainerFeedback = (logData['trainerFeedback'] ?? '')
                  .toString()
                  .trim();
              if (trainerFeedback.isNotEmpty &&
                  !allFeedbacks.contains(trainerFeedback)) {
                allFeedbacks.add(trainerFeedback);
              }
            }

            if (allFeedbacks.isEmpty) {
              return const SizedBox.shrink();
            }

            // Show most recent feedback with indicator that there are more
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFeedbackCard(allFeedbacks.first),

                // Show indicator if there are more comments
                if (allFeedbacks.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: () => _showAllFeedbackHistory(allFeedbacks),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ver ${allFeedbacks.length - 1} comentario${allFeedbacks.length > 2 ? 's' : ''} anterior${allFeedbacks.length > 2 ? 'es' : ''}',
                              style: TextStyle(
                                color: Colors.blue.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.blue.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllFeedbackHistory(List<String> feedbacks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Historial de Comentarios",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: feedbacks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comentario ${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feedbacks[index],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CERRAR", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(String feedback) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.message_rounded,
                      color: widget.primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Comentario del Entrenador',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                feedback,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _feedbackBtn(
    String value,
    IconData icon,
    Color color,
    String displayLabel,
  ) {
    bool isSelected = selectedFeedback == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFeedback = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white24, size: 24),
            const SizedBox(height: 6),
            Text(
              displayLabel,
              style: TextStyle(
                color: isSelected ? color : Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cronómetro de descanso integrado con presets y controles play/pausa/reinicio.
class RestTimerWidget extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const RestTimerWidget({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> {
  static const List<int> _presets = [30, 45, 60, 90];
  int _totalSeconds = 60;
  int _remaining = 60;
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      if (_remaining == 0) _remaining = _totalSeconds;
      setState(() => _running = true);
      _tick();
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remaining = _totalSeconds;
      _running = false;
    });
  }

  void _setPreset(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remaining = seconds;
      _running = false;
    });
  }

  String get _formatted {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds == 0 ? 0.0 : _remaining / _totalSeconds;
    final isDone = _remaining == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2029),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timer_rounded,
                  color: widget.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Cronómetro de descanso',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Display con anillo de progreso
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? Colors.greenAccent : widget.primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      isDone ? '¡Listo!' : _formatted,
                      style: TextStyle(
                        color: isDone ? Colors.greenAccent : Colors.white,
                        fontSize: isDone ? 14 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Controles
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: widget.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _running
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: const Color(0xFF11151C),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _running ? 'PAUSA' : 'INICIAR',
                                    style: const TextStyle(
                                      color: Color(0xFF11151C),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _reset,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.refresh_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _presets.map((s) {
                        final isSelected = _totalSeconds == s;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              onTap: () => _setPreset(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.secondaryColor.withValues(
                                          alpha: 0.25,
                                        )
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.secondaryColor
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  '${s}s',
                                  style: TextStyle(
                                    color: isSelected
                                        ? widget.secondaryColor
                                        : Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
