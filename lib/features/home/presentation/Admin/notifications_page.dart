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

              return _buildNotificationCard(doc, data, isRead, date);
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tarjeta de notificación (rediseño moderno)
  // ---------------------------------------------------------------------------

  ({IconData icon, Color color}) _notificationVisual(String type) {
    switch (type) {
      case 'routine_completed':
        return (icon: Icons.fitness_center_rounded, color: primaryColor);
      case 'pdf_request':
        return (icon: Icons.picture_as_pdf_rounded, color: const Color(0xFF64B5F6));
      case 'pdf_approved':
        return (icon: Icons.check_circle_rounded, color: Colors.greenAccent);
      case 'pdf_rejected':
        return (icon: Icons.cancel_rounded, color: Colors.redAccent);
      default:
        return (icon: Icons.notifications_rounded, color: const Color(0xFF89AC76));
    }
  }

  Widget _buildNotificationCard(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isRead,
    DateTime date,
  ) {
    final type = (data['type'] ?? '').toString();
    final visual = _notificationVisual(type);
    final isPdfRequest = type == 'pdf_request';
    final isProcessed = data['processed'] == true || _notificationStatus[doc.id] != null;

    void onCardTap() {
      if (isPdfRequest) return;
      _markAsRead(doc.id);
      final logId = data['logId']?.toString();
      if (logId == null || logId.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewNotificationPage(logId: logId, notificationId: doc.id),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isRead ? surfaceColor.withValues(alpha: 0.04) : const Color(0xFF1A2029),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead ? Colors.white.withValues(alpha: 0.06) : visual.color.withValues(alpha: 0.35),
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
                    onTap: isPdfRequest ? null : onCardTap,
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
                                // Título + indicador / cierre
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['title'] ?? 'Notificación',
                                        style: TextStyle(
                                          color: isRead ? Colors.white70 : Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      GestureDetector(
                                        onTap: () => _markAsRead(doc.id),
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
                                // Cuerpo
                                Text(
                                  data['message'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                // Acciones / estado de solicitud de PDF
                                if (isPdfRequest) ...[
                                  const SizedBox(height: 12),
                                  if (isProcessed)
                                    _buildStatusChip(data, doc.id)
                                  else
                                    _buildPdfActions(doc.id, data),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  DateFormat('HH:mm - dd MMM').format(date),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 10.5,
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

  Widget _buildStatusChip(Map<String, dynamic> data, String docId) {
    final approved = (data['processedBy'] ?? _notificationStatus[docId]) == 'approved';
    final color = approved ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(approved ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            approved ? 'APROBADO' : 'RECHAZADO',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfActions(String docId, Map<String, dynamic> data) {
    final processing = _processingNotifications.contains(docId);
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: processing
                ? null
                : () => _handlePdfRequest(context, docId, data['userId'], data['resourceId'], true),
            icon: processing
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11151C)),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: const Text('APROBAR', overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              backgroundColor: processing ? primaryColor.withValues(alpha: 0.5) : primaryColor,
              foregroundColor: const Color(0xFF11151C),
              disabledBackgroundColor: primaryColor.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white38,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 11),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: processing
                ? null
                : () => _handlePdfRequest(context, docId, data['userId'], data['resourceId'], false),
            icon: processing
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                    ),
                  )
                : const Icon(Icons.close_rounded, size: 16),
            label: const Text('RECHAZAR', overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: processing ? Colors.white24 : Colors.redAccent,
              disabledForegroundColor: Colors.white24,
              side: BorderSide(color: processing ? Colors.white24 : Colors.redAccent.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}
