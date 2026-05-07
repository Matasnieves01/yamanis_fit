import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> videoUrls;
  final DateTime createdAt;
  final bool isActive;

  Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.videoUrls,
    required this.createdAt,
    required this.isActive,
  });

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Support both old format (videoUrl) and new format (videoUrls)
    List<String> videos = [];
    if (data['videoUrls'] is List) {
      videos = List<String>.from(data['videoUrls'] ?? []);
    } else if (data['videoUrl'] is String &&
        (data['videoUrl'] as String).isNotEmpty) {
      videos = [data['videoUrl'] as String];
    }

    return Promotion(
      id: doc.id,
      title: data['title'] ?? 'Sin título',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      videoUrls: videos,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'videoUrls': videoUrls,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
