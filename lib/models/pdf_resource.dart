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

  static double _parsePrice(Map<String, dynamic> data) {
    final raw = data['price'] ?? data['precio'] ?? data['cost'];
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  factory PdfResource.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final parsedPrice = _parsePrice(data);
    final isFree = (data['isFree'] == true) && (parsedPrice == 0.0);

    return PdfResource(
      id: doc.id,
      name: data['name'] ?? 'Sin nombre',
      url: data['url'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      price: parsedPrice,
      isFree: isFree,
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
