import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamanis_fit/core/services/routine_plan_service.dart';

void main() {
  group('RoutinePlanService.evaluatePlanStatus', () {
    final DateTime planStart = DateTime(2026, 9, 1);
    const int durationWeeks = 4; // 28 days -> regular ends Sept 29, 23:59:59. Grace ends Oct 6, 23:59:59.

    final Map<String, dynamic> userData = {
      'role': 'user',
      'planStartDate': Timestamp.fromDate(planStart),
      'planDurationWeeks': durationWeeks,
    };

    final List<Map<String, dynamic>> testRoutines = [
      {
        'id': 'routine_1',
        'name': 'Día 1',
        'date': Timestamp.fromDate(DateTime(2026, 9, 2)),
      },
      {
        'id': 'routine_2',
        'name': 'Día 2',
        'date': Timestamp.fromDate(DateTime(2026, 9, 4)),
      },
      {
        'id': 'routine_3',
        'name': 'Día 3',
        'date': Timestamp.fromDate(DateTime(2026, 9, 25)),
      },
    ];

    test('Dentro del tiempo regular: no bloqueado, no en gracia', () {
      final now = DateTime(2026, 9, 15);
      final status = RoutinePlanService.evaluatePlanStatus(
        userData: userData,
        allRoutines: testRoutines,
        completedRoutineIds: {'routine_1'},
        nowOverride: now,
      );

      expect(status.isPastRegularPlan, isFalse);
      expect(status.isInGracePeriod, isFalse);
      expect(status.isBlocked, isFalse);
      expect(status.areAllExercisesCompleted, isFalse);
      expect(status.completedRoutines, equals(1));
      expect(status.totalRoutines, equals(3));
    });

    test('Dentro del tiempo regular: todos los ejercicios completados', () {
      final now = DateTime(2026, 9, 20);
      final status = RoutinePlanService.evaluatePlanStatus(
        userData: userData,
        allRoutines: testRoutines,
        completedRoutineIds: {'routine_1', 'routine_2', 'routine_3'},
        nowOverride: now,
      );

      expect(status.areAllExercisesCompleted, isTrue);
      expect(status.isInGracePeriod, isFalse);
      expect(status.isBlocked, isFalse);
    });

    test('Pasaron las semanas del plan y NO completó todo: Semana adicional de gracia activa', () {
      // Regular end is Sept 29 23:59:59. Test on Oct 2 (3 days into grace week)
      final now = DateTime(2026, 10, 2);
      final status = RoutinePlanService.evaluatePlanStatus(
        userData: userData,
        allRoutines: testRoutines,
        completedRoutineIds: {'routine_1', 'routine_2'},
        nowOverride: now,
      );

      expect(status.isPastRegularPlan, isTrue);
      expect(status.isInGracePeriod, isTrue);
      expect(status.isBlocked, isFalse);
      expect(status.areAllExercisesCompleted, isFalse);
      expect(status.daysLeftInGracePeriod, inInclusiveRange(1, 5));
    });

    test('Pasaron las semanas del plan y la semana adicional venció: Ejercicios BLOQUEADOS', () {
      // Grace period ends Oct 6 23:59:59. Test on Oct 8 (after grace week)
      final now = DateTime(2026, 10, 8);
      final status = RoutinePlanService.evaluatePlanStatus(
        userData: userData,
        allRoutines: testRoutines,
        completedRoutineIds: {'routine_1', 'routine_2'},
        nowOverride: now,
      );

      expect(status.isPastRegularPlan, isTrue);
      expect(status.isInGracePeriod, isFalse);
      expect(status.isBlocked, isTrue);
      expect(status.areAllExercisesCompleted, isFalse);
    });

    test('Completó todos los ejercicios durante la semana de gracia: No bloqueado y marcado como completado', () {
      final now = DateTime(2026, 10, 3);
      final status = RoutinePlanService.evaluatePlanStatus(
        userData: userData,
        allRoutines: testRoutines,
        completedRoutineIds: {'routine_1', 'routine_2', 'routine_3'},
        nowOverride: now,
      );

      expect(status.areAllExercisesCompleted, isTrue);
      expect(status.isInGracePeriod, isFalse);
      expect(status.isBlocked, isFalse);
    });
  });
}
