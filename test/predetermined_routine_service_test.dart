import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamanis_fit/models/predetermined_routine.dart';
import 'package:yamanis_fit/models/routine_request.dart';

void main() {
  group('PredeterminedRoutine Models Test', () {
    test('PredeterminedDayPlan serialization and deserialization', () {
      final dayPlan = PredeterminedDayPlan(
        dayNumber: 1,
        name: 'Día 1 - Tren Inferior & Glúteo',
        targetWeekday: 1,
        muscleFocus: ['Glúteo', 'Cuádriceps'],
        workouts: [
          {'name': 'Sentadilla búlgara', 'series': '4', 'reps': '12'},
          {'name': 'Hip Thrust', 'series': '4', 'reps': '10'},
        ],
        notes: 'Enfocarse en la pausa isométrica',
      );

      final map = dayPlan.toMap();
      expect(map['dayNumber'], 1);
      expect(map['name'], 'Día 1 - Tren Inferior & Glúteo');
      expect(map['targetWeekday'], 1);
      expect(map['muscleFocus'], ['Glúteo', 'Cuádriceps']);
      expect((map['workouts'] as List).length, 2);
      expect(map['notes'], 'Enfocarse en la pausa isométrica');

      final restored = PredeterminedDayPlan.fromMap(map);
      expect(restored.dayNumber, 1);
      expect(restored.name, 'Día 1 - Tren Inferior & Glúteo');
      expect(restored.targetWeekday, 1);
      expect(restored.muscleFocus, ['Glúteo', 'Cuádriceps']);
      expect(restored.workouts.length, 2);
      expect(restored.workouts.first['name'], 'Sentadilla búlgara');
      expect(restored.notes, 'Enfocarse en la pausa isométrica');
    });

    test('PredeterminedRoutine serialization and deserialization', () {
      final now = DateTime.now();
      final routine = PredeterminedRoutine(
        id: 'routine-123',
        name: 'Hipertrofia 4 Semanas',
        description: 'Programa enfocado en aumento de masa muscular.',
        durationWeeks: 4,
        level: 'Intermedio',
        intensity: 'Alta',
        muscleFocus: ['Fuerza', 'Hipertrofia'],
        days: [
          PredeterminedDayPlan(
            dayNumber: 1,
            name: 'Empuje',
            targetWeekday: 1,
            workouts: [
              {'name': 'Press banca', 'series': '4', 'reps': '10'},
            ],
          ),
          PredeterminedDayPlan(
            dayNumber: 2,
            name: 'Tracción',
            targetWeekday: 3,
            workouts: [
              {'name': 'Dominadas', 'series': '4', 'reps': '8'},
            ],
          ),
        ],
        isActive: true,
        createdAt: now,
      );

      final map = routine.toMap();
      expect(map['name'], 'Hipertrofia 4 Semanas');
      expect(map['durationWeeks'], 4);
      expect(map['level'], 'Intermedio');
      expect(map['intensity'], 'Alta');
      expect(map['muscleFocus'], ['Fuerza', 'Hipertrofia']);
      expect((map['days'] as List).length, 2);
      expect(map['isActive'], true);

      final restored = PredeterminedRoutine.fromMap(map, 'routine-123');
      expect(restored.id, 'routine-123');
      expect(restored.name, 'Hipertrofia 4 Semanas');
      expect(restored.durationWeeks, 4);
      expect(restored.level, 'Intermedio');
      expect(restored.intensity, 'Alta');
      expect(restored.muscleFocus, ['Fuerza', 'Hipertrofia']);
      expect(restored.days.length, 2);
      expect(restored.days.first.name, 'Empuje');
      expect(restored.days.last.name, 'Tracción');
      expect(restored.isActive, true);
      expect(restored.daysPerWeek, 2);
      expect(restored.totalWorkoutsCount, 2);
    });

    test('RoutineRequest serialization and deserialization', () {
      final now = DateTime.now();
      final request = RoutineRequest(
        id: 'req-456',
        userId: 'user-001',
        userEmail: 'client@yamanis.com',
        userName: 'Cliente Prueba',
        predeterminedRoutineId: 'routine-123',
        routineName: 'Hipertrofia 4 Semanas',
        status: 'pending',
        requestedAt: now,
      );

      final map = request.toMap();
      expect(map['userId'], 'user-001');
      expect(map['userEmail'], 'client@yamanis.com');
      expect(map['userName'], 'Cliente Prueba');
      expect(map['predeterminedRoutineId'], 'routine-123');
      expect(map['routineName'], 'Hipertrofia 4 Semanas');
      expect(map['status'], 'pending');

      final restored = RoutineRequest.fromMap(map, 'req-456');
      expect(restored.id, 'req-456');
      expect(restored.userId, 'user-001');
      expect(restored.userEmail, 'client@yamanis.com');
      expect(restored.userName, 'Cliente Prueba');
      expect(restored.predeterminedRoutineId, 'routine-123');
      expect(restored.routineName, 'Hipertrofia 4 Semanas');
      expect(restored.status, 'pending');
      expect(restored.isPending, true);
      expect(restored.isApproved, false);
      expect(restored.isRejected, false);
    });

    test('RoutineRequest handles nullable and fallback fields', () {
      final map = {
        'userId': 'user-002',
        'predeterminedRoutineId': 'routine-999',
        'routineName': 'Rutina Básica',
        'status': 'approved',
        'createdAt': Timestamp.now(),
      };

      final restored = RoutineRequest.fromMap(map, 'req-789');
      expect(restored.id, 'req-789');
      expect(restored.userEmail, '');
      expect(restored.userName, 'Usuario');
      expect(restored.status, 'approved');
      expect(restored.isApproved, true);
      expect(restored.isPending, false);
      expect(restored.resolvedAt, isNull);
      expect(restored.rejectionReason, isNull);
    });
  });
}
