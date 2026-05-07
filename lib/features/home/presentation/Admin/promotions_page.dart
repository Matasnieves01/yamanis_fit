import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/models/promotion.dart';
import 'create_promotion_page.dart';
import 'edit_promotion_page.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);

  Stream<QuerySnapshot<Map<String, dynamic>>> _promotionsStream() {
    return FirebaseFirestore.instance
        .collection('promotions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _deletePromotion(Promotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Eliminar promoción', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Quieres eliminar "${promotion.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('promotions').doc(promotion.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promoción eliminada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: surfaceColor.withValues(alpha: 0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (promotion.imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  promotion.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: surfaceColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      backgroundColor.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _chip('PROMOCIÓN', primaryColor),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditPromotionPage(promotion: promotion),
                                ),
                              );
                              if (updated == true) {
                                // Refresh the stream by triggering a rebuild
                                (context as Element).markNeedsBuild();
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            onPressed: () => _deletePromotion(promotion),
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    promotion.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    promotion.description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Videos: ${promotion.videoUrls.length}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ),
                      _chip('GRATIS', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('PROMOCIONES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _promotionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los datos', style: TextStyle(color: Colors.white70)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final promotions = docs.map((doc) => Promotion.fromFirestore(doc)).toList();

          if (promotions.isEmpty) {
            return const Center(
              child: Text('Aún no hay entrenamientos', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: promotions.length,
            itemBuilder: (context, index) => _buildPromotionCard(promotions[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'promotions_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePromotionPage()),
          );
        },
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva promoción', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
