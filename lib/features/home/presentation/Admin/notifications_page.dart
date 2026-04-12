import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'view_notification_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);

  Stream<QuerySnapshot> _getNotifications() {
    // Updated query to match security rules: only fetch notifications targeted to admin
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('targetRole', isEqualTo: 'admin')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _markAsRead(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('NOTIFICACIONES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No hay notificaciones", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isRead = data['read'] ?? false;
              final DateTime date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : surfaceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isRead ? Colors.white10 : primaryColor.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  onTap: () {
                    _markAsRead(doc.id);
                    final logId = data['logId']?.toString();
                    if (logId == null || logId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewNotificationPage(
                          logId: logId,
                          notificationId: doc.id,
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.white10 : primaryColor.withValues(alpha: 0.2),
                    child: Icon(
                      data['type'] == 'routine_completed' ? Icons.fitness_center : Icons.notifications,
                      color: isRead ? Colors.white38 : primaryColor,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? 'Notificación',
                    style: TextStyle(
                      color: isRead ? Colors.white60 : Colors.white,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? '', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm - dd MMM').format(date),
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                  trailing: isRead 
                    ? null 
                    : Container(width: 8, height: 8, decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
