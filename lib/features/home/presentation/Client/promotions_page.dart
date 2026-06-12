import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/models/promotion.dart';
import 'promotion_detail_page.dart';
import '../../../../core/widgets/branded_loading_screen.dart';

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
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PromotionDetailPage(promotion: promotion),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: surfaceColor.withValues(alpha: 0.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _chip('PROMOCIÓN', primaryColor),
                        Icon(Icons.arrow_forward_rounded, color: primaryColor, size: 20),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promotion.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promotion.description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
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
            return const BrandedLoadingScreen();
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
              child: Text('Aún no hay promociones disponibles', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: promotions.length,
            itemBuilder: (context, index) => _buildPromotionCard(promotions[index]),
          );
        },
      ),
    );
  }
}

