import 'package:cloud_firestore/cloud_firestore.dart';

class PdfResource {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;
  final double price;
  final bool isFree;

  PdfResource({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
    this.price = 0.0,
    this.isFree = true,
  });

  factory PdfResource.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PdfResource(
      id: doc.id,
      name: data['name'] ?? 'Sin nombre',
      url: data['url'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      price: (data['price'] ?? 0.0).toDouble(),
      isFree: data['isFree'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'createdAt': createdAt,
      'price': price,
      'isFree': isFree,
    };
  }
}
