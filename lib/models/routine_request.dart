import 'package:cloud_firestore/cloud_firestore.dart';

class RoutineRequest {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String predeterminedRoutineId;
  final String routineName;
  final String status; // 'pending', 'approved', 'rejected'
  final double price;
  final bool isFree;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? rejectionReason;

  RoutineRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.predeterminedRoutineId,
    required this.routineName,
    this.status = 'pending',
    this.price = 0.0,
    this.isFree = true,
    required this.requestedAt,
    this.resolvedAt,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory RoutineRequest.fromMap(Map<String, dynamic> data, String id) {
    final priceVal = (data['price'] as num?)?.toDouble() ?? 0.0;
    final isFreeVal = data['isFree'] as bool? ?? (priceVal <= 0.0);

    return RoutineRequest(
      id: id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? 'Usuario',
      predeterminedRoutineId: data['predeterminedRoutineId'] ?? data['routineId'] ?? '',
      routineName: data['routineName'] ?? 'Rutina predeterminada',
      status: (data['status'] ?? 'pending').toString().toLowerCase().trim(),
      price: priceVal,
      isFree: isFreeVal,
      requestedAt: (data['requestedAt'] is Timestamp)
          ? (data['requestedAt'] as Timestamp).toDate()
          : (data['requestedAt'] is DateTime)
              ? data['requestedAt'] as DateTime
              : DateTime.now(),
      resolvedAt: (data['resolvedAt'] is Timestamp)
          ? (data['resolvedAt'] as Timestamp).toDate()
          : (data['resolvedAt'] is DateTime)
              ? data['resolvedAt'] as DateTime
              : null,
      rejectionReason: data['rejectionReason'],
    );
  }

  factory RoutineRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RoutineRequest.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'predeterminedRoutineId': predeterminedRoutineId,
      'routineName': routineName,
      'status': status,
      'price': price,
      'isFree': isFree,
      'requestedAt': requestedAt,
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }
}
