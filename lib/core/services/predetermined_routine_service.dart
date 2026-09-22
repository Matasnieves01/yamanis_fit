import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';
import 'package:yamanis_fit/models/predetermined_routine.dart';
import 'package:yamanis_fit/models/routine_request.dart';

class PredeterminedRoutineService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene la fecha de inicio del día de hoy a las 00:00:00 local
  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Verifica de forma estricta si un usuario ya tiene una rutina activa asignada en su calendario.
  static Future<bool> userHasActiveRoutine(String userId) async {
    final startOfToday = _startOfToday();

    try {
      // 1. Obtener todas las rutinas del usuario con fecha >= hoy
      final querySnapshot = await _firestore
          .collection('routines')
          .where('clientId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      // 2. Obtener IDs de las rutinas que el usuario ya completó
      final logsSnapshot = await _firestore
          .collection('routine_logs')
          .where('userId', isEqualTo: userId)
          .get();

      final completedRoutineIds = logsSnapshot.docs
          .map((doc) => doc.data()['routineId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();

      // 3. Si hay al menos una rutina futura o de hoy que NO esté completada, tiene rutina activa
      for (final doc in querySnapshot.docs) {
        final routineId = doc.id;
        if (!completedRoutineIds.contains(routineId)) {
          return true; // Encontró una rutina pendiente/activa
        }
      }

      return false; // Todas las rutinas encontradas ya fueron completadas
    } catch (e) {
      debugPrint('[PredeterminedRoutineService] Error checking active routine: $e');
      // En caso de error de red o índice, asumimos false para no bloquear injustamente al usuario
      return false;
    }
  }

  /// Conteo de rutinas activas pendientes para un usuario
  static Future<int> getActiveRoutinesCount(String userId) async {
    try {
      final startToday = _startOfToday();
      final snapshot = await _firestore
          .collection('routines')
          .where('clientId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startToday))
          .get();
      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Verifica si el usuario tiene una solicitud pendiente
  static Future<RoutineRequest?> getPendingRequestForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('routine_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return RoutineRequest.fromMap(doc.data(), doc.id);
    } catch (e) {
      debugPrint('[PredeterminedRoutineService] Error checking pending request: $e');
      return null;
    }
  }

  /// Solicitar la asignación de una rutina predeterminada.
  /// REGLA ESTRICTA: Solo puede solicitar si:
  /// 1. NO tiene una rutina activa en su calendario.
  /// 2. Ha completado su Planilla de Datos obligatoria (medidas y encuesta).
  /// 3. NO tiene ya una solicitud pendiente.
  static Future<void> requestRoutine({
    required String userId,
    required String userEmail,
    required String userName,
    required PredeterminedRoutine routine,
  }) async {
    // 1. Validar si ya tiene una rutina activa asignada
    final hasActive = await userHasActiveRoutine(userId);
    if (hasActive) {
      throw Exception(
        'Ya cuentas con una rutina activa en tu calendario. Complétala antes de solicitar una nueva.',
      );
    }

    // 2. Validar si el usuario ha completado obligatoriamente su planilla de datos
    final hasCompletedSheet = await BiometricsService.hasCompletedDataSheet(userId);
    if (!hasCompletedSheet) {
      throw Exception(
        'Es obligatorio completar la Planilla de Datos (medidas y antecedentes de salud) antes de solicitar un plan de entrenamiento.',
      );
    }

    // 3. Validar si ya tiene una solicitud pendiente
    final pending = await getPendingRequestForUser(userId);
    if (pending != null) {
      throw Exception(
        'Ya tienes una solicitud pendiente para "${pending.routineName}". Espera a que sea procesada.',
      );
    }

    final docId = '${userId}_${routine.id}';

    // 4. Crear el documento de solicitud
    await _firestore.collection('routine_requests').doc(docId).set({
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'predeterminedRoutineId': routine.id,
      'routineName': routine.name,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    // 5. Notificar a la entrenadora (admin)
    await _firestore.collection('notifications').add({
      'title': '📋 Nueva Solicitud de Rutina',
      'message': '$userName ($userEmail) solicita el programa: ${routine.name}',
      'type': 'routine_request',
      'targetRole': 'admin',
      'userId': userId,
      'resourceId': routine.id,
      'requestId': docId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// La entrenadora aprueba y asigna la rutina al usuario.
  /// REGLAS ESTRICTAS:
  /// - Solo se puede aprobar y asignar si el usuario tiene su planilla de medidas y salud completada.
  /// - Solo se puede aprobar y asignar si el usuario NO tiene una rutina ya asignada.
  static Future<int> approveAndAssignRoutine({
    required String requestId,
    required PredeterminedRoutine routine,
    required String targetUserId,
    String? targetUserName,
    DateTime? startDate,
  }) async {
    // 1. REGLA ESTRICTA: Validar que el usuario tenga completada su planilla de medidas y salud
    final hasCompletedDataSheet = await BiometricsService.hasCompletedDataSheet(targetUserId);
    if (!hasCompletedDataSheet) {
      throw Exception(
        'No se puede asignar: El usuario aún no ha completado su planilla de medidas corporales y antecedentes de salud obligatorios.',
      );
    }

    // 2. REGLA ESTRICTA: Verificar que el usuario NO tenga una rutina activa
    final hasActive = await userHasActiveRoutine(targetUserId);
    if (hasActive) {
      throw Exception(
        'No se puede asignar: El usuario ya tiene una rutina activa asignada en su calendario.',
      );
    }

    // 3. Determinar fecha de inicio (por defecto hoy o próximo lunes si es fin de semana)
    final baseDate = startDate ?? DateTime.now();
    final cleanStart = DateTime(baseDate.year, baseDate.month, baseDate.day);

    // 3. Generar las sesiones de entrenamiento semana a semana
    final batch = _firestore.batch();
    final routinesCollection = _firestore.collection('routines');
    int totalSessions = 0;

    for (int week = 0; week < routine.durationWeeks; week++) {
      for (final dayPlan in routine.days) {
        // Calcular el día de la semana correspondiente
        // targetWeekday va de 1 (Lunes) a 7 (Domingo)
        int dayDiff = (dayPlan.targetWeekday - cleanStart.weekday);
        if (dayDiff < 0) {
          dayDiff += 7; // Mover al día correspondiente de la semana
        }

        final sessionDate = cleanStart.add(Duration(days: (week * 7) + dayDiff));
        // Guardar a las 12:00:00 UTC para consistencia con el calendario existente
        final storageDate = DateTime.utc(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          12,
          0,
          0,
        );

        // Dar formato estándar a los ejercicios para máxima compatibilidad con el reproductor nativo
        final formattedWorkouts = dayPlan.workouts.map((w) {
          final workoutId = (w['workoutId'] ?? '').toString();
          final workoutName = (w['workoutName'] ?? '').toString();
          final sets = (w['sets'] ?? '4').toString();
          final reps = (w['reps'] ?? '12').toString();
          final weight = (w['weight'] ?? '').toString();
          final description = (w['description'] ?? w['notes'] ?? '').toString();

          final List rawExercises = (w['exercises'] is List) ? (w['exercises'] as List) : [];
          final exercisesList = rawExercises.isNotEmpty
              ? rawExercises
              : [
                  {
                    'workoutId': workoutId,
                    'workoutName': workoutName,
                    'reps': reps,
                    'weight': weight,
                    if (description.isNotEmpty) 'description': description,
                  }
                ];

          return {
            'workoutId': workoutId,
            'workoutName': workoutName,
            'sets': sets,
            'reps': reps,
            'weight': weight,
            if (description.isNotEmpty) 'description': description,
            'exercises': exercisesList,
          };
        }).toList();

        final newRoutineRef = routinesCollection.doc();
        batch.set(newRoutineRef, {
          'name': '${routine.name} - ${dayPlan.name}',
          'workouts': formattedWorkouts,
          'muscleFocus': dayPlan.muscleFocus.isNotEmpty ? dayPlan.muscleFocus : routine.muscleFocus,
          'intensity': routine.intensity,
          'level': routine.level,
          'notes': dayPlan.notes,
          'clientId': targetUserId,
          'date': Timestamp.fromDate(storageDate),
          'predeterminedRoutineId': routine.id,
          'weekNumber': week + 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
        totalSessions++;
      }
    }

    // 4. Actualizar estado de la solicitud a aprobada
    final requestRef = _firestore.collection('routine_requests').doc(requestId);
    batch.update(requestRef, {
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'assignedSessionsCount': totalSessions,
    });

    // 5. Notificar al cliente
    final userNotifRef = _firestore.collection('notifications').doc();
    batch.set(userNotifRef, {
      'title': '🏋️ ¡Tu programa ha sido aprobado!',
      'message': 'La entrenadora ha asignado "${routine.name}" a tu calendario ($totalSessions sesiones). ¡Ve a tu Inicio para comenzar!',
      'type': 'routine_approved',
      'targetRole': 'user',
      'userId': targetUserId,
      'resourceId': routine.id,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Ejecutar todas las escrituras en batch
    await batch.commit();

    return totalSessions;
  }

  /// La entrenadora rechaza una solicitud de rutina
  static Future<void> rejectRoutineRequest({
    required String requestId,
    required String targetUserId,
    required String routineName,
    String? reason,
  }) async {
    await _firestore.collection('routine_requests').doc(requestId).update({
      'status': 'rejected',
      'resolvedAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
    });

    // Notificar al cliente
    await _firestore.collection('notifications').add({
      'title': 'Solicitud de rutina no aprobada',
      'message': reason != null && reason.isNotEmpty
          ? 'Tu solicitud para "$routineName" fue rechazada: $reason'
          : 'Tu solicitud para "$routineName" fue rechazada. Contacta a tu entrenadora para más detalles.',
      'type': 'routine_rejected',
      'targetRole': 'user',
      'userId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}
