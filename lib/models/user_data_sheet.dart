import 'package:cloud_firestore/cloud_firestore.dart';

class UserBiometrics {
  final double? weight; // kg
  final double? previousWeight; // kg
  final double? height; // cm
  final int? age;
  final double? neck; // cm
  final double? chest; // cm
  final double? waist; // cm
  final double? hips; // cm
  final double? biceps; // cm
  final double? thigh; // cm
  final double? calves; // cm
  final DateTime? updatedAt;
  final Map<String, double>? previousDeltas;

  const UserBiometrics({
    this.weight,
    this.previousWeight,
    this.height,
    this.age,
    this.neck,
    this.chest,
    this.waist,
    this.hips,
    this.biceps,
    this.thigh,
    this.calves,
    this.updatedAt,
    this.previousDeltas,
  });

  double? get weightDelta {
    if (weight == null || previousWeight == null) return null;
    return weight! - previousWeight!;
  }

  bool get isComplete {
    return weight != null &&
        height != null &&
        age != null &&
        waist != null &&
        biceps != null &&
        thigh != null;
  }

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'previousWeight': previousWeight,
      'height': height,
      'age': age,
      'neck': neck,
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'biceps': biceps,
      'thigh': thigh,
      'calves': calves,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'previousDeltas': previousDeltas,
    };
  }

  factory UserBiometrics.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserBiometrics();

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    Map<String, double>? parseDeltas(dynamic v) {
      if (v is Map) {
        return v.map((key, value) => MapEntry(key.toString(), parseDouble(value) ?? 0.0));
      }
      return null;
    }

    return UserBiometrics(
      weight: parseDouble(map['weight']),
      previousWeight: parseDouble(map['previousWeight']),
      height: parseDouble(map['height']),
      age: parseInt(map['age']),
      neck: parseDouble(map['neck']),
      chest: parseDouble(map['chest']),
      waist: parseDouble(map['waist']),
      hips: parseDouble(map['hips']),
      biceps: parseDouble(map['biceps']),
      thigh: parseDouble(map['thigh']),
      calves: parseDouble(map['calves']),
      updatedAt: parseDate(map['updatedAt']),
      previousDeltas: parseDeltas(map['previousDeltas']),
    );
  }
}

class HealthLifestyleAssessment {
  final String healthConditions;
  final String surgicalHistory;
  final String injuries;
  final String medications;
  final String physicalActivityLevel;
  final String sleepHours;
  final String dietDescription;
  final String trainingExperience;
  final String trainingLocation;
  final String trainingDaysPerWeek;
  final String trainingGoals;
  final String motivation;
  final String extraComments;

  const HealthLifestyleAssessment({
    this.healthConditions = '',
    this.surgicalHistory = '',
    this.injuries = '',
    this.medications = '',
    this.physicalActivityLevel = '',
    this.sleepHours = '',
    this.dietDescription = '',
    this.trainingExperience = '',
    this.trainingLocation = '',
    this.trainingDaysPerWeek = '',
    this.trainingGoals = '',
    this.motivation = '',
    this.extraComments = '',
  });

  bool get isComplete {
    return healthConditions.trim().isNotEmpty &&
        surgicalHistory.trim().isNotEmpty &&
        injuries.trim().isNotEmpty &&
        medications.trim().isNotEmpty &&
        physicalActivityLevel.trim().isNotEmpty &&
        sleepHours.trim().isNotEmpty &&
        dietDescription.trim().isNotEmpty &&
        trainingExperience.trim().isNotEmpty &&
        trainingLocation.trim().isNotEmpty &&
        trainingDaysPerWeek.trim().isNotEmpty &&
        trainingGoals.trim().isNotEmpty &&
        motivation.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'healthConditions': healthConditions,
      'surgicalHistory': surgicalHistory,
      'injuries': injuries,
      'medications': medications,
      'physicalActivityLevel': physicalActivityLevel,
      'sleepHours': sleepHours,
      'dietDescription': dietDescription,
      'trainingExperience': trainingExperience,
      'trainingLocation': trainingLocation,
      'trainingDaysPerWeek': trainingDaysPerWeek,
      'trainingGoals': trainingGoals,
      'motivation': motivation,
      'extraComments': extraComments,
    };
  }

  factory HealthLifestyleAssessment.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const HealthLifestyleAssessment();
    return HealthLifestyleAssessment(
      healthConditions: map['healthConditions']?.toString() ?? '',
      surgicalHistory: map['surgicalHistory']?.toString() ?? '',
      injuries: map['injuries']?.toString() ?? '',
      medications: map['medications']?.toString() ?? '',
      physicalActivityLevel: map['physicalActivityLevel']?.toString() ?? '',
      sleepHours: map['sleepHours']?.toString() ?? '',
      dietDescription: map['dietDescription']?.toString() ?? '',
      trainingExperience: map['trainingExperience']?.toString() ?? '',
      trainingLocation: map['trainingLocation']?.toString() ?? '',
      trainingDaysPerWeek: map['trainingDaysPerWeek']?.toString() ?? '',
      trainingGoals: map['trainingGoals']?.toString() ?? '',
      motivation: map['motivation']?.toString() ?? '',
      extraComments: map['extraComments']?.toString() ?? '',
    );
  }
}

class UserDataSheet {
  final String userId;
  final String fullName;
  final String email;
  final UserBiometrics biometrics;
  final HealthLifestyleAssessment assessment;
  final bool isComplete;
  final DateTime? updatedAt;

  const UserDataSheet({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.biometrics,
    required this.assessment,
    required this.isComplete,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'biometrics': biometrics.toMap(),
      'assessment': assessment.toMap(),
      'isComplete': isComplete,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory UserDataSheet.fromMap(Map<String, dynamic> map, String userId) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final biometrics = UserBiometrics.fromMap(map['biometrics'] as Map<String, dynamic>?);
    final assessment = HealthLifestyleAssessment.fromMap(map['assessment'] as Map<String, dynamic>?);

    final isComplete = map['isComplete'] == true || (biometrics.isComplete && assessment.isComplete);

    return UserDataSheet(
      userId: userId,
      fullName: map['fullName']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      biometrics: biometrics,
      assessment: assessment,
      isComplete: isComplete,
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
