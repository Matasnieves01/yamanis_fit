import 'package:cloud_firestore/cloud_firestore.dart';

class PdfResource {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;

  PdfResource({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  factory PdfResource.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PdfResource(
      id: doc.id,
      name: data['name'] ?? 'Sin nombre',
      url: data['url'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'createdAt': createdAt,
    };
  }
}
