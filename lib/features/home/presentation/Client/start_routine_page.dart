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
  List<String?> feedbackList = [];
  Map<String, Map<String, dynamic>> workoutDetailsCache = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    workouts = widget.routine['workouts'] ?? [];
    completionStatus = List.generate(workouts.length, (index) => false);
    feedbackList = List.generate(workouts.length, (index) => null);
    _loadAllWorkoutDetails();
  }

  Future<void> _loadAllWorkoutDetails() async {
    for (var workout in workouts) {
      final id = workout['workoutId'];
      if (id != null && !workoutDetailsCache.containsKey(id)) {
        final doc = await FirebaseFirestore.instance.collection('workouts').doc(id).get();
        if (doc.exists) {
          workoutDetailsCache[id] = doc.data()!;
        }
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _showWorkoutDetail(int index) {
    final workout = workouts[index];
    final details = workoutDetailsCache[workout['workoutId']];
    if (details == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => WorkoutDetailSheet(
        workout: workout,
        details: details,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        onComplete: (feedback) {
          setState(() {
            completionStatus[index] = true;
            feedbackList[index] = feedback;
          });
          _checkRoutineCompletion();
        },
      ),
    );
  }

  void _checkRoutineCompletion() async {
    if (completionStatus.every((status) => status)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Save Log to Firestore for Admin
      await FirebaseFirestore.instance.collection('routine_logs').add({
        'routineId': widget.routineId,
        'routineName': widget.routine['name'],
        'userId': user.uid,
        'date': Timestamp.now(),
        'results': List.generate(workouts.length, (i) => {
          'workoutName': workouts[i]['workoutName'],
          'feedback': feedbackList[i],
        }),
      });

      if (!mounted) return;
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Routine Completed!", style: TextStyle(color: Colors.white)),
        content: Text("Great job! Your progress has been sent to your trainer.", 
          style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to dashboard
            },
            child: Text("FINISH", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
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
        title: Text(widget.routine['name']?.toString().toUpperCase() ?? "ROUTINE"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WORKOUT LIST",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Complete exercises in order to unlock the next one.",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: workouts.length,
                      itemBuilder: (context, index) {
                        final isCompleted = completionStatus[index];
                        final isAvailable = index == 0 || completionStatus[index - 1];
                        final workout = workouts[index];

                        return GestureDetector(
                          onTap: isAvailable && !isCompleted ? () => _showWorkoutDetail(index) : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isCompleted 
                                ? primaryColor.withOpacity(0.1) 
                                : isAvailable ? surfaceColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isCompleted 
                                  ? primaryColor.withOpacity(0.3) 
                                  : isAvailable ? primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.05)
                              ),
                            ),
                            child: Row(
                              children: [
                                // Status Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isCompleted ? primaryColor : Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check : isAvailable ? Icons.play_arrow : Icons.lock_outline,
                                    color: isCompleted ? backgroundColor : isAvailable ? primaryColor : Colors.white24,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Text Data
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workout['workoutName']?.toString().toUpperCase() ?? "UNKNOWN",
                                        style: TextStyle(
                                          color: isAvailable ? Colors.white : Colors.white38,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${workout['sets']} Sets | ${workout['reps']} Reps | ${workout['weight']}kg",
                                        style: TextStyle(
                                          color: isAvailable ? primaryColor.withOpacity(0.7) : Colors.white12,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCompleted)
                                  Icon(Icons.check_circle, color: primaryColor),
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
  final dynamic workout;
  final Map<String, dynamic> details;
  final Color primaryColor;
  final Color secondaryColor;
  final Function(String feedback) onComplete;

  const WorkoutDetailSheet({
    super.key,
    required this.workout,
    required this.details,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onComplete,
  });

  @override
  State<WorkoutDetailSheet> createState() => _WorkoutDetailSheetState();
}

class _WorkoutDetailSheetState extends State<WorkoutDetailSheet> {
  late YoutubePlayerController _ytController;
  String selectedFeedback = "Good";

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.details['videoUrl'] ?? "");
    _ytController = YoutubePlayerController(
      initialVideoId: videoId ?? "",
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _ytController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // Video Player
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: YoutubePlayer(
              controller: _ytController,
              showVideoProgressIndicator: true,
              progressIndicatorColor: widget.primaryColor,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.workout['workoutName'].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatCard("SETS", widget.workout['sets']),
                        const SizedBox(width: 12),
                        _buildStatCard("REPS", widget.workout['reps']),
                        const SizedBox(width: 12),
                        _buildStatCard("WEIGHT", "${widget.workout['weight']}kg"),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text("INSTRUCTIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      widget.details['description'] ?? "No instructions provided.",
                      style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    const Text("HOW DID IT GO?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Feedback Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _feedbackBtn("Struggled", Icons.sentiment_very_dissatisfied, Colors.redAccent),
                        _feedbackBtn("Good", Icons.sentiment_satisfied, widget.primaryColor),
                        _feedbackBtn("Overperformed", Icons.bolt, Colors.orangeAccent),
                      ],
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onComplete(selectedFeedback);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("COMPLETE EXERCISE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _feedbackBtn(String label, IconData icon, Color color) {
    bool isSelected = selectedFeedback == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFeedback = label),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? color : Colors.transparent),
            ),
            child: Icon(icon, color: isSelected ? color : Colors.white30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isSelected ? color : Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
