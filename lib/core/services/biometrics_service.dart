import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:yamanis_fit/models/user_data_sheet.dart';

class BiometricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Guarda la planilla de datos completa y calcula diferenciales con mediciones previas
  static Future<void> saveDataSheet(String userId, UserDataSheet sheet) async {
    try {
      // 1. Obtener datos biométricos anteriores si existen para calcular deltas
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final existingData = userDoc.data();
      final oldBiometricsMap = existingData?['biometrics'] as Map<String, dynamic>?;
      final oldBiometrics = UserBiometrics.fromMap(oldBiometricsMap);

      final newB = sheet.biometrics;
      final deltas = <String, double>{};

      if (oldBiometrics.chest != null && newB.chest != null) {
        deltas['chest'] = double.parse((newB.chest! - oldBiometrics.chest!).toStringAsFixed(1));
      }
      if (oldBiometrics.waist != null && newB.waist != null) {
        deltas['waist'] = double.parse((newB.waist! - oldBiometrics.waist!).toStringAsFixed(1));
      }
      if (oldBiometrics.biceps != null && newB.biceps != null) {
        deltas['biceps'] = double.parse((newB.biceps! - oldBiometrics.biceps!).toStringAsFixed(1));
      }
      if (oldBiometrics.thigh != null && newB.thigh != null) {
        deltas['thigh'] = double.parse((newB.thigh! - oldBiometrics.thigh!).toStringAsFixed(1));
      }
      if (oldBiometrics.calves != null && newB.calves != null) {
        deltas['calves'] = double.parse((newB.calves! - oldBiometrics.calves!).toStringAsFixed(1));
      }
      if (oldBiometrics.hips != null && newB.hips != null) {
        deltas['hips'] = double.parse((newB.hips! - oldBiometrics.hips!).toStringAsFixed(1));
      }
      if (oldBiometrics.neck != null && newB.neck != null) {
        deltas['neck'] = double.parse((newB.neck! - oldBiometrics.neck!).toStringAsFixed(1));
      }

      final updatedBiometrics = UserBiometrics(
        weight: newB.weight ?? oldBiometrics.weight,
        previousWeight: oldBiometrics.weight ?? newB.weight,
        height: newB.height ?? oldBiometrics.height,
        age: newB.age ?? oldBiometrics.age,
        neck: newB.neck ?? oldBiometrics.neck,
        chest: newB.chest ?? oldBiometrics.chest,
        waist: newB.waist ?? oldBiometrics.waist,
        hips: newB.hips ?? oldBiometrics.hips,
        biceps: newB.biceps ?? oldBiometrics.biceps,
        thigh: newB.thigh ?? oldBiometrics.thigh,
        calves: newB.calves ?? oldBiometrics.calves,
        updatedAt: DateTime.now(),
        previousDeltas: deltas.isNotEmpty ? deltas : (oldBiometrics.previousDeltas ?? {}),
      );

      final updatedSheet = UserDataSheet(
        userId: userId,
        fullName: sheet.fullName,
        email: sheet.email,
        biometrics: updatedBiometrics,
        assessment: sheet.assessment,
        isComplete: true,
        updatedAt: DateTime.now(),
      );

      // 2. Guardar en el documento de usuario
      await _firestore.collection('users').doc(userId).set({
        'hasCompletedDataSheet': true,
        'hasCompletedBiometrics': true,
        'biometrics': updatedBiometrics.toMap(),
        'dataSheet': updatedSheet.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Guardar en el historial para auditoría y seguimiento
      try {
        await _firestore.collection('users').doc(userId).collection('biometric_history').add({
          'weight': newB.weight,
          'height': newB.height,
          'neck': newB.neck,
          'chest': newB.chest,
          'waist': newB.waist,
          'hips': newB.hips,
          'biceps': newB.biceps,
          'thigh': newB.thigh,
          'calves': newB.calves,
          'deltas': deltas,
          'recordedAt': FieldValue.serverTimestamp(),
        });
      } catch (histError) {
        debugPrint('[BiometricsService] Aviso: Historial biométrico no se pudo registrar en subcolección: $histError');
      }
    } catch (e) {
      debugPrint('[BiometricsService] Error al guardar planilla: $e');
      rethrow;
    }
  }

  /// Obtiene la planilla de datos de un usuario
  static Future<UserDataSheet?> getDataSheet(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      if (data['dataSheet'] is Map) {
        return UserDataSheet.fromMap(Map<String, dynamic>.from(data['dataSheet']), userId);
      } else if (data['biometrics'] is Map) {
        final biometrics = UserBiometrics.fromMap(Map<String, dynamic>.from(data['biometrics']));
        return UserDataSheet(
          userId: userId,
          fullName: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          email: data['email'] ?? '',
          biometrics: biometrics,
          assessment: const HealthLifestyleAssessment(),
          isComplete: data['hasCompletedDataSheet'] == true || data['hasCompletedBiometrics'] == true,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[BiometricsService] Error al obtener planilla: $e');
      return null;
    }
  }

  /// Verifica si el usuario ya completó su planilla/medidas iniciales o si ya inició
  /// un plan previamente (las medidas solo son obligatorias al iniciar el primer plan).
  static Future<bool> hasCompletedDataSheet(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      // 1. Si ya tiene marcado que completó la planilla o biometría inicial alguna vez
      if (data['hasCompletedDataSheet'] == true || data['hasCompletedBiometrics'] == true) {
        return true;
      }

      // 2. Si dataSheet está estructurado en el documento de usuario
      if (data['dataSheet'] is Map) {
        final dsMap = Map<String, dynamic>.from(data['dataSheet']);
        final ds = UserDataSheet.fromMap(dsMap, userId);
        if (ds.isComplete || ds.biometrics.isComplete) {
          return true;
        }
      }

      // 3. Si tiene medidas registradas en 'biometrics'
      if (data['biometrics'] is Map) {
        final b = UserBiometrics.fromMap(Map<String, dynamic>.from(data['biometrics']));
        if (b.isComplete || (b.weight != null && b.height != null)) {
          return true;
        }
      }

      // 4. Si el usuario ya inició un plan anteriormente (tiene sesiones completadas en routine_logs),
      // ya no está en su primer plan por primera vez, por lo que las medidas son opcionales.
      final logsSnap = await _firestore
          .collection('routine_logs')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (logsSnap.docs.isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[BiometricsService] Error al verificar estado de planilla: $e');
      return false;
    }
  }

  /// Registra un nuevo peso rápidamente desde la tarjeta de PESO ACTUAL
  static Future<void> quickLogWeight(String userId, double newWeight) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final existingData = userDoc.data();
      final oldBiometricsMap = existingData?['biometrics'] as Map<String, dynamic>?;
      final oldBiometrics = UserBiometrics.fromMap(oldBiometricsMap);

      final currentOldWeight = oldBiometrics.weight ?? newWeight;

      final updatedBiometrics = UserBiometrics(
        weight: newWeight,
        previousWeight: currentOldWeight,
        height: oldBiometrics.height,
        age: oldBiometrics.age,
        neck: oldBiometrics.neck,
        chest: oldBiometrics.chest,
        waist: oldBiometrics.waist,
        hips: oldBiometrics.hips,
        biceps: oldBiometrics.biceps,
        thigh: oldBiometrics.thigh,
        calves: oldBiometrics.calves,
        updatedAt: DateTime.now(),
        previousDeltas: oldBiometrics.previousDeltas,
      );

      await _firestore.collection('users').doc(userId).set({
        'biometrics': updatedBiometrics.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await _firestore.collection('users').doc(userId).collection('biometric_history').add({
          'weight': newWeight,
          'previousWeight': currentOldWeight,
          'weightDelta': double.parse((newWeight - currentOldWeight).toStringAsFixed(2)),
          'recordedAt': FieldValue.serverTimestamp(),
          'type': 'quick_weight',
        });
      } catch (histError) {
        debugPrint('[BiometricsService] Aviso: Historial biométrico no se pudo registrar: $histError');
      }
    } catch (e) {
      debugPrint('[BiometricsService] Error al registrar peso: $e');
      rethrow;
    }
  }
}
