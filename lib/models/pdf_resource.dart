import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yamanis_fit/core/services/pdf_cache_service.dart';

class PdfResource {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;
  final double price;
  final bool isFree;
  final String? thumbnailUrl;

  PdfResource({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
    this.price = 0.0,
    this.isFree = true,
    this.thumbnailUrl,
  });

  /// Retorna la URL de la portada: o la imagen personalizada o la miniatura generada de Drive
  String? get coverImageUrl {
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return thumbnailUrl;
    }
    return PdfCacheService.getDriveThumbnailUrl(url, width: 800);
  }

  factory PdfResource.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PdfResource(
      id: doc.id,
      name: data['name'] ?? 'Sin nombre',
      url: data['url'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      price: (data['price'] ?? 0.0).toDouble(),
      isFree: data['isFree'] ?? true,
      thumbnailUrl: data['thumbnailUrl'] ?? data['coverUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'createdAt': createdAt,
      'price': price,
      'isFree': isFree,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }
}
