import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExerciseWeightEntry {
  final String weight;
  final String reps;
  final String plannedWeight;
  final DateTime date;
  final String routineId;
  final String routineName;

  const ExerciseWeightEntry({
    required this.weight,
    required this.reps,
    this.plannedWeight = '',
    required this.date,
    this.routineId = '',
    this.routineName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'reps': reps,
      'plannedWeight': plannedWeight,
      'date': Timestamp.fromDate(date),
      'routineId': routineId,
      'routineName': routineName,
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'weight': weight,
      'reps': reps,
      'plannedWeight': plannedWeight,
      'dateMs': date.millisecondsSinceEpoch,
      'routineId': routineId,
      'routineName': routineName,
    };
  }

  factory ExerciseWeightEntry.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['date'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (map['dateMs'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['dateMs'] as int);
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return ExerciseWeightEntry(
      weight: (map['weight'] ?? '').toString().trim(),
      reps: (map['reps'] ?? '').toString().trim(),
      plannedWeight: (map['plannedWeight'] ?? '').toString().trim(),
      date: parsedDate,
      routineId: (map['routineId'] ?? '').toString(),
      routineName: (map['routineName'] ?? '').toString(),
    );
  }
}

class ExerciseWeightRecord {
  final String workoutId;
  final String workoutName;
  final String lastWeight;
  final String lastReps;
  final DateTime updatedAt;
  final List<ExerciseWeightEntry> history;

  const ExerciseWeightRecord({
    required this.workoutId,
    required this.workoutName,
    required this.lastWeight,
    required this.lastReps,
    required this.updatedAt,
    required this.history,
  });

  Map<String, dynamic> toJsonMap() {
    return {
      'workoutId': workoutId,
      'workoutName': workoutName,
      'lastWeight': lastWeight,
      'lastReps': lastReps,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'history': history.map((e) => e.toJsonMap()).toList(),
    };
  }

  factory ExerciseWeightRecord.fromJsonMap(Map<String, dynamic> map) {
    final rawHistory = (map['history'] as List?) ?? [];
    final parsedHistory = rawHistory
        .whereType<Map>()
        .map((m) => ExerciseWeightEntry.fromMap(Map<String, dynamic>.from(m)))
        .where((e) => e.weight.isNotEmpty)
        .toList();
    parsedHistory.sort((a, b) => b.date.compareTo(a.date));

    return ExerciseWeightRecord(
      workoutId: (map['workoutId'] ?? '').toString(),
      workoutName: (map['workoutName'] ?? '').toString(),
      lastWeight: (map['lastWeight'] ?? '').toString().trim(),
      lastReps: (map['lastReps'] ?? '').toString().trim(),
      updatedAt: map['updatedAtMs'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAtMs'] as int)
          : DateTime.now(),
      history: parsedHistory,
    );
  }
}

class ExerciseWeightService {
  static String normalizeName(String? name) {
    if (name == null) return '';
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String docIdForExercise({String? workoutId, String? workoutName}) {
    final cleanId = (workoutId ?? '').trim();
    if (cleanId.isNotEmpty) {
      return 'id_${cleanId.replaceAll('/', '_')}';
    }
    final normName = normalizeName(workoutName)
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü_-]'), '_');
    return 'name_${normName.isEmpty ? 'unknown' : normName}';
  }

  static String _prefsKey(String uid) => 'user_exercise_weights_v1_$uid';

  /// Busca el registro de peso de un ejercicio por `workoutId` o por `workoutName`.
  static ExerciseWeightRecord? findRecord(
    Map<String, ExerciseWeightRecord> records, {
    String? workoutId,
    String? workoutName,
  }) {
    final cleanId = (workoutId ?? '').trim();
    if (cleanId.isNotEmpty) {
      final byId = records['id:$cleanId'];
      if (byId != null && byId.lastWeight.isNotEmpty) return byId;
    }
    final normName = normalizeName(workoutName);
    if (normName.isNotEmpty) {
      final byName = records['name:$normName'];
      if (byName != null && byName.lastWeight.isNotEmpty) return byName;
    }
    return null;
  }

  static void _indexRecord(
    Map<String, ExerciseWeightRecord> map,
    ExerciseWeightRecord record,
  ) {
    if (record.lastWeight.isEmpty) return;
    final cleanId = record.workoutId.trim();
    final normName = normalizeName(record.workoutName);

    if (cleanId.isNotEmpty) {
      final key = 'id:$cleanId';
      final existing = map[key];
      if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
        map[key] = _mergeRecords(existing, record);
      } else {
        map[key] = _mergeRecords(record, existing);
      }
    }
    if (normName.isNotEmpty) {
      final key = 'name:$normName';
      final existing = map[key];
      if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
        map[key] = _mergeRecords(existing, record);
      } else {
        map[key] = _mergeRecords(record, existing);
      }
    }
  }

  static ExerciseWeightRecord _mergeRecords(
    ExerciseWeightRecord? older,
    ExerciseWeightRecord newer,
  ) {
    if (older == null) return newer;
    final combined = <ExerciseWeightEntry>[...newer.history];
    for (final entry in older.history) {
      final isDuplicate = combined.any(
        (e) =>
            e.weight == entry.weight &&
            e.date.year == entry.date.year &&
            e.date.month == entry.date.month &&
            e.date.day == entry.date.day &&
            (e.routineId == entry.routineId ||
                e.routineId.isEmpty ||
                entry.routineId.isEmpty),
      );
      if (!isDuplicate) {
        combined.add(entry);
      }
    }
    combined.sort((a, b) => b.date.compareTo(a.date));
    final trimmed = combined.take(30).toList();

    return ExerciseWeightRecord(
      workoutId: newer.workoutId.isNotEmpty ? newer.workoutId : older.workoutId,
      workoutName:
          newer.workoutName.isNotEmpty ? newer.workoutName : older.workoutName,
      lastWeight:
          newer.lastWeight.isNotEmpty ? newer.lastWeight : older.lastWeight,
      lastReps: newer.lastReps.isNotEmpty ? newer.lastReps : older.lastReps,
      updatedAt: newer.updatedAt,
      history: trimmed,
    );
  }

  /// Carga el historial de pesos de un usuario combinando:
  /// 1) Subcolección `users/{uid}/exercise_weights`
  /// 2) Historial de `routine_logs` (para compatibilidad con entrenamientos previos)
  /// 3) Caché local en `SharedPreferences`
  static Future<Map<String, ExerciseWeightRecord>> loadUserExerciseWeights(
    String uid, {
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? preloadedLogs,
  }) async {
    final Map<String, ExerciseWeightRecord> records = {};

    // 1. Cargar caché local primero
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_prefsKey(uid));
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            final rec = ExerciseWeightRecord.fromJsonMap(
              Map<String, dynamic>.from(entry.value as Map),
            );
            _indexRecord(records, rec);
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading local exercise weights: $e');
    }

    // 2. Cargar desde `routine_logs` para reconstruir historial previo
    try {
      final logsDocs = preloadedLogs ??
          (await FirebaseFirestore.instance
                  .collection('routine_logs')
                  .where('userId', isEqualTo: uid)
                  .get())
              .docs;

      final Map<String, List<ExerciseWeightEntry>> historyByKey = {};
      final Map<String, String> nameByKey = {};
      final Map<String, String> idByKey = {};

      for (final doc in logsDocs) {
        final data = doc.data();
        final logDate =
            (data['date'] as Timestamp?)?.toDate() ??
            (data['completedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final routineId = (data['routineId'] ?? '').toString();
        final routineName = (data['routineName'] ?? 'Rutina').toString();
        final results = (data['results'] as List?) ?? [];

        for (final group in results) {
          if (group is! Map) continue;
          final exercises = (group['exercises'] as List?) ?? [];
          for (final ex in exercises) {
            if (ex is! Map) continue;
            final actualWeight = (ex['actualWeight'] ?? '').toString().trim();
            if (actualWeight.isEmpty) continue;

            final workoutId = (ex['workoutId'] ?? '').toString().trim();
            final workoutName =
                (ex['name'] ?? ex['workoutName'] ?? '').toString().trim();
            if (workoutId.isEmpty && workoutName.isEmpty) continue;

            final docKey = docIdForExercise(
              workoutId: workoutId,
              workoutName: workoutName,
            );
            idByKey[docKey] = workoutId;
            if (workoutName.isNotEmpty) nameByKey[docKey] = workoutName;

            historyByKey.putIfAbsent(docKey, () => []).add(
                  ExerciseWeightEntry(
                    weight: actualWeight,
                    reps: (ex['actualReps'] ?? ex['plannedReps'] ?? '')
                        .toString()
                        .trim(),
                    plannedWeight: (ex['plannedWeight'] ?? '').toString().trim(),
                    date: logDate,
                    routineId: routineId,
                    routineName: routineName,
                  ),
                );
          }
        }
      }

      for (final entry in historyByKey.entries) {
        final list = entry.value;
        if (list.isEmpty) continue;
        list.sort((a, b) => b.date.compareTo(a.date));
        final latest = list.first;
        final rec = ExerciseWeightRecord(
          workoutId: idByKey[entry.key] ?? '',
          workoutName: nameByKey[entry.key] ?? '',
          lastWeight: latest.weight,
          lastReps: latest.reps,
          updatedAt: latest.date,
          history: list.take(30).toList(),
        );
        _indexRecord(records, rec);
      }
    } catch (e) {
      debugPrint('Error loading exercise weights from routine_logs: $e');
    }

    // 3. Cargar desde subcolección `users/{uid}/exercise_weights`
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('exercise_weights')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final lastWeight = (data['lastWeight'] ?? '').toString().trim();
        if (lastWeight.isEmpty) continue;

        final updatedAt =
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final rawHistory = (data['history'] as List?) ?? [];
        final parsedHistory = rawHistory
            .whereType<Map>()
            .map((m) => ExerciseWeightEntry.fromMap(Map<String, dynamic>.from(m)))
            .where((e) => e.weight.isNotEmpty)
            .toList();
        parsedHistory.sort((a, b) => b.date.compareTo(a.date));

        final rec = ExerciseWeightRecord(
          workoutId: (data['workoutId'] ?? '').toString().trim(),
          workoutName: (data['workoutName'] ?? '').toString().trim(),
          lastWeight: lastWeight,
          lastReps: (data['lastReps'] ?? '').toString().trim(),
          updatedAt: updatedAt,
          history: parsedHistory.isNotEmpty
              ? parsedHistory
              : [
                  ExerciseWeightEntry(
                    weight: lastWeight,
                    reps: (data['lastReps'] ?? '').toString().trim(),
                    date: updatedAt,
                  ),
                ],
        );
        _indexRecord(records, rec);
      }
    } catch (e) {
      debugPrint('Error loading users/{uid}/exercise_weights: $e');
    }

    // Guardar caché local sincronizado
    await _saveToLocalPrefs(uid, records);

    return records;
  }

  static Future<void> _saveToLocalPrefs(
    String uid,
    Map<String, ExerciseWeightRecord> records,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializable = <String, dynamic>{};
      for (final entry in records.entries) {
        serializable[entry.key] = entry.value.toJsonMap();
      }
      await prefs.setString(_prefsKey(uid), jsonEncode(serializable));
    } catch (e) {
      debugPrint('Error saving local exercise weights: $e');
    }
  }

  /// Guarda el peso levantado de uno o varios ejercicios inmediatamente y actualiza su historial.
  static Future<Map<String, ExerciseWeightRecord>> saveExerciseWeights({
    required String uid,
    required String routineId,
    required String routineName,
    required List<Map<String, dynamic>> exercisesResults,
    required Map<String, ExerciseWeightRecord> currentRecords,
  }) async {
    final now = DateTime.now();
    final updatedRecords = Map<String, ExerciseWeightRecord>.from(currentRecords);

    for (final ex in exercisesResults) {
      final actualWeight = (ex['actualWeight'] ?? '').toString().trim();
      if (actualWeight.isEmpty) continue;

      final workoutId = (ex['workoutId'] ?? '').toString().trim();
      final workoutName =
          (ex['name'] ?? ex['workoutName'] ?? '').toString().trim();
      if (workoutId.isEmpty && workoutName.isEmpty) continue;

      final actualReps =
          (ex['actualReps'] ?? ex['plannedReps'] ?? '').toString().trim();
      final plannedWeight = (ex['plannedWeight'] ?? '').toString().trim();

      final existing = findRecord(
        updatedRecords,
        workoutId: workoutId,
        workoutName: workoutName,
      );

      final newEntry = ExerciseWeightEntry(
        weight: actualWeight,
        reps: actualReps,
        plannedWeight: plannedWeight,
        date: now,
        routineId: routineId,
        routineName: routineName,
      );

      final List<ExerciseWeightEntry> updatedHistory = [
        newEntry,
        if (existing != null)
          ...existing.history.where((h) {
            final sameDayAndRoutine =
                h.routineId == routineId &&
                h.date.year == now.year &&
                h.date.month == now.month &&
                h.date.day == now.day;
            return !sameDayAndRoutine;
          }),
      ].take(30).toList();

      final newRecord = ExerciseWeightRecord(
        workoutId: workoutId.isNotEmpty
            ? workoutId
            : (existing?.workoutId ?? ''),
        workoutName: workoutName.isNotEmpty
            ? workoutName
            : (existing?.workoutName ?? ''),
        lastWeight: actualWeight,
        lastReps: actualReps,
        updatedAt: now,
        history: updatedHistory,
      );

      _indexRecord(updatedRecords, newRecord);

      final docId = docIdForExercise(
        workoutId: newRecord.workoutId,
        workoutName: newRecord.workoutName,
      );

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('exercise_weights')
            .doc(docId)
            .set({
          'workoutId': newRecord.workoutId,
          'workoutName': newRecord.workoutName,
          'lastWeight': newRecord.lastWeight,
          'lastReps': newRecord.lastReps,
          'updatedAt': Timestamp.fromDate(now),
          'history': updatedHistory.map((e) => e.toMap()).toList(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving exercise weight to Firestore: $e');
      }
    }

    await _saveToLocalPrefs(uid, updatedRecords);
    return updatedRecords;
  }

  /// Retorna una copia profunda de `workouts` de una rutina aplicando el último peso
  /// levantado por el usuario en cada ejercicio (conservando `trainerWeight` original).
  static List<Map<String, dynamic>> applySavedWeightsToWorkouts(
    List<dynamic> rawWorkouts,
    Map<String, ExerciseWeightRecord> records,
  ) {
    final List<Map<String, dynamic>> result = [];

    for (final rawGroup in rawWorkouts) {
      if (rawGroup is! Map) continue;
      final group = Map<String, dynamic>.from(rawGroup);
      final rawExercises = (group['exercises'] as List?) ?? [group];
      final List<Map<String, dynamic>> updatedExercises = [];

      for (final rawEx in rawExercises) {
        if (rawEx is! Map) continue;
        final ex = Map<String, dynamic>.from(rawEx);
        final workoutId = (ex['workoutId'] ?? '').toString().trim();
        final workoutName =
            (ex['workoutName'] ?? ex['name'] ?? '').toString().trim();

        final originalWeight =
            (ex['trainerWeight'] ?? ex['weight'] ?? '').toString().trim();
        ex['trainerWeight'] = originalWeight;

        final record = findRecord(
          records,
          workoutId: workoutId,
          workoutName: workoutName,
        );

        if (record != null && record.lastWeight.isNotEmpty) {
          ex['weight'] = record.lastWeight;
          ex['lastLiftedWeight'] = record.lastWeight;
        }
        updatedExercises.add(ex);
      }

      group['exercises'] = updatedExercises;
      if (updatedExercises.isNotEmpty) {
        group['weight'] = updatedExercises.first['weight'];
        group['trainerWeight'] = updatedExercises.first['trainerWeight'];
      }
      result.add(group);
    }

    return result;
  }
}

