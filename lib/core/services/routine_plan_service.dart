import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoutinePlanModel {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int durationWeeks;
  final List<Map<String, dynamic>> routines;
  final bool isCurrent;

  RoutinePlanModel({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.durationWeeks,
    required this.routines,
    required this.isCurrent,
  });
}

class RoutinePlanStatus {
  final RoutinePlanModel? currentPlan;
  final DateTime? startDate;
  final DateTime? regularEndDate;
  final DateTime? gracePeriodEndDate;
  final int planWeeks;
  final int totalRoutines;
  final int completedRoutines;
  final bool areAllExercisesCompleted;
  final bool isPastRegularPlan;
  final bool isInGracePeriod;
  final bool isBlocked;
  final int daysLeftInGracePeriod;

  const RoutinePlanStatus({
    this.currentPlan,
    this.startDate,
    this.regularEndDate,
    this.gracePeriodEndDate,
    this.planWeeks = 4,
    this.totalRoutines = 0,
    this.completedRoutines = 0,
    this.areAllExercisesCompleted = false,
    this.isPastRegularPlan = false,
    this.isInGracePeriod = false,
    this.isBlocked = false,
    this.daysLeftInGracePeriod = 0,
  });

  double get completionProgress {
    if (totalRoutines == 0) return 0.0;
    return (completedRoutines / totalRoutines).clamp(0.0, 1.0);
  }
}

