import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientNotificationsPage extends StatefulWidget {
  const ClientNotificationsPage({super.key});

  @override
  State<ClientNotificationsPage> createState() => _ClientNotificationsPageState();
}

class _ClientNotificationsPageState extends State<ClientNotificationsPage> {
  static const Color _backgroundColor = Color(0xFF11151C);
  static const Color _surfaceColor = Color(0xFF1B222C);
  static const Color _primaryColor = Color(0xFFAEE084);

  bool _showAll = false;

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
    final month = _getMonthName(date.month);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month • $hour:$minute';
  }

  String _getMonthName(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Text(
            'Inicia sesión para ver notificaciones',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'FEEDBACK DEL TRAINER',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryColor));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar notificaciones', style: TextStyle(color: Colors.white54)));
          }

          final allDocs = snapshot.data!.docs
              .where((doc) {
                final type = doc.data()['type'];
                return type == 'trainer_feedback' || type == 'pdf_approved' || type == 'pdf_rejected';
              })
              .toList()
            ..sort((a, b) {
              final aDate = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bDate = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bDate.compareTo(aDate);
            });

          final unreadDocs = allDocs.where((doc) => doc.data()['read'] != true).toList();
          final docs = _showAll ? allDocs : unreadDocs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text(
                    _showAll ? 'Aún no tienes feedback del trainer' : 'No tienes notificaciones nuevas',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  if (!_showAll && allDocs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      child: const Text('VER NOTIFICACIONES PASADAS', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      icon: Icon(_showAll ? Icons.visibility_off_outlined : Icons.history, size: 16, color: _primaryColor),
                      label: Text(
                        _showAll ? 'VER SOLO NO LEÍDAS' : 'VER NOTIFICACIONES PASADAS',
                        style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                );
              }
              final doc = docs[index - 1];
              final data = doc.data();
              final isRead = data['read'] == true;
              final type = data['type'] ?? 'trainer_feedback';
              
              String feedback = '';
              if (type == 'trainer_feedback') {
                feedback = (data['trainerFeedback'] ?? '').toString().trim();
                if (feedback.isEmpty) feedback = (data['message'] ?? '');
              } else {
                feedback = (data['message'] ?? '');
              }
              
              final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final title = data['title'] ?? (type == 'pdf_approved' ? 'Acceso concedido' : 'Feedback de tu rutina');

              return _buildNotificationCard(
                docId: doc.id,
                title: title.toString(),
                feedback: feedback,
                date: date,
                type: type.toString(),
                isRead: isRead,
              );
            },
          );
        },
      ),
    );
  }

  ({IconData icon, Color color}) _notificationVisual(String type) {
    switch (type) {
      case 'pdf_approved':
        return (icon: Icons.picture_as_pdf_rounded, color: _primaryColor);
      case 'pdf_rejected':
        return (icon: Icons.error_outline_rounded, color: Colors.redAccent);
      default:
        return (icon: Icons.forum_rounded, color: _primaryColor);
    }
  }

  Widget _buildNotificationCard({
    required String docId,
    required String title,
    required String feedback,
    required DateTime date,
    required String type,
    required bool isRead,
  }) {
    final visual = _notificationVisual(type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isRead ? _surfaceColor.withValues(alpha: 0.4) : _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead ? Colors.white.withValues(alpha: 0.05) : visual.color.withValues(alpha: 0.35),
        ),
        boxShadow: isRead
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral de estado (no leída)
              Container(width: 4, color: isRead ? Colors.transparent : visual.color),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      if (!isRead) await _markAsRead(docId);
                      if (!context.mounted) return;
                      _showFeedbackDetail(context, title, feedback, date, type);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ícono según tipo
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: visual.color.withValues(alpha: isRead ? 0.10 : 0.18),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              visual.icon,
                              color: isRead ? visual.color.withValues(alpha: 0.6) : visual.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title.toUpperCase(),
                                        style: TextStyle(
                                          color: isRead ? Colors.white70 : Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      GestureDetector(
                                        onTap: () => _markAsRead(docId),
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: Colors.white.withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  feedback,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: isRead ? 0.4 : 0.6),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _formatDate(date),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbackDetail(BuildContext context, String title, String message, DateTime date, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (type == 'pdf_rejected' ? Colors.redAccent : _primaryColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    type == 'pdf_approved' 
                      ? Icons.picture_as_pdf_rounded 
                      : (type == 'pdf_rejected' ? Icons.error_outline_rounded : Icons.forum_rounded), 
                    color: type == 'pdf_rejected' ? Colors.redAccent : _primaryColor
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _formatDate(date),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              type == 'trainer_feedback' ? 'MENSAJE DEL TRAINER:' : 'DETALLES:',
              style: TextStyle(
                color: type == 'pdf_rejected' ? Colors.redAccent : _primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.87),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: type == 'pdf_rejected' ? Colors.redAccent : _primaryColor,
                  foregroundColor: _backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
