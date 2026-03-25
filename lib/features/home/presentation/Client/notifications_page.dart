import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientNotificationsPage extends StatelessWidget {
  const ClientNotificationsPage({super.key});

  static const Color _backgroundColor = Color(0xFF11151C);
  static const Color _surfaceColor = Color(0xFF55768C);
  static const Color _primaryColor = Color(0xFFAEE084);

  Stream<QuerySnapshot<Map<String, dynamic>>> _getNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'read': true});
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Text(
            'Inicia sesion para ver notificaciones',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'MIS NOTIFICACIONES',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getNotifications(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs
              .where((doc) => doc.data()['type'] == 'trainer_feedback')
              .toList()
            ..sort((a, b) {
              final aDate = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bDate = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bDate.compareTo(aDate);
            });

          if (docs.isEmpty) {
            return const Center(
              child: Text('Aun no tienes feedback del trainer', style: TextStyle(color: Colors.white54)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['read'] == true;
              final feedback = (data['trainerFeedback'] ?? '').toString().trim();
              final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : _surfaceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRead ? Colors.white10 : _primaryColor.withOpacity(0.35),
                  ),
                ),
                child: ListTile(
                  onTap: () async {
                    await _markAsRead(doc.id);
                    if (!context.mounted) return;

                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: Text(
                          data['title'] ?? 'Feedback de tu trainer',
                          style: const TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          feedback.isEmpty ? (data['message'] ?? '') : feedback,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.white10 : _primaryColor.withOpacity(0.2),
                    child: Icon(
                      Icons.message_outlined,
                      color: isRead ? Colors.white38 : _primaryColor,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? 'Feedback de tu trainer',
                    style: TextStyle(
                      color: isRead ? Colors.white60 : Colors.white,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback.isEmpty ? (data['message'] ?? '') : feedback,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                  trailing: isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

