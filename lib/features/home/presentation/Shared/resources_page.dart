import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/models/pdf_resource.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pdf_viewer_page.dart';
import '../Admin/upload_pdf_page.dart';

class ResourcesPage extends StatefulWidget {
  final bool isAdmin;
  const ResourcesPage({super.key, required this.isAdmin});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color secondaryColor = const Color(0xFF89AC76);

  Future<void> _deletePdf(PdfResource resource) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Eliminar PDF', style: TextStyle(color: Colors.redAccent)),
        content: Text('¿Estás seguro de que quieres eliminar "${resource.name}"?', 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Eliminar solo de Firestore
      await FirebaseFirestore.instance.collection('resources').doc(resource.id).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurso eliminado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar PDF: $e')),
      );
    }
  }

  Future<void> _requestAccess(PdfResource resource) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Create access request
      await FirebaseFirestore.instance
          .collection('pdf_access')
          .doc('${user.uid}_${resource.id}')
          .set({
        'userId': user.uid,
        'userEmail': user.email,
        'resourceId': resource.id,
        'resourceName': resource.name,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // 2. Send notification to admin
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Nueva solicitud de PDF',
        'message': '${user.email} solicita acceso a: ${resource.name}',
        'type': 'pdf_request',
        'targetRole': 'admin',
        'userId': user.uid,
        'resourceId': resource.id,
        'resourceName': resource.name, // Añadido para facilitar la respuesta
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primaryColor.withOpacity(0.2)),
          ),
          title: Text('SOLICITUD ENVIADA', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: const Text(
            'Para completar el acceso, por favor envía el comprobante de pago por WhatsApp a la entrenadora.\n\nUna vez verificado, se te habilitará el acceso automáticamente.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ENTENDIDO', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar acceso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('RECURSOS Y GUÍAS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: primaryColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadPdfPage()),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resources')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar recursos', style: TextStyle(color: Colors.white70)));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 64, color: surfaceColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No hay recursos disponibles aún', style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final resource = PdfResource.fromFirestore(docs[index]);
              final user = FirebaseAuth.instance.currentUser;
              final userId = user?.uid;

              if (userId == null) {
                return const SizedBox.shrink();
              }

               // For admins, skip the PDF access check - they always have access
               if (widget.isAdmin) {
                 return _buildResourceCard(resource, userId, 'approved', true);
               }

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pdf_access')
                      .doc('${userId}_${resource.id}')
                      .snapshots(),
                  builder: (context, accessSnapshot) {
                    // Ignorar errores de permiso si el documento no existe
                    if (accessSnapshot.hasError) {
                      // Si hay error pero es por permiso al no existir el documento,
                      // asumimos que el usuario no tiene acceso
                      print('PDF Access error for ${userId}_${resource.id}: ${accessSnapshot.error}');
                      return _buildResourceCard(resource, userId, 'none', false);
                    }

                    if (accessSnapshot.connectionState == ConnectionState.waiting && !accessSnapshot.hasData) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        height: 80,
                        decoration: BoxDecoration(
                          color: surfaceColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFAEE084)))),
                      );
                    }

                    final accessData = accessSnapshot.data?.data() as Map<String, dynamic>?;
                    final String rawStatus = accessData?['status']?.toString() ?? 'none';
                    final String status = rawStatus.toLowerCase().trim();
                    final bool hasAccess = resource.isFree || status == 'approved';

                    return _buildResourceCard(resource, userId, status, hasAccess);
                  },
                );
             },
           );
         },
       ),
     );
   }

    Widget _buildResourceCard(PdfResource resource, String userId, String status, bool hasAccess) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surfaceColor.withOpacity(0.1),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(
           color: hasAccess ? primaryColor.withOpacity(0.2) : surfaceColor.withOpacity(0.2),
         ),
       ),
       child: ListTile(
         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
         leading: Container(
           padding: const EdgeInsets.all(10),
           decoration: BoxDecoration(
             color: (resource.isFree ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.1),
             shape: BoxShape.circle,
           ),
           child: Icon(
             resource.isFree ? Icons.picture_as_pdf : Icons.lock_outline,
             color: resource.isFree ? Colors.greenAccent : Colors.orangeAccent,
           ),
         ),
         title: Text(
           resource.name,
           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
         ),
         subtitle: Row(
           children: [
             Text(
               resource.isFree ? 'GRATIS' : '\$${resource.price.toStringAsFixed(2)}',
               style: TextStyle(
                 color: resource.isFree ? Colors.greenAccent : primaryColor,
                 fontSize: 12,
                 fontWeight: FontWeight.bold,
               ),
             ),
             if (!resource.isFree && status == 'pending') ...[
               const SizedBox(width: 8),
               const Text(
                 '• Pendiente',
                 style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
               ),
             ],
           ],
         ),
         trailing: widget.isAdmin
             ? IconButton(
                 icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                 onPressed: () => _deletePdf(resource),
               )
             : (hasAccess || status == 'approved')
                 ? TextButton(
                     onPressed: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => PdfViewerPage(resource: resource),
                         ),
                       );
                     },
                     child: Text('VER', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                   )
                 : status == 'pending'
                     ? Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.orangeAccent.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: const Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 14),
                             SizedBox(width: 4),
                             Text('PENDIENTE', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                           ],
                         ),
                       )
                     : TextButton(
                         onPressed: () => _requestAccess(resource),
                         child: Text('COMPRAR', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                       ),
         onTap: hasAccess || widget.isAdmin
             ? () {
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => PdfViewerPage(resource: resource),
                   ),
                 );
               }
             : null,
       ),
     );
   }
 }
