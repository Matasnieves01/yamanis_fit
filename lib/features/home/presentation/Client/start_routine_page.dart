import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  DateTime _normalizeDay(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    final routineDateTs = widget.routine['date'] as Timestamp?;
    if (routineDateTs != null) {
      final routineDay = _normalizeDay(routineDateTs.toDate());
      final today = _normalizeDay(DateTime.now());
      _canStartToday = !routineDay.isAfter(today);
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
          final doc = await FirebaseFirestore.instance.collection('workouts').doc(id).get();
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

  void _showFinalCommentDialog() {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("¡Rutina Terminada!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("¿Quieres dejar algún comentario sobre el entrenamiento?", 
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Escribe aquí (opcional)...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                fillColor: Colors.white.withOpacity(0.05),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
            child: Text("ENVIAR", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _finalizeRoutine(String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final clientName = "${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}".trim();

      final logRef = await FirebaseFirestore.instance.collection('routine_logs').add({
        'routineId': widget.routineId,
        'routineName': widget.routine['name'],
        'userId': user.uid,
        'userName': clientName,
        'date': Timestamp.now(),
        'results': resultsList,
        'clientFeedback': comment, // Changed from clientComment to clientFeedback to match Admin view
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'routine_completed',
        'title': 'Rutina Completada',
        'message': '$clientName ha terminado la rutina: ${widget.routine['name']}${comment.isNotEmpty ? "\nComentario: $comment" : ""}',
        'userId': user.uid,
        'userName': clientName,
        'targetRole': 'admin',
        'logId': logRef.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      setState(() => isLoading = false);
      _showSuccessDialog();
    } catch (e) {
      debugPrint("Error finishing routine: $e");
      if(!mounted) return;
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
        title: const Text("Error al guardar", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "No pudimos guardar tu progreso. Por favor verifica tu conexión a internet e intenta de nuevo.",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Text(
                errorMessage.length > 100 ? "${errorMessage.substring(0, 100)}..." : errorMessage,
                style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CERRAR", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalCommentDialog();
            },
            child: Text("REINTENTAR", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          )
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
        content: Text("Tu progreso ha sido enviado correctamente.", 
          style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close success dialog
              Navigator.pop(context, true); // Go back to dashboard with success indicator
            },
            child: Text("LISTO", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.routine['name']?.toString().toUpperCase() ?? "RUTINA"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_canStartToday
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy, color: Colors.redAccent, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Esta rutina no está disponible todavía',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('VOLVER'),
                    ),
                  ],
                ),
              ),
            )
          : isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "LISTA DE EJERCICIOS",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Puedes completar los ejercicios en cualquier orden.",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: workouts.length,
                      itemBuilder: (context, index) {
                        final isCompleted = completionStatus[index];
                        final workoutGroup = workouts[index];
                        final List exercises = workoutGroup['exercises'] ?? [workoutGroup];

                        return GestureDetector(
                          onTap: !isCompleted ? () => _showWorkoutDetail(index) : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isCompleted 
                                ? primaryColor.withOpacity(0.1) 
                                : surfaceColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isCompleted 
                                  ? primaryColor.withOpacity(0.3) 
                                  : primaryColor.withOpacity(0.1)
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isCompleted ? primaryColor : Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check : Icons.play_arrow,
                                    color: isCompleted ? backgroundColor : primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ...exercises.map((ex) => Text(
                                        ex['workoutName']?.toString().toUpperCase() ?? "DESCONOCIDO",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      )),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${workoutGroup['sets']} Series | ${exercises.map((e) => "${e['reps']}r").join(' + ')} | ${exercises.map((e) => "${e['weight']}kg").join(' + ')}",
                                        style: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCompleted) Icon(Icons.check_circle, color: primaryColor),
                              ],
                            ),
                          ),
                        );
                      },
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
  final Function(Map<String, dynamic> results) onComplete;

  const WorkoutDetailSheet({
    super.key,
    required this.workoutGroup,
    required this.exercises,
    required this.detailsCache,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onComplete,
  });

  @override
  State<WorkoutDetailSheet> createState() => _WorkoutDetailSheetState();
}

class _WorkoutDetailSheetState extends State<WorkoutDetailSheet> {
  late List<YoutubePlayerController> _ytControllers;
  late List<TextEditingController> _weightControllers;
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
  }

  @override
  void dispose() {
    for (var c in _ytControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.exercises.length > 1 ? "SUPERSET" : "EJERCICIO",
                  style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...widget.exercises.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ex = entry.value;
                  final details = widget.detailsCache[ex['workoutId']];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (idx > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10)),
                      Text(ex['workoutName'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: YoutubePlayer(controller: _ytControllers[idx], showVideoProgressIndicator: true),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard("SERIES", widget.workoutGroup['sets']),
                          const SizedBox(width: 12),
                          _buildStatCard("REPS", ex['reps']),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: widget.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.primaryColor.withOpacity(0.2))),
                              child: Column(
                                children: [
                                  const Text("PESO REAL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                  TextField(
                                    controller: _weightControllers[idx],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, suffixText: "kg", suffixStyle: TextStyle(color: Colors.white38, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text("INSTRUCCIONES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(details?['description'] ?? "Sin instrucciones.", style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5, fontSize: 13)),
                    ],
                  );
                }),
                const SizedBox(height: 32),
                const Text("¿CÓMO TE SENTISTE?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _feedbackBtn("Struggled", Icons.sentiment_very_dissatisfied, Colors.redAccent, "Difícil"),
                    _feedbackBtn("Good", Icons.sentiment_satisfied, widget.primaryColor, "Bien"),
                    _feedbackBtn("Overperformed", Icons.bolt, Colors.orangeAccent, "Excelente"),
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      final results = {
                        'workoutName': widget.exercises.map((e) => e['workoutName']).join(' + '),
                        'feedback': selectedFeedback,
                        'exercises': widget.exercises.asMap().entries.map((e) => {
                          'name': e.value['workoutName'],
                          'plannedWeight': e.value['weight'],
                          'actualWeight': _weightControllers[e.key].text,
                          'reps': e.value['reps'],
                        }).toList(),
                      };
                      Navigator.pop(context);
                      Future.microtask(() => widget.onComplete(results));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("COMPLETAR EJERCICIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(value.toString() ?? "-", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _feedbackBtn(String value, IconData icon, Color color, String displayLabel) {
    bool isSelected = selectedFeedback == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFeedback = value),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: isSelected ? color : Colors.transparent)),
            child: Icon(icon, color: isSelected ? color : Colors.white30),
          ),
          const SizedBox(height: 8),
          Text(displayLabel, style: TextStyle(color: isSelected ? color : Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
