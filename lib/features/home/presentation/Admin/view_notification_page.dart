import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewNotificationPage extends StatefulWidget {
  final String logId;
  final String notificationId;

  const ViewNotificationPage({
    super.key,
    required this.logId,
    required this.notificationId,
  });

  @override
  State<ViewNotificationPage> createState() => _ViewNotificationPageState();
}

class _ViewNotificationPageState extends State<ViewNotificationPage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);
  final TextEditingController _trainerFeedbackController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(widget.notificationId)
        .update({'read': true});
  }

  Future<void> _saveTrainerFeedback(String userId, String routineName) async {
    final feedbackText = _trainerFeedbackController.text.trim();
    if (feedbackText.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('routine_logs')
          .doc(widget.logId)
          .update({
        'trainerFeedback': feedbackText,
        'feedbackAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'trainer_feedback',
        'title': '¡Tu Trainer ha respondido!',
        'message': 'Feedback sobre tu rutina: $routineName',
        'trainerFeedback': feedbackText,
        'userId': userId,
        'targetRole': 'client',
        'logId': widget.logId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback enviado al cliente'), behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('DETALLES DE RUTINA',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('routine_logs')
            .doc(widget.logId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(
                child: Text("Log no encontrado",
                    style: TextStyle(color: Colors.white70)));
          }

          final results = data['results'] as List<dynamic>? ?? [];
          final date = (data['date'] as Timestamp).toDate();
          final clientName = data['userName'] ?? 'Cliente';
          final routineName = data['routineName'] ?? 'Rutina';
          final clientId = data['userId'];
          final clientGeneralFeedback = (data['clientFeedback'] ?? '').toString().trim();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(clientName, routineName, date),
                const SizedBox(height: 32),
                
                const Text("COMENTARIO DEL CLIENTE",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: clientGeneralFeedback.isNotEmpty 
                        ? Colors.orangeAccent.withOpacity(0.1)
                        : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: clientGeneralFeedback.isNotEmpty 
                          ? Colors.orangeAccent.withOpacity(0.3)
                          : Colors.white.withOpacity(0.05)
                    ),
                  ),
                  child: Text(
                    clientGeneralFeedback.isNotEmpty 
                        ? clientGeneralFeedback 
                        : "El cliente no dejó comentarios adicionales.",
                    style: TextStyle(
                      color: clientGeneralFeedback.isNotEmpty ? Colors.white : Colors.white24, 
                      fontSize: 14, 
                      fontStyle: clientGeneralFeedback.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                      height: 1.5
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Text("DESGLOSE DE EJERCICIOS",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                const SizedBox(height: 16),
                ...results.map((res) => _buildWorkoutResultCard(res)).toList(),
                const SizedBox(height: 40),
                const Text("TU FEEDBACK (TRAINER)",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                const SizedBox(height: 16),
                TextField(
                  controller: _trainerFeedbackController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Escribe algo motivador o correcciones...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.all(20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveTrainerFeedback(clientId, routineName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                        : const Text("ENVIAR FEEDBACK",
                            style: TextStyle(
                                fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String name, String routine, DateTime date) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: surfaceColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: primaryColor, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(routine,
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(date),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutResultCard(Map<String, dynamic> res) {
    Color feedbackColor = Colors.white38;
    IconData feedbackIcon = Icons.sentiment_neutral;

    if (res['feedback'] == 'Struggled') {
      feedbackColor = Colors.redAccent;
      feedbackIcon = Icons.sentiment_very_dissatisfied;
    } else if (res['feedback'] == 'Good') {
      feedbackColor = primaryColor;
      feedbackIcon = Icons.sentiment_satisfied;
    } else if (res['feedback'] == 'Overperformed') {
      feedbackColor = Colors.orangeAccent;
      feedbackIcon = Icons.bolt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(res['workoutName'].toString().toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: feedbackColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(feedbackIcon, color: feedbackColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      res['feedback'].toString().toUpperCase(),
                      style: TextStyle(color: feedbackColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...((res['exercises'] as List<dynamic>? ?? []).map((ex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ex['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    _buildSmallStat("PLAN", "${ex['plannedWeight'] ?? 0}kg"),
                    const SizedBox(width: 16),
                    _buildSmallStat("REAL", "${ex['actualWeight'] ?? 0}kg", highlight: true),
                  ],
                ),
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value,
      {bool highlight = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        Text(value,
            style: TextStyle(
                color: color ?? (highlight ? primaryColor : Colors.white70),
                fontSize: 13,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}
