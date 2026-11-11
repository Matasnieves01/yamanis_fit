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
  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Agrupa la lista de rutinas en bloques/planes separados cada vez que se crea una
  /// nueva rutina (por `planId`, lote de `createdAt`, `planStartDate`, o ciclo de semanas).
  static List<RoutinePlanModel> groupRoutinesIntoPlans(
    List<Map<String, dynamic>> allRoutines, {
    DateTime? userStartDate,
    int? userPlanWeeks,
    String? currentPlanId,
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

    final DateTime? userStartDay =
        userStartDate != null ? _dayOnly(userStartDate) : null;
    final int defaultPlanWeeks =
        (userPlanWeeks != null && userPlanWeeks > 0) ? userPlanWeeks : 4;

    final List<List<Map<String, dynamic>>> clusters = [];
    List<Map<String, dynamic>> currentCluster = [];

    for (final r in sorted) {
      final rDateRaw = (r['date'] as Timestamp?)?.toDate();
      if (rDateRaw == null) continue;
      final rDay = _dayOnly(rDateRaw);

      if (currentCluster.isEmpty) {
        currentCluster.add(r);
        continue;
      }

      final first = currentCluster.first;
      final prev = currentCluster.last;
      final firstDateRaw = (first['date'] as Timestamp).toDate();
      final prevDateRaw = (prev['date'] as Timestamp).toDate();
      final firstDay = _dayOnly(firstDateRaw);
      final prevDay = _dayOnly(prevDateRaw);

      final String rPlanId = (r['planId'] ?? '').toString().trim();
      final String firstPlanId = (first['planId'] ?? '').toString().trim();

      bool shouldStartNewPlan = false;

      // 1. Si alguno tiene planId explícito y son distintos, separar siempre
      if (rPlanId.isNotEmpty || firstPlanId.isNotEmpty) {
        if (rPlanId != firstPlanId) {
          shouldStartNewPlan = true;
        }
      } else {
        // Rutinas sin planId explícito (creadas previamente mes a mes):

        // 2. Si fueron creadas en lotes distintos (diferencia > 2 días en createdAt)
        // y la fecha programada pertenece a una semana posterior al inicio del bloque actual
        final firstCreatedTs = first['createdAt'] as Timestamp?;
        final rCreatedTs = r['createdAt'] as Timestamp?;
        if (firstCreatedTs != null && rCreatedTs != null) {
          final firstCreatedDay = _dayOnly(firstCreatedTs.toDate());
          final rCreatedDay = _dayOnly(rCreatedTs.toDate());
          final createdGap = rCreatedDay.difference(firstCreatedDay).inDays.abs();
          if (createdGap > 2 && rDay.difference(firstDay).inDays >= 7) {
            shouldStartNewPlan = true;
          }
        }

        // 3. Si cruza la fecha de inicio del plan actual del usuario (planStartDate)
        if (!shouldStartNewPlan &&
            userStartDay != null &&
            prevDay.isBefore(userStartDay) &&
            !rDay.isBefore(userStartDay)) {
          shouldStartNewPlan = true;
        }

        // 4. Si supera la duración en semanas del bloque (por defecto 4 semanas = 1 mes)
        if (!shouldStartNewPlan) {
          final explicitDur = (first['durationWeeks'] as num?)?.toInt();
          final int targetWeeks = (explicitDur != null && explicitDur > 0)
              ? explicitDur
              : (userStartDay != null && !firstDay.isBefore(userStartDay)
                  ? defaultPlanWeeks
                  : 4);
          final spanFromClusterStart = rDay.difference(firstDay).inDays;
          if (spanFromClusterStart >= targetWeeks * 7) {
            shouldStartNewPlan = true;
          }
        }

        // 5. Si hay una pausa de más de 14 días sin entrenamientos
        final gapDays = rDay.difference(prevDay).inDays;
        if (!shouldStartNewPlan && gapDays > 14) {
          shouldStartNewPlan = true;
        }
      }

      if (shouldStartNewPlan) {
        clusters.add(currentCluster);
        currentCluster = [r];
      } else {
        currentCluster.add(r);
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<RoutinePlanModel> plans = [];

    for (int i = 0; i < clusters.length; i++) {
      final cluster = clusters[i];
      final firstDate = (cluster.first['date'] as Timestamp).toDate();
      final lastDate = (cluster.last['date'] as Timestamp).toDate();
      final firstDay = _dayOnly(firstDate);
      final lastDay = _dayOnly(lastDate);

      int? explicitWeeks;
      String? explicitPlanId;
      for (final r in cluster) {
        final dur = (r['durationWeeks'] as num?)?.toInt();
        if (dur != null && dur > 0) {
          explicitWeeks = dur;
        }
        final pid = (r['planId'] ?? '').toString().trim();
        if (pid.isNotEmpty) {
          explicitPlanId = pid;
        }
      }

      final spanDays = lastDay.difference(firstDay).inDays;
      final weeksFromSpan = (spanDays ~/ 7) + 1;

      int calculatedWeeks;
      if (explicitWeeks != null) {
        calculatedWeeks = explicitWeeks;
      } else if (userStartDay != null &&
          firstDay.difference(userStartDay).inDays.abs() <= 7 &&
          userPlanWeeks != null &&
          userPlanWeeks > 0) {
        calculatedWeeks = userPlanWeeks;
      } else {
        calculatedWeeks = weeksFromSpan;
      }
      if (weeksFromSpan > calculatedWeeks) {
        calculatedWeeks = weeksFromSpan;
      }
      calculatedWeeks = calculatedWeeks.clamp(1, 12);

      final bool isLastCluster = (i == clusters.length - 1);
      bool isCurrent = false;
      if (currentPlanId != null &&
          currentPlanId.isNotEmpty &&
          explicitPlanId == currentPlanId) {
        isCurrent = true;
      } else if (isLastCluster) {
        isCurrent = true;
      }

      final planId = (explicitPlanId != null && explicitPlanId.isNotEmpty)
          ? explicitPlanId
          : 'plan_${DateFormat('yyyyMMdd').format(firstDate)}_$i';

      plans.add(RoutinePlanModel(
        id: planId,
        title: isCurrent ? 'Plan Actual' : 'Plan Anterior',
        startDate: firstDate,
        endDate: lastDate,
        durationWeeks: calculatedWeeks,
        routines: cluster,
        isCurrent: isCurrent,
      ));
    }

    // Garantizar que solo un plan (el más reciente o el que coincide con currentPlanId) sea marcado como actual
    if (plans.isNotEmpty) {
      int currentIdx = plans.lastIndexWhere((p) => p.isCurrent);
      if (currentIdx == -1) currentIdx = plans.length - 1;
      for (int i = 0; i < plans.length; i++) {
        final p = plans[i];
        final isCurr = (i == currentIdx);
        plans[i] = RoutinePlanModel(
          id: p.id,
          title: isCurr ? 'Plan Actual' : 'Plan Anterior',
          startDate: p.startDate,
          endDate: p.endDate,
          durationWeeks: p.durationWeeks,
          routines: p.routines,
          isCurrent: isCurr,
        );
      }
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
    final currentPlanId = userData['currentPlanId']?.toString();
    final plans = groupRoutinesIntoPlans(
      allRoutines,
      userStartDate: userPlanStart,
      userPlanWeeks: planDurationFromUser,
      currentPlanId: currentPlanId,
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
