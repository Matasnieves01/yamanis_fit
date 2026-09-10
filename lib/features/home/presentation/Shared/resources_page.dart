import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/pdf_cache_service.dart';
import 'package:yamanis_fit/models/pdf_resource.dart';
import '../Admin/upload_pdf_page.dart';
import 'pdf_viewer_page.dart';

class ResourcesPage extends StatefulWidget {
  final bool isAdmin;
  const ResourcesPage({super.key, required this.isAdmin});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'free', 'premium', 'my_guides'
  String _searchQuery = '';

  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161D27);
  final Color surfaceColor = const Color(0xFF1F2937);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color secondaryColor = const Color(0xFF89AC76);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deletePdf(PdfResource resource) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Eliminar Guía', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${resource.name}"? Los usuarios ya no podrán acceder a ella.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('resources').doc(resource.id).delete();
      // Eliminar también la copia en caché local si existía
      await PdfCacheService.removeCachedFile(resource.url, resourceId: resource.id);

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

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Nueva solicitud de PDF',
        'message': '${user.email} solicita acceso a: ${resource.name}',
        'type': 'pdf_request',
        'targetRole': 'admin',
        'userId': user.uid,
        'resourceId': resource.id,
        'resourceName': resource.name,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'SOLICITUD ENVIADA',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Has solicitado acceso a:\n"${resource.name}"',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para completar el desbloqueo, envía el comprobante de pago por WhatsApp a la entrenadora.\n\nUna vez confirmado, la guía se habilitará automáticamente en tu cuenta.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
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

  void _openPdfViewer(PdfResource resource) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfViewerPage(resource: resource)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'RECURSOS Y GUÍAS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 26),
              tooltip: 'Añadir nueva guía',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadPdfPage()),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildResourcesList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de búsqueda
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por título o tema...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: primaryColor.withValues(alpha: 0.7), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chips de filtrado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todos', 'all', Icons.grid_view_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Gratuitos', 'free', Icons.card_giftcard_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Premium', 'premium', Icons.workspace_premium_rounded),
                if (!widget.isAdmin) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('Mis Guías', 'my_guides', Icons.bookmark_added_rounded),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final bool isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : surfaceColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? backgroundColor : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? backgroundColor : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('resources')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar recursos: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.picture_as_pdf_outlined,
            title: 'No hay guías disponibles',
            subtitle: widget.isAdmin
                ? 'Toca el botón superior "+" para subir tu primer PDF.'
                : 'Pronto la entrenadora añadirá material exclusivo.',
          );
        }

        final allResources = docs.map((doc) => PdfResource.fromFirestore(doc)).toList();
        final user = FirebaseAuth.instance.currentUser;
        final userId = user?.uid;

        if (userId == null) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: allResources.length,
          itemBuilder: (context, index) {
            final resource = allResources[index];

            // Filtro por texto de búsqueda
            if (_searchQuery.isNotEmpty &&
                !resource.name.toLowerCase().contains(_searchQuery)) {
              return const SizedBox.shrink();
            }

            // Para administradores: siempre tienen acceso completo
            if (widget.isAdmin) {
              if (_selectedFilter == 'free' && !resource.isFree) return const SizedBox.shrink();
              if (_selectedFilter == 'premium' && resource.isFree) return const SizedBox.shrink();
              return _buildResourceCard(
                resource: resource,
                userId: userId,
                status: 'approved',
                hasAccess: true,
              );
            }

            // Para clientes: consultar estado de permisos en Firestore
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pdf_access')
                  .doc('${userId}_${resource.id}')
                  .snapshots(),
              builder: (context, accessSnapshot) {
                final accessData = accessSnapshot.data?.data() as Map<String, dynamic>?;
                final String rawStatus = accessData?['status']?.toString() ?? 'none';
                final String status = rawStatus.toLowerCase().trim();
                final bool hasAccess = resource.isFree || status == 'approved';

                // Aplicar filtros seleccionados
                if (_selectedFilter == 'free' && !resource.isFree) {
                  return const SizedBox.shrink();
                }
                if (_selectedFilter == 'premium' && resource.isFree) {
                  return const SizedBox.shrink();
                }
                if (_selectedFilter == 'my_guides' && !hasAccess) {
                  return const SizedBox.shrink();
                }

                return _buildResourceCard(
                  resource: resource,
                  userId: userId,
                  status: status,
                  hasAccess: hasAccess,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildResourceCard({
    required PdfResource resource,
    required String userId,
    required String status,
    required bool hasAccess,
  }) {
    final coverUrl = resource.coverImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAccess
              ? primaryColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          width: hasAccess ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (hasAccess || widget.isAdmin) {
              _openPdfViewer(resource);
            } else if (status == 'pending') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tu solicitud está en revisión. La entrenadora verificará tu pago pronto.'),
                ),
              );
            } else {
              _requestAccess(resource);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Portada del PDF (Efecto libro/revista)
                _buildCoverThumbnail(resource, coverUrl, hasAccess, status),
                const SizedBox(width: 14),

                // Información y Botones
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 11, color: primaryColor),
                                const SizedBox(width: 4),
                                const Text(
                                  'GUÍA DIGITAL',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (widget.isAdmin)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              tooltip: 'Eliminar guía',
                              onPressed: () => _deletePdf(resource),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Título
                      Text(
                        resource.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Estado de acceso o precio
                      _buildPriceOrStatusTag(resource, hasAccess, status),
                      const SizedBox(height: 12),

                      // Botón de acción
                      _buildActionButton(resource, hasAccess, status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverThumbnail(
    PdfResource resource,
    String? coverUrl,
    bool hasAccess,
    String status,
  ) {
    const double coverWidth = 105;
    const double coverHeight = 145;

    return Container(
      width: coverWidth,
      height: coverHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen de portada (desde Drive thumbnail o personalizada)
            if (coverUrl != null && coverUrl.isNotEmpty)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildCoverPlaceholder(resource, isLoading: true);
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildCoverPlaceholder(resource);
                },
              )
            else
              _buildCoverPlaceholder(resource),

            // Sombra degradada inferior para legibilidad
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Lomo decorativo de libro a la izquierda
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      primaryColor.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Insignia superior izquierda (Gratis / Premium / Acceso)
            Positioned(
              top: 8,
              left: 8,
              child: _buildCoverBadge(resource, hasAccess, status),
            ),

            // Ícono de caché local (si ya está descargado)
            Positioned(
              bottom: 6,
              right: 6,
              child: FutureBuilder(
                future: PdfCacheService.getCachedFile(resource.url, resourceId: resource.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: backgroundColor.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Icon(Icons.bolt_rounded, size: 12, color: primaryColor),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverBadge(PdfResource resource, bool hasAccess, String status) {
    if (resource.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'GRATIS',
          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
        ),
      );
    }

    if (hasAccess) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'ACCESO',
          style: TextStyle(color: backgroundColor, fontSize: 9, fontWeight: FontWeight.w900),
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'PENDIENTE',
          style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 9),
          SizedBox(width: 3),
          Text(
            'PRO',
            style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder(PdfResource resource, {bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF222B38),
            const Color(0xFF131820),
          ],
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            CircularProgressIndicator(strokeWidth: 2, color: primaryColor)
          else ...[
            Icon(Icons.picture_as_pdf_rounded, size: 38, color: primaryColor.withValues(alpha: 0.8)),
            const SizedBox(height: 8),
            Text(
              resource.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceOrStatusTag(PdfResource resource, bool hasAccess, String status) {
    if (resource.isFree) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            'Incluido en tu membresía',
            style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    if (hasAccess) {
      return Row(
        children: [
          Icon(Icons.verified_rounded, size: 14, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            'Desbloqueado para siempre',
            style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    if (status == 'pending') {
      return Row(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.orangeAccent),
          const SizedBox(width: 4),
          const Text(
            'Verificación en curso',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          '\$${resource.price.toStringAsFixed(2)}',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'USD',
          style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButton(PdfResource resource, bool hasAccess, String status) {
    if (hasAccess || widget.isAdmin) {
      return SizedBox(
        width: double.infinity,
        height: 38,
        child: ElevatedButton.icon(
          onPressed: () => _openPdfViewer(resource),
          icon: const Icon(Icons.auto_stories_rounded, size: 16),
          label: const Text(
            'LEER GUÍA',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: backgroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        width: double.infinity,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty_rounded, color: Colors.orangeAccent, size: 15),
              SizedBox(width: 6),
              Text(
                'EN REVISIÓN',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: ElevatedButton.icon(
        onPressed: () => _requestAccess(resource),
        icon: const Icon(Icons.lock_open_rounded, size: 16),
        label: const Text(
          'DESBLOQUEAR',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceColor,
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor.withValues(alpha: 0.6)),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Icon(icon, size: 52, color: Colors.white38),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