class RoutinePlanService {
  /// Agrupa la lista de rutinas en bloques/planes basados en fecha y distancia temporal
  static List<RoutinePlanModel> groupRoutinesIntoPlans(
    List<Map<String, dynamic>> allRoutines, {
    DateTime? userStartDate,
    int? userPlanWeeks,
    DateTime? nowOverride,
  }) {
    if (allRoutines.isEmpty) {
      final now = nowOverride ?? DateTime.now();
      final start = userStartDate ?? now;
      final weeks = userPlanWeeks ?? 4;
      return [
        RoutinePlanModel(
          id: 'plan_default',
          title: 'Plan Actual',
          startDate: start,
          endDate: start.add(Duration(days: weeks * 7)),
          durationWeeks: weeks,
          routines: [],
          isCurrent: true,
        ),
      ];
    }

    final sorted = List<Map<String, dynamic>>.from(allRoutines);
    sorted.sort((a, b) {
      final tsA = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tsB = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return tsA.compareTo(tsB);
    });

    final planDurationWeeks = userPlanWeeks ?? 4;
    final planCycleEnd = userStartDate?.add(Duration(days: planDurationWeeks * 7 + 7));

    final List<List<Map<String, dynamic>>> clusters = [];
    List<Map<String, dynamic>> currentCluster = [];

    for (final r in sorted) {
      final rDate = (r['date'] as Timestamp?)?.toDate();
      if (rDate == null) continue;

      if (currentCluster.isEmpty) {
        currentCluster.add(r);
      } else {
        final lastDate =
            (currentCluster.last['date'] as Timestamp?)?.toDate() ?? rDate;
        final gapDays = rDate.difference(lastDate).inDays;

        final bool bothInCurrentPlanCycle = userStartDate != null &&
            planCycleEnd != null &&
            !lastDate.isBefore(userStartDate.subtract(const Duration(days: 1))) &&
            !lastDate.isAfter(planCycleEnd) &&
            !rDate.isBefore(userStartDate.subtract(const Duration(days: 1))) &&
            !rDate.isAfter(planCycleEnd);

        // Separación de más de 28 días sin entrenamientos indica un plan distinto
        if (!bothInCurrentPlanCycle && gapDays > 28) {
          clusters.add(currentCluster);
          currentCluster = [r];
        } else {
          currentCluster.add(r);
        }
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final now = nowOverride ?? DateTime.now();
    final List<RoutinePlanModel> plans = [];

    for (int i = 0; i < clusters.length; i++) {
      final cluster = clusters[i];
      final firstDate = (cluster.first['date'] as Timestamp).toDate();
      final lastDate = (cluster.last['date'] as Timestamp).toDate();

      int calculatedWeeks = userPlanWeeks ?? 1;
      for (final r in cluster) {
        final dur = (r['durationWeeks'] as num?)?.toInt();
        if (dur != null && dur > calculatedWeeks) {
          calculatedWeeks = dur;
        }
      }
      final spanDays = lastDate.difference(firstDate).inDays;
      final weeksFromSpan = (spanDays / 7).floor() + 1;
      if (weeksFromSpan > calculatedWeeks) {
        calculatedWeeks = weeksFromSpan;
      }
      calculatedWeeks = calculatedWeeks.clamp(1, 12);

      // Determinación de si este plan es el actual
      bool isCurrent = false;
      if (userStartDate != null) {
        final diffDays = firstDate.difference(userStartDate).inDays.abs();
        if (diffDays <= 7) {
          isCurrent = true;
        }
      }
      if (!isCurrent) {
        final planEndWithGrace = firstDate.add(Duration(days: calculatedWeeks * 7 + 7));
        if (!now.isBefore(firstDate) && !now.isAfter(planEndWithGrace)) {
          isCurrent = true;
        }
      }

      final planId = 'plan_${DateFormat('yyyyMMdd').format(firstDate)}';
      final title = isCurrent ? 'Plan Actual' : 'Plan Anterior';

      plans.add(RoutinePlanModel(
        id: planId,
        title: title,
        startDate: firstDate,
        endDate: lastDate,
        durationWeeks: calculatedWeeks,
        routines: cluster,
        isCurrent: isCurrent,
      ));
    }

    // Si ningún plan coincidió con now ni con userStartDate, marcar el último (más reciente) como actual
    if (plans.isNotEmpty && !plans.any((p) => p.isCurrent)) {
      final lastPlan = plans.last;
      final index = plans.indexOf(lastPlan);
      plans[index] = RoutinePlanModel(
        id: lastPlan.id,
        title: 'Plan Actual',
        startDate: lastPlan.startDate,
        endDate: lastPlan.endDate,
        durationWeeks: lastPlan.durationWeeks,
        routines: lastPlan.routines,
        isCurrent: true,
      );
    }

    plans.sort((a, b) {
      if (a.isCurrent && !b.isCurrent) return -1;
      if (!a.isCurrent && b.isCurrent) return 1;
      return b.startDate.compareTo(a.startDate);
    });

    return plans;
  }

  /// Evalúa el estado del plan activo del usuario:
  /// - Semanas correspondientes
  /// - Si completó todos los ejercicios
  /// - Si está en la semana adicional de prórroga (gracia)
  /// - Si se deben bloquear los ejercicios tras vencer la semana adicional sin completarlos
  static RoutinePlanStatus evaluatePlanStatus({
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> allRoutines,
    required Set<String> completedRoutineIds,
    DateTime? nowOverride,
  }) {
    final role = (userData['role'] ?? 'user').toString().toLowerCase();
    if (role == 'admin') {
      return const RoutinePlanStatus(
        areAllExercisesCompleted: false,
        isPastRegularPlan: false,
        isInGracePeriod: false,
        isBlocked: false,
      );
    }

    if (allRoutines.isEmpty) {
      return const RoutinePlanStatus(
        areAllExercisesCompleted: false,
        isPastRegularPlan: false,
        isInGracePeriod: false,
        isBlocked: false,
      );
    }

    final now = nowOverride ?? DateTime.now();

    final userPlanStart = (userData['planStartDate'] as Timestamp?)?.toDate();
    final planDurationFromUser =
        (userData['planDurationWeeks'] as num?)?.toInt();
    final plans = groupRoutinesIntoPlans(
      allRoutines,
      userStartDate: userPlanStart,
      userPlanWeeks: planDurationFromUser,
      nowOverride: now,
    );
    final currentPlan = plans.firstWhere(
      (p) => p.isCurrent,
      orElse: () => plans.first,
    );

    final planRoutines = currentPlan.routines;
    final totalRoutines = planRoutines.length;
    int completedRoutines = 0;

    for (final r in planRoutines) {
      final rId = (r['id'] ?? '').toString();
      if (rId.isNotEmpty && completedRoutineIds.contains(rId)) {
        completedRoutines++;
      }
    }

    final bool areAllExercisesCompleted =
        totalRoutines > 0 && completedRoutines >= totalRoutines;

    // Duración en semanas del plan
    final int planWeeks = (planDurationFromUser != null && planDurationFromUser > 0)
        ? planDurationFromUser
        : currentPlan.durationWeeks;

    // Fecha de inicio del plan
    final DateTime startDate = userPlanStart ?? currentPlan.startDate;

    // Fecha fin regular del plan (inicio + semanas * 7 días a las 23:59:59)
    final regularEndRaw = startDate.add(Duration(days: planWeeks * 7));
    final regularEndDate = DateTime(
      regularEndRaw.year,
      regularEndRaw.month,
      regularEndRaw.day,
      23,
      59,
      59,
    );

    // Semana adicional antes del bloqueo (1 semana extra = 7 días más)
    final gracePeriodEndRaw = regularEndDate.add(const Duration(days: 7));
    final gracePeriodEndDate = DateTime(
      gracePeriodEndRaw.year,
      gracePeriodEndRaw.month,
      gracePeriodEndRaw.day,
      23,
      59,
      59,
    );

    final bool isPastRegularPlan = now.isAfter(regularEndDate);
    final bool isPastGracePeriod = now.isAfter(gracePeriodEndDate);

    bool isInGracePeriod = false;
    bool isBlocked = false;
    int daysLeft = 0;

    if (areAllExercisesCompleted) {
      // Todos los ejercicios completados con éxito: no hay bloqueo ni gracia
      isInGracePeriod = false;
      isBlocked = false;
      daysLeft = 0;
    } else if (isPastRegularPlan) {
      if (!isPastGracePeriod) {
        // Pasaron las semanas regulares pero aún tiene la semana adicional de gracia
        isInGracePeriod = true;
        isBlocked = false;
        final diffHours = gracePeriodEndDate.difference(now).inHours;
        daysLeft = (diffHours / 24).ceil().clamp(1, 7);
      } else {
        // Pasó la semana adicional y NO completó todos los ejercicios: BLOQUEO
        isInGracePeriod = false;
        isBlocked = true;
        daysLeft = 0;
      }
    } else {
      // Aún dentro del período normal del plan
      isInGracePeriod = false;
      isBlocked = false;
      daysLeft = 0;
    }

    return RoutinePlanStatus(
      currentPlan: currentPlan,
      startDate: startDate,
      regularEndDate: regularEndDate,
      gracePeriodEndDate: gracePeriodEndDate,
      planWeeks: planWeeks,
      totalRoutines: totalRoutines,
      completedRoutines: completedRoutines,
      areAllExercisesCompleted: areAllExercisesCompleted,
      isPastRegularPlan: isPastRegularPlan,
      isInGracePeriod: isInGracePeriod,
      isBlocked: isBlocked,
      daysLeftInGracePeriod: daysLeft,
    );
  }
}
