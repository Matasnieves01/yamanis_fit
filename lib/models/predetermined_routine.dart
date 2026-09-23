import 'package:cloud_firestore/cloud_firestore.dart';

class PredeterminedDayPlan {
  final int dayNumber; // 1, 2, 3...
  final String name; // ej. "Día 1 - Tren Inferior & Glúteo"
  final int targetWeekday; // 1 (Lunes), 2 (Martes), ... 7 (Domingo)
  final List<String> muscleFocus;
  final String intensity;
  final String level;
  final List<Map<String, dynamic>> workouts;
  final String nutritionPlanUrl;
  final String notes;

  PredeterminedDayPlan({
    required this.dayNumber,
    required this.name,
    this.targetWeekday = 1,
    this.muscleFocus = const [],
    this.intensity = 'Alta',
    this.level = 'Intermedio',
    this.workouts = const [],
    this.nutritionPlanUrl = '',
    this.notes = '',
  });

  factory PredeterminedDayPlan.fromMap(Map<String, dynamic> map) {
    return PredeterminedDayPlan(
      dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 1,
      name: map['name'] ?? 'Día de entrenamiento',
      targetWeekday: (map['targetWeekday'] as num?)?.toInt() ?? 1,
      muscleFocus: List<String>.from(map['muscleFocus'] ?? []),
      intensity: map['intensity'] ?? 'Alta',
      level: map['level'] ?? 'Intermedio',
      workouts: List<Map<String, dynamic>>.from(map['workouts'] ?? []),
      nutritionPlanUrl: map['nutritionPlanUrl'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'name': name,
      'targetWeekday': targetWeekday,
      'muscleFocus': muscleFocus,
      'intensity': intensity,
      'level': level,
      'workouts': workouts,
      'nutritionPlanUrl': nutritionPlanUrl,
      'notes': notes,
    };
  }
}

class PredeterminedRoutine {
  final String id;
  final String name;
  final String description;
  final String coverImageUrl;
  final String promoTag;
  final String level; // Principiante, Intermedio, Avanzado
  final String intensity; // Baja, Media, Alta
  final List<String> muscleFocus;
  final int durationWeeks; // ej. 4 semanas
  final List<PredeterminedDayPlan> days;
  final bool isActive;
  final double price;
  final bool isFree;
  final DateTime createdAt;

  PredeterminedRoutine({
    required this.id,
    required this.name,
    required this.description,
    this.coverImageUrl = '',
    this.promoTag = '',
    this.level = 'Intermedio',
    this.intensity = 'Media',
    this.muscleFocus = const [],
    this.durationWeeks = 4,
    this.days = const [],
    this.isActive = true,
    this.price = 0.0,
    this.isFree = true,
    required this.createdAt,
  });

  int get daysPerWeek => days.length;

  int get totalWorkoutsCount {
    int count = 0;
    for (final day in days) {
      count += day.workouts.length;
    }
    return count;
  }

  factory PredeterminedRoutine.fromMap(Map<String, dynamic> data, String id) {
    final rawDays = data['days'] as List? ?? [];
    final parsedDays = rawDays
        .whereType<Map<String, dynamic>>()
        .map((m) => PredeterminedDayPlan.fromMap(m))
        .toList();

    final priceVal = (data['price'] as num?)?.toDouble() ?? 0.0;
    final isFreeVal = data['isFree'] as bool? ?? (priceVal <= 0.0);

    return PredeterminedRoutine(
      id: id,
      name: data['name'] ?? 'Programa sin título',
      description: data['description'] ?? '',
      coverImageUrl: data['coverImageUrl'] ?? '',
      promoTag: data['promoTag'] ?? '',
      level: data['level'] ?? 'Intermedio',
      intensity: data['intensity'] ?? 'Media',
      muscleFocus: List<String>.from(data['muscleFocus'] ?? []),
      durationWeeks: (data['durationWeeks'] as num?)?.toInt() ?? 4,
      days: parsedDays,
      isActive: data['isActive'] ?? true,
      price: priceVal,
      isFree: isFreeVal,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime)
              ? data['createdAt'] as DateTime
              : DateTime.now(),
    );
  }

  factory PredeterminedRoutine.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PredeterminedRoutine.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'promoTag': promoTag,
      'level': level,
      'intensity': intensity,
      'muscleFocus': muscleFocus,
      'durationWeeks': durationWeeks,
      'days': days.map((d) => d.toMap()).toList(),
      'isActive': isActive,
      'price': price,
      'isFree': isFree,
      'createdAt': createdAt,
    };
  }
}
