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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Escribe aquí (opcional)...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                fillColor: Colors.white.withValues(alpha: 0.05),
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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                errorMessage.length > 100 ? "${errorMessage.substring(0, 100)}..." : errorMessage,
                style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'monospace'),
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
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
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
    final completedCount = completionStatus.where((s) => s).length;
    final progress = workouts.isEmpty ? 0.0 : completedCount / workouts.length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.routine['name']?.toString().toUpperCase() ?? "RUTINA",
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_canStartToday
          ? _buildNotAvailableView()
          : isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Column(
                  children: [
                    _buildProgressBar(progress, completedCount),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: workouts.length,
                        itemBuilder: (context, index) {
                          final isCompleted = completionStatus[index];
                          final workoutGroup = workouts[index];
                          final List exercises = workoutGroup['exercises'] ?? [workoutGroup];

                          return _buildWorkoutCard(index, isCompleted, exercises, workoutGroup);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

   Widget _buildProgressBar(double progress, int completed) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 "PROGRESO DE LA RUTINA",
                 style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
               ),
               Text(
                 "$completed/${workouts.length}",
                 style: TextStyle(color: primaryColor, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
               ),
             ],
           ),
           const SizedBox(height: 12),
           ClipRRect(
             borderRadius: BorderRadius.circular(12),
             child: LinearProgressIndicator(
               value: progress,
               backgroundColor: Colors.white.withValues(alpha: 0.08),
               valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
               minHeight: 10,
             ),
           ),
         ],
       ),
     );
   }

   Widget _buildWorkoutCard(int index, bool isCompleted, List exercises, dynamic workoutGroup) {
     return GestureDetector(
       onTap: !isCompleted ? () => _showWorkoutDetail(index) : null,
       child: Container(
         margin: const EdgeInsets.only(bottom: 12),
         decoration: BoxDecoration(
           color: isCompleted ? primaryColor.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.03),
           borderRadius: BorderRadius.circular(20),
           border: Border.all(
             color: isCompleted ? primaryColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
             width: 1.5,
           ),
         ),
         child: ClipRRect(
           borderRadius: BorderRadius.circular(20),
           child: IntrinsicHeight(
             child: Row(
               children: [
                 // Barra lateral indicadora
                 Container(
                   width: 6,
                   decoration: BoxDecoration(
                     color: isCompleted ? primaryColor : Colors.transparent,
                     borderRadius: const BorderRadius.only(
                       topLeft: Radius.circular(20),
                       bottomLeft: Radius.circular(20),
                     ),
                   ),
                 ),
                 Expanded(
                   child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Row(
                       children: [
                         _buildStatusIcon(isCompleted),
                         const SizedBox(width: 14),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               // Nombre de ejercicios (puede ser múltiple para supersets)
                               Wrap(
                                 spacing: 4,
                                 runSpacing: 4,
                                 children: exercises.map((ex) {
                                   return Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                     decoration: BoxDecoration(
                                       color: isCompleted
                                         ? primaryColor.withValues(alpha: 0.1)
                                         : Colors.white.withValues(alpha: 0.05),
                                       borderRadius: BorderRadius.circular(6),
                                       border: Border.all(
                                         color: isCompleted
                                           ? primaryColor.withValues(alpha: 0.2)
                                           : Colors.white.withValues(alpha: 0.08),
                                       ),
                                     ),
                                     child: Text(
                                       ex['workoutName']?.toString().toUpperCase() ?? "DESCONOCIDO",
                                       style: TextStyle(
                                         color: isCompleted ? Colors.white.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.9),
                                         fontWeight: FontWeight.w800,
                                         fontSize: 12,
                                         letterSpacing: 0.3,
                                         decoration: isCompleted ? TextDecoration.lineThrough : null,
                                       ),
                                     ),
                                   );
                                 }).toList(),
                               ),
                               const SizedBox(height: 8),
                               // Series y reps
                               Row(
                                 children: [
                                   Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(
                                         Icons.repeat,
                                         size: 12,
                                         color: isCompleted
                                           ? primaryColor.withValues(alpha: 0.4)
                                           : primaryColor.withValues(alpha: 0.7),
                                       ),
                                       const SizedBox(width: 4),
                                       Text(
                                         "${workoutGroup['sets']} SERIES",
                                         style: TextStyle(
                                           color: isCompleted
                                             ? primaryColor.withValues(alpha: 0.3)
                                             : primaryColor.withValues(alpha: 0.7),
                                           fontSize: 10,
                                           fontWeight: FontWeight.w700,
                                           letterSpacing: 0.2,
                                         ),
                                       ),
                                     ],
                                   ),
                                   const SizedBox(width: 16),
                                   Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(
                                         Icons.fitness_center,
                                         size: 12,
                                         color: isCompleted
                                           ? secondaryColor.withValues(alpha: 0.4)
                                           : secondaryColor.withValues(alpha: 0.7),
                                       ),
                                       const SizedBox(width: 4),
                                       Text(
                                         exercises.map((e) => "${e['reps']} ").join('+ '),
                                         style: TextStyle(
                                           color: isCompleted
                                             ? secondaryColor.withValues(alpha: 0.3)
                                             : secondaryColor.withValues(alpha: 0.7),
                                           fontSize: 10,
                                           fontWeight: FontWeight.w700,
                                           letterSpacing: 0.2,
                                         ),
                                       ),
                                       Text(
                                         "REPS",
                                         style: TextStyle(
                                           color: isCompleted
                                             ? secondaryColor.withValues(alpha: 0.3)
                                             : secondaryColor.withValues(alpha: 0.7),
                                           fontSize: 10,
                                           fontWeight: FontWeight.w700,
                                           letterSpacing: 0.2,
                                         ),
                                       ),
                                     ],
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                         if (!isCompleted)
                           Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2), size: 22),
                       ],
                     ),
                   ),
                 ),
               ],
             ),
           ),
         ),
       ),
     );
   }

   Widget _buildStatusIcon(bool isCompleted) {
     return AnimatedContainer(
       duration: const Duration(milliseconds: 300),
       width: 44,
       height: 44,
       decoration: BoxDecoration(
         gradient: isCompleted
           ? LinearGradient(
               colors: [primaryColor.withValues(alpha: 0.8), primaryColor],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
             )
           : null,
         color: isCompleted ? null : Colors.white.withValues(alpha: 0.06),
         shape: BoxShape.circle,
         border: isCompleted
           ? null
           : Border.all(
               color: Colors.white.withValues(alpha: 0.12),
               width: 2,
             ),
         boxShadow: isCompleted
           ? [
               BoxShadow(
                 color: primaryColor.withValues(alpha: 0.3),
                 blurRadius: 12,
                 spreadRadius: 2,
               ),
             ]
           : null,
       ),
       child: Icon(
         isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
         color: isCompleted ? backgroundColor : primaryColor,
         size: 22,
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
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_clock_outlined, color: Colors.redAccent, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Próximamente',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Esta rutina estará disponible en la fecha programada.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('VOLVER AL INICIO', style: TextStyle(fontWeight: FontWeight.bold)),
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
       decoration: BoxDecoration(
         color: const Color(0xFF11151C),
         borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
       ),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           const SizedBox(height: 12),
           Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
           Flexible(
             child: SingleChildScrollView(
               padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _buildHeader(),
                   const SizedBox(height: 16),
                   ..._buildExerciseDetailsList(),
                   const SizedBox(height: 24),
                   const Text("¿CÓMO TE SENTISTE?", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                   const SizedBox(height: 12),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       _feedbackBtn("Struggled", Icons.sentiment_very_dissatisfied, Colors.redAccent, "DIFÍCIL"),
                       _feedbackBtn("Good", Icons.sentiment_satisfied, widget.primaryColor, "BIEN"),
                       _feedbackBtn("Overperformed", Icons.bolt, Colors.orangeAccent, "EXCELENTE"),
                     ],
                   ),
                   const SizedBox(height: 20),
                   SizedBox(
                     width: double.infinity,
                     height: 52,
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
                       style: ElevatedButton.styleFrom(
                         backgroundColor: widget.primaryColor,
                         foregroundColor: Colors.black,
                         elevation: 0,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                       child: const Text("GUARDAR EJERCICIO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
           if (idx > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10, height: 1)),
           if (idx > 0) const SizedBox(height: 16),
           _buildExerciseCard(idx, ex, details),
         ],
       );
     }).toList();
   }

   Widget _buildExerciseCard(int idx, dynamic ex, Map<String, dynamic>? details) {
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
                             style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
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
               borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
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
                 borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                 color: Colors.white10,
               ),
               child: const Center(
                 child: Icon(Icons.videocam_off, color: Colors.white24, size: 40),
               ),
             ),
           // Descripción y detalles
           if (details?['description'] != null && details!['description'].toString().isNotEmpty) ...[
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
             child: _buildWeightInputCompact(idx, ex['weight']?.toString() ?? "0"),
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
             border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
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
             border: Border.all(color: widget.secondaryColor.withValues(alpha: 0.3)),
           ),
           child: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Icon(Icons.fitness_center, size: 14, color: widget.secondaryColor),
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

   Widget _buildWeightInputCompact(int idx, String recommendedWeight) {
     return Container(
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.white.withValues(alpha: 0.04),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
       ),
       child: Row(
         children: [
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text("PESO RECOMENDADO",
                 style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
               const SizedBox(height: 2),
               Text("$recommendedWeight kg",
                 style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w900)),
             ],
           ),
           const Spacer(),
           Container(
             width: 70,
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
             decoration: BoxDecoration(
               color: widget.primaryColor.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: widget.primaryColor.withValues(alpha: 0.2)),
             ),
             child: Column(
               children: [
                 Text("TU PESO",
                   style: TextStyle(color: widget.primaryColor.withValues(alpha: 0.6), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                 const SizedBox(height: 4),
                 TextField(
                   controller: _weightControllers[idx],
                   keyboardType: TextInputType.number,
                   textAlign: TextAlign.center,
                   style: TextStyle(color: widget.primaryColor, fontSize: 16, fontWeight: FontWeight.w900),
                   decoration: InputDecoration(
                     isDense: true,
                     border: InputBorder.none,
                     hintText: "0",
                     hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                     suffixText: "kg",
                     suffixStyle: TextStyle(color: widget.primaryColor.withValues(alpha: 0.5), fontSize: 8, fontWeight: FontWeight.bold),
                   ),
                 ),
               ],
             ),
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
          decoration: BoxDecoration(color: widget.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(
            widget.exercises.length > 1 ? "SUPERSET" : "SIMPLE",
            style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
          ),
        ),
      ],
    );
  }



  Widget _feedbackBtn(String value, IconData icon, Color color, String displayLabel) {
    bool isSelected = selectedFeedback == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFeedback = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white24, size: 24),
            const SizedBox(height: 6),
            Text(displayLabel, style: TextStyle(color: isSelected ? color : Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
