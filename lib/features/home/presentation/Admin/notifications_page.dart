import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'view_notification_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);

  // Track processing state for each notification
  final Set<String> _processingNotifications = {};
  final Map<String, String> _notificationStatus = {};
  bool _showAll = false;

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

  Future<void> _handlePdfRequest(BuildContext context, String notificationId, String userId, String resourceId, bool approve) async {
    // Prevent double-clicking
    if (_processingNotifications.contains(notificationId)) {
      return;
    }

    setState(() {
      _processingNotifications.add(notificationId);
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('pdf_access').doc('${userId}_$resourceId');

      if (approve) {
        // Ensure the document exists first (set it if it doesn't)
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          await docRef.set({
            'userId': userId,
            'resourceId': resourceId,
            'status': 'pending',
            'requestedAt': FieldValue.serverTimestamp(),
          });
        }

        // Now update the status to approved
        await docRef.update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': FirebaseFirestore.instance.app.name,
        });
        
        // Notificar al usuario que su acceso fue aprobado
        await FirebaseFirestore.instance.collection('notifications').add({
          'title': '✅ Acceso concedido',
          'message': 'Tu solicitud para acceder al PDF ha sido aprobada. ¡Ya puedes verlo!',
          'type': 'pdf_approved',
          'userId': userId,
          'resourceId': resourceId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'targetRole': 'user',
        });

        if (mounted) {
          _notificationStatus[notificationId] = 'approved';
          setState(() {});
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Acceso aprobado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Ensure the document exists first (set it if it doesn't)
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          await docRef.set({
            'userId': userId,
            'resourceId': resourceId,
            'status': 'pending',
            'requestedAt': FieldValue.serverTimestamp(),
          });
        }

        await docRef.update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseFirestore.instance.app.name,
        });

        // Notificar al usuario que su acceso fue rechazado con opción de reintento
        await FirebaseFirestore.instance.collection('notifications').add({
          'title': '❌ Solicitud rechazada',
          'message': 'Tu solicitud de acceso a este PDF fue rechazada. Si crees que es un error o deseas intentar nuevamente, por favor realiza el pago y envía un nuevo comprobante. También puedes contactar con la entrenadora para más información.',
          'type': 'pdf_rejected',
          'userId': userId,
          'resourceId': resourceId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'targetRole': 'user',
        });

        if (mounted) {
          _notificationStatus[notificationId] = 'rejected';
          setState(() {});
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Acceso rechazado'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Marcar la notificación del admin como leída y procesada
      await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
        'read': true,
        'processed': true,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': approve ? 'approved' : 'rejected',
      });
    } catch (e) {
      if (mounted) {
        _processingNotifications.remove(notificationId);
        setState(() {});
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        _processingNotifications.remove(notificationId);
      }
    }
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
          
          final allDocs = snapshot.data!.docs;
          final unreadDocs = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['read'] != true).toList();
          final docs = _showAll ? allDocs : unreadDocs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 56, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 12),
                  Text(
                    _showAll ? "No hay notificaciones" : "No tienes notificaciones nuevas",
                    style: const TextStyle(color: Colors.white54),
                  ),
                  if (!_showAll && allDocs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _showAll = true),
                      child: Text('VER NOTIFICACIONES PASADAS', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      icon: Icon(_showAll ? Icons.visibility_off_outlined : Icons.history, size: 16, color: primaryColor),
                      label: Text(
                        _showAll ? 'VER SOLO NO LEÍDAS' : 'VER NOTIFICACIONES PASADAS',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                );
              }
              final doc = docs[index - 1];
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
                  onTap: data['type'] == 'pdf_request' 
                    ? null // No hacer nada al clickear la tarjeta si es solicitud de PDF
                    : () {
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
                       if (data['type'] == 'pdf_request') ...[
                         const SizedBox(height: 12),
                         // Mostrar estado si ya fue procesado
                         if (data['processed'] == true || _notificationStatus[doc.id] != null) ...[
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                             decoration: BoxDecoration(
                               color: ((data['processedBy'] ?? _notificationStatus[doc.id]) == 'approved' ? Colors.green : Colors.red).withOpacity(0.1),
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(
                                 color: ((data['processedBy'] ?? _notificationStatus[doc.id]) == 'approved' ? Colors.green : Colors.red).withOpacity(0.3),
                               ),
                             ),
                             child: Row(
                               children: [
                                 Icon(
                                   (data['processedBy'] ?? _notificationStatus[doc.id]) == 'approved' ? Icons.check_circle : Icons.cancel,
                                   color: (data['processedBy'] ?? _notificationStatus[doc.id]) == 'approved' ? Colors.green : Colors.red,
                                   size: 16,
                                 ),
                                 const SizedBox(width: 8),
                                 Text(
                                   (data['processedBy'] ?? _notificationStatus[doc.id]) == 'approved' ? 'APROBADO' : 'RECHAZADO',
                                   style: TextStyle(
                                     color: (data['processedBy'] ?? _notificationStatus[doc.id]) == 'approved' ? Colors.green : Colors.red,
                                     fontWeight: FontWeight.bold,
                                     fontSize: 11,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                          ] else ...[
                            // Mostrar botones solo si NO ha sido procesado
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      child: ElevatedButton.icon(
                                        onPressed: _processingNotifications.contains(doc.id)
                                            ? null
                                            : () => _handlePdfRequest(
                                                  context,
                                                  doc.id,
                                                  data['userId'],
                                                  data['resourceId'],
                                                  true,
                                                ),
                                        icon: _processingNotifications.contains(doc.id)
                                            ? const SizedBox(
                                                height: 14,
                                                width: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFF11151C),
                                                ),
                                              )
                                            : const Icon(Icons.check, size: 16),
                                        label: const Text('APROBAR', overflow: TextOverflow.ellipsis),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _processingNotifications.contains(doc.id)
                                              ? primaryColor.withValues(alpha: 0.5)
                                              : primaryColor,
                                          foregroundColor: const Color(0xFF11151C),
                                          disabledBackgroundColor: primaryColor.withValues(alpha: 0.3),
                                          disabledForegroundColor: Colors.white38,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SizedBox(
                                      child: OutlinedButton.icon(
                                        onPressed: _processingNotifications.contains(doc.id)
                                            ? null
                                            : () => _handlePdfRequest(
                                                  context,
                                                  doc.id,
                                                  data['userId'],
                                                  data['resourceId'],
                                                  false,
                                                ),
                                        icon: _processingNotifications.contains(doc.id)
                                            ? const SizedBox(
                                                height: 14,
                                                width: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                                ),
                                              )
                                            : const Icon(Icons.close, size: 16),
                                        label: const Text('RECHAZAR', overflow: TextOverflow.ellipsis),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _processingNotifications.contains(doc.id)
                                              ? Colors.white24
                                              : Colors.redAccent,
                                          disabledForegroundColor: Colors.white24,
                                          side: BorderSide(
                                            color: _processingNotifications.contains(doc.id)
                                                ? Colors.white24
                                                : Colors.redAccent,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                       ],
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
