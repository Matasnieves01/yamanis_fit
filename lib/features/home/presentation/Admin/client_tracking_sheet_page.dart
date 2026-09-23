import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/core/constants/muscle_constants.dart';
import 'package:yamanis_fit/core/services/routine_plan_service.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/client_info_page.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/client_routines_page.dart';

class ClientTrackingSheetPage extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientEmail;

  const ClientTrackingSheetPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
  });

  @override
  State<ClientTrackingSheetPage> createState() => _ClientTrackingSheetPageState();
}

class _ClientTrackingSheetPageState extends State<ClientTrackingSheetPage>
    with TickerProviderStateMixin {
  // Colores corporativos basados en la plantilla de seguimiento
  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161F2C);
  final Color surfaceColor = const Color(0xFF1E2838);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color secondaryColor = const Color(0xFF89AC76);

  // Paleta Borgoña / Vino de las tablas de Yamanis Ortega
  final Color burgundyHeader = const Color(0xFF881337);
  final Color burgundyAccent = const Color(0xFFBE123C);
  final Color burgundyLight = const Color(0xFFFCE7F3);
  final Color cellBorderColor = const Color(0xFF334155);

  bool _isLoading = true;
  bool _isSaving = false;

  // Datos del alumno
  String _studentGoal = "Recomposición corporal";
  DateTime? _startDate;
  int _weeksElapsed = 1;
  String _trainerName = "Yamanis Ortega";

  // Rutinas agrupadas por semana -> días
  // Map<int (semana 1..N), List<DaySheetData>>
  final Map<int, List<DaySheetData>> _weeksData = {};
  int _selectedWeek = 1;
  int _totalWeeksCount = 1;

  // Planes de rutina
  List<RoutinePlanModel> _availablePlans = [];
  RoutinePlanModel? _selectedPlan;
  Map<String, Map<String, dynamic>> _logsByRoutineId = {};
  Map<String, Map<String, dynamic>> _savedOverrides = {};

  late TabController _tabController;
  final Map<String, Map<String, dynamic>> _workoutCache = {};

  void _selectPlan(RoutinePlanModel plan) {
    setState(() {
      _selectedPlan = plan;
      _selectedWeek = 1;
      _buildWeeksStructureForPlan(plan, _logsByRoutineId, _savedOverrides);
    });
  }

  @override
  void initState() {
    super.initState();
    _initTabController(_totalWeeksCount);
    _loadAllTrackingData();
  }

  void _initTabController(int weeksCount) {
    _totalWeeksCount = weeksCount;
    _tabController = TabController(length: _totalWeeksCount + 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging && _tabController.index < _totalWeeksCount) {
      setState(() {
        _selectedWeek = _tabController.index + 1;
      });
    }
  }

  void _updateTabController(int newWeeksCount) {
    final newLength = newWeeksCount + 2;
    if (_tabController.length != newLength) {
      final oldIndex = _tabController.index.clamp(0, newLength - 1);
      final oldController = _tabController;
      _totalWeeksCount = newWeeksCount;
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: oldIndex,
      );
      _tabController.addListener(_handleTabSelection);
      oldController.removeListener(_handleTabSelection);
      oldController.dispose();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTrackingData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Cargar datos de usuario
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .get();
      final userData = userDoc.data() ?? {};

      // Extraer objetivo y fecha de inicio
      final createdAtTs = userData['createdAt'] as Timestamp?;
      _startDate = createdAtTs?.toDate() ?? DateTime.now();

      final dataSheet = userData['dataSheet'] as Map<String, dynamic>?;
      final assessment = dataSheet?['assessment'] as Map<String, dynamic>?;
      if (assessment != null && assessment['trainingGoals'] != null) {
        final goals = assessment['trainingGoals'].toString().trim();
        if (goals.isNotEmpty) _studentGoal = goals;
      }

      final now = DateTime.now();
      final diffDays = now.difference(_startDate ?? now).inDays;
      _weeksElapsed = (diffDays / 7).ceil().clamp(1, 100);

      // 2. Cargar rutinas asignadas al cliente
      final List<Map<String, dynamic>> allRoutines = [];
      try {
        final routinesSnap = await FirebaseFirestore.instance
            .collection('routines')
            .where('clientId', isEqualTo: widget.clientId)
            .get();
        for (final doc in routinesSnap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          allRoutines.add(data);
        }
      } catch (e) {
        debugPrint('Error cargando rutinas: $e');
      }

      // 3. Cargar logs de rutinas completadas
      final Map<String, Map<String, dynamic>> logsByRoutineId = {};
      try {
        final logsSnap = await FirebaseFirestore.instance
            .collection('routine_logs')
            .where('userId', isEqualTo: widget.clientId)
            .get();
        for (final logDoc in logsSnap.docs) {
          final log = logDoc.data();
          final rId = log['routineId']?.toString();
          if (rId != null && rId.isNotEmpty) {
            logsByRoutineId[rId] = log;
          }
        }
      } catch (e) {
        debugPrint('Error cargando logs: $e');
      }

      // 4. Cargar entrenamientos para clasificar músculos específicos
      try {
        final workoutsSnap =
            await FirebaseFirestore.instance.collection('workouts').get();
        for (final doc in workoutsSnap.docs) {
          _workoutCache[doc.id] = doc.data();
        }
      } catch (e) {
        debugPrint('Error cargando workouts: $e');
      }

      // 5. Cargar overrides guardados previamente por el admin (desde userData)
      final Map<String, Map<String, dynamic>> savedOverrides = {};
      final rawTrackingSheets = userData['trackingSheets'] as Map<String, dynamic>?;
      if (rawTrackingSheets != null) {
        rawTrackingSheets.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            savedOverrides[key] = val;
          }
        });
      }

      // Intento opcional en subcolección sin interrumpir si no tiene permisos
      try {
        final overridesSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.clientId)
            .collection('tracking_sheets')
            .get();
        for (final doc in overridesSnap.docs) {
          savedOverrides[doc.id] = doc.data();
        }
      } catch (_) {
        // Fallback silencioso seguro
      }

      // Ordenar cronológicamente
      allRoutines.sort((a, b) {
        final tsA = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tsB = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tsA.compareTo(tsB);
      });

      _logsByRoutineId = logsByRoutineId;
      _savedOverrides = savedOverrides;

      // Agrupar rutinas por planes
      _availablePlans = _groupRoutinesIntoPlans(allRoutines);
      _selectedPlan = _availablePlans.first;

      _buildWeeksStructureForPlan(_selectedPlan!, _logsByRoutineId, _savedOverrides);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando hoja de registro: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<RoutinePlanModel> _groupRoutinesIntoPlans(List<Map<String, dynamic>> allRoutines) {
    return RoutinePlanService.groupRoutinesIntoPlans(
      allRoutines,
      userStartDate: _startDate,
    );
  }

  void _buildWeeksStructureForPlan(
    RoutinePlanModel plan,
    Map<String, Map<String, dynamic>> logsByRoutineId,
    Map<String, Map<String, dynamic>> savedOverrides,
  ) {
    _weeksData.clear();

    _totalWeeksCount = plan.durationWeeks.clamp(1, 12);
    _selectedWeek = _selectedWeek.clamp(1, _totalWeeksCount);
    _updateTabController(_totalWeeksCount);

    for (int w = 1; w <= _totalWeeksCount; w++) {
      _weeksData[w] = [];
    }

    final routines = plan.routines;
    if (routines.isEmpty) {
      for (int w = 1; w <= _totalWeeksCount; w++) {
        _weeksData[w] = [
          DaySheetData(
            dayNumber: 1,
            dayTitle: "DÍA 1: ESTRUCTURA",
            sessionDuration: "60MIN",
            targetMuscles: "Tren Superior",
            strengthNotes: "",
            exercises: [
              ExerciseRowData(
                studentNotes: "",
                category: "Pectoral",
                exerciseName: "Press de pecho",
                technicalFeedback: "Controla la fase excéntrica",
                totalSets: "4",
                rirRpe: "RPE 8",
                sets: [
                  SetDetail(reps: "12", weight: "10"),
                  SetDetail(reps: "12", weight: "10"),
                  SetDetail(reps: "10", weight: "12"),
                  SetDetail(reps: "10", weight: "12"),
                ],
              ),
            ],
          ),
          DaySheetData(
            dayNumber: 2,
            dayTitle: "DÍA 2: ESTRUCTURA",
            sessionDuration: "60MIN",
            targetMuscles: "Piernas & Glúteo",
            strengthNotes: "",
            exercises: [],
          ),
        ];
      }
    } else {
      final firstDate = plan.startDate;

      for (int i = 0; i < routines.length; i++) {
        final r = routines[i];
        final rId = r['id']?.toString() ?? '';
        final rDate = (r['date'] as Timestamp?)?.toDate() ?? firstDate;
        final days = rDate.difference(firstDate).inDays;
        final weekIdx = ((days / 7).floor() + 1).clamp(1, _totalWeeksCount);

        final log = logsByRoutineId[rId];
        final routineName = r['name']?.toString() ?? 'Día';
        final workouts = (r['workouts'] as List?) ?? [];
        final muscleFocusList = (r['muscleFocus'] as List?) ?? [];

        final List<ExerciseRowData> exerciseRows = [];

        for (final wGroup in workouts) {
          final wMap = wGroup as Map<String, dynamic>;
          final groupSets = wMap['sets']?.toString() ?? '4';
          final subExercises = (wMap['exercises'] as List?) ?? [wMap];

          for (final ex in subExercises) {
            final exMap = ex as Map<String, dynamic>;
            final wId = exMap['workoutId']?.toString();
            final wName = exMap['workoutName']?.toString() ?? 'Ejercicio';
            final plannedReps = exMap['reps']?.toString() ?? '10-12';
            final plannedWeight = exMap['weight']?.toString() ?? '';
            final description = exMap['description']?.toString() ?? '';

            String category = _inferMuscleCategory(wId, wName, muscleFocusList);

            final List<SetDetail> setsList = [];
            final totalSetsInt = (int.tryParse(groupSets) ?? 4).clamp(1, 4);

            for (int s = 1; s <= 4; s++) {
              if (s <= totalSetsInt) {
                setsList.add(SetDetail(
                  reps: plannedReps,
                  weight: plannedWeight,
                ));
              } else {
                setsList.add(SetDetail(reps: '', weight: ''));
              }
            }

            String studentNotes = "";
            if (log != null) {
              studentNotes = log['clientFeedback']?.toString() ?? '';
              final logResults = (log['results'] as List?) ?? [];
              for (final res in logResults) {
                final resMap = res as Map<String, dynamic>;
                final resExercises = (resMap['exercises'] as List?) ?? [];
                for (final rex in resExercises) {
                  final rexMap = rex as Map<String, dynamic>;
                  if (rexMap['name'] == wName) {
                    final actualW = rexMap['actualWeight']?.toString();
                    final actualR = rexMap['actualReps']?.toString();
                    if (actualW != null && actualW.isNotEmpty) {
                      for (var set in setsList) {
                        if (set.reps.isNotEmpty) {
                          set.weight = actualW;
                        }
                      }
                    }
                    if (actualR != null && actualR.isNotEmpty) {
                      for (var set in setsList) {
                        if (set.reps.isNotEmpty) {
                          set.reps = actualR;
                        }
                      }
                    }
                  }
                }
              }
            }

            exerciseRows.add(ExerciseRowData(
              workoutId: wId,
              studentNotes: studentNotes,
              category: category,
              exerciseName: wName,
              technicalFeedback: description,
              totalSets: totalSetsInt.toString(),
              rirRpe: "RPE 8",
              sets: setsList,
            ));
          }
        }

        final dayNum = (_weeksData[weekIdx]?.length ?? 0) + 1;
        _weeksData.putIfAbsent(weekIdx, () => []);
        _weeksData[weekIdx]!.add(DaySheetData(
          routineId: rId,
          dayNumber: dayNum,
          dayTitle: "DÍA $dayNum: ${routineName.toUpperCase()}",
          sessionDuration: "60MIN",
          targetMuscles: muscleFocusList.join(', '),
          strengthNotes: "",
          exercises: exerciseRows,
        ));
      }
    }

    // Aplicar overrides guardados para este plan
    for (int w = 1; w <= _totalWeeksCount; w++) {
      final overrideKey = '${plan.id}_week_$w';
      final fallbackKey = 'week_$w';
      final overrideMap = savedOverrides[overrideKey] ??
          (plan.isCurrent ? savedOverrides[fallbackKey] : null);

      if (overrideMap != null) {
        final daysOverride = (overrideMap['days'] as List?) ?? [];
        final currentDays = _weeksData[w] ?? [];

        for (int d = 0; d < currentDays.length && d < daysOverride.length; d++) {
          final dData = daysOverride[d] as Map<String, dynamic>;
          currentDays[d].sessionDuration = dData['sessionDuration']?.toString() ?? currentDays[d].sessionDuration;
          currentDays[d].doms = dData['doms']?.toString() ?? currentDays[d].doms;
          currentDays[d].targetMuscles = dData['targetMuscles']?.toString() ?? currentDays[d].targetMuscles;
          currentDays[d].dailyWeight = dData['dailyWeight']?.toString() ?? currentDays[d].dailyWeight;
          currentDays[d].strengthNotes = dData['strengthNotes']?.toString() ?? currentDays[d].strengthNotes;

          final exOverrides = (dData['exercises'] as List?) ?? [];
          for (int e = 0; e < currentDays[d].exercises.length && e < exOverrides.length; e++) {
            final eData = exOverrides[e] as Map<String, dynamic>;
            final ex = currentDays[d].exercises[e];
            ex.studentNotes = eData['studentNotes']?.toString() ?? ex.studentNotes;
            ex.category = eData['category']?.toString() ?? ex.category;
            ex.exerciseName = eData['exerciseName']?.toString() ?? ex.exerciseName;
            ex.technicalFeedback = eData['technicalFeedback']?.toString() ?? ex.technicalFeedback;
            ex.totalSets = eData['totalSets']?.toString() ?? ex.totalSets;
            ex.rirRpe = eData['rirRpe']?.toString() ?? ex.rirRpe;

            final setsOv = (eData['sets'] as List?) ?? [];
            for (int s = 0; s < ex.sets.length && s < setsOv.length; s++) {
              final sMap = setsOv[s] as Map<String, dynamic>;
              ex.sets[s].reps = sMap['reps']?.toString() ?? ex.sets[s].reps;
              ex.sets[s].weight = sMap['weight']?.toString() ?? ex.sets[s].weight;
            }
          }
        }
      }
    }
  }

  String _inferMuscleCategory(
      String? workoutId, String workoutName, List<dynamic> routineMuscleFocus) {
    if (workoutId != null && _workoutCache.containsKey(workoutId)) {
      final doc = _workoutCache[workoutId]!;
      final specific = (doc['specificMuscles'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (specific.isNotEmpty) return specific.first;
      final general = (doc['generalMuscles'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (general.isNotEmpty) {
        final mapped = MuscleConstants.musclesByCategory[general.first];
        if (mapped != null && mapped.isNotEmpty) return mapped.first;
        return general.first;
      }
    }

    final lower = workoutName.toLowerCase();
    if (lower.contains('pecho') || lower.contains('bench') || lower.contains('press banca')) {
      return 'Pectoral';
    }
    if (lower.contains('sentadilla') || lower.contains('prensa') || lower.contains('cuad')) {
      return 'Cuádriceps';
    }
    if (lower.contains('bicep') || lower.contains('curl')) return 'Bíceps';
    if (lower.contains('tricep') || lower.contains('fondo') || lower.contains('copa')) {
      return 'Tríceps';
    }
    if (lower.contains('espalda') || lower.contains('remo') || lower.contains('jalon')) {
      return 'Espalda';
    }
    if (lower.contains('glute') || lower.contains('hip thrust')) return 'Glúteo';
    if (lower.contains('isquio') || lower.contains('femor') || lower.contains('peso muerto')) {
      return 'Isquiosurales';
    }
    if (lower.contains('gemelo') || lower.contains('pantorrilla')) return 'Gemelos';
    if (lower.contains('hombro') || lower.contains('militar')) return 'Deltoides anterior';
    if (lower.contains('lateral') || lower.contains('vuelo')) return 'Deltoides lateral';
    if (lower.contains('posterior') || lower.contains('pajaro')) return 'Deltoides posterior';
    if (lower.contains('abdom') || lower.contains('plancha') || lower.contains('crunch')) {
      return 'Abdominales';
    }
    if (lower.contains('abductor')) return 'Abductores';
    if (lower.contains('aductor')) return 'Aductores';

    if (routineMuscleFocus.isNotEmpty) {
      final gen = routineMuscleFocus.first.toString();
      final mapped = MuscleConstants.musclesByCategory[gen];
      if (mapped != null && mapped.isNotEmpty) return mapped.first;
      return gen;
    }

    return 'Pectoral';
  }

  Future<void> _saveCurrentWeekOverrides() async {
    setState(() => _isSaving = true);

    try {
      final days = _weeksData[_selectedWeek] ?? [];
      final daysToSave = days.map((day) => day.toMap()).toList();
      final planId = _selectedPlan?.id ?? 'default';

      // 1. Guardar en el documento del usuario con clave del plan
      final trackingSheetsUpdate = <String, dynamic>{
        '${planId}_week_$_selectedWeek': {
          'planId': planId,
          'weekNumber': _selectedWeek,
          'days': daysToSave,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      };
      if (_selectedPlan?.isCurrent == true) {
        trackingSheetsUpdate['week_$_selectedWeek'] = {
          'weekNumber': _selectedWeek,
          'days': daysToSave,
          'updatedAt': DateTime.now().toIso8601String(),
        };
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .set({
        'trackingSheets': trackingSheetsUpdate,
      }, SetOptions(merge: true));

      // 2. Guardar también en la subcolección de forma opcional
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.clientId)
            .collection('tracking_sheets')
            .doc('${planId}_week_$_selectedWeek')
            .set({
          'planId': planId,
          'weekNumber': _selectedWeek,
          'days': daysToSave,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Semana $_selectedWeek guardada correctamente'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar semana: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _editExerciseRow(DaySheetData day, ExerciseRowData ex) {
    final noteCtrl = TextEditingController(text: ex.studentNotes);
    final catCtrl = TextEditingController(text: ex.category);
    final feedbackCtrl = TextEditingController(text: ex.technicalFeedback);
    final rirCtrl = TextEditingController(text: ex.rirRpe);
    final setsCtrl = TextEditingController(text: ex.totalSets);

    final List<TextEditingController> repsCtrls = ex.sets.take(4).map((s) => TextEditingController(text: s.reps)).toList();
    final List<TextEditingController> weightCtrls = ex.sets.take(4).map((s) => TextEditingController(text: s.weight)).toList();

    // Asegurar que haya 4 controladores
    while (repsCtrls.length < 4) {
      repsCtrls.add(TextEditingController());
      weightCtrls.add(TextEditingController());
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ex.exerciseName.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField("Categoría de ejercicio (Músculo)", catCtrl),
                const SizedBox(height: 8),
                _buildDialogField("Feedback Técnico (Entrenadora)", feedbackCtrl),
                const SizedBox(height: 8),
                _buildDialogField("Notas del Alumno", noteCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDialogField("Series", setsCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDialogField("RIR/RPE", rirCtrl)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "SERIES (REPS & PESO EN KG) - MÁX 4 SERIES",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 6),
                for (int i = 0; i < 4; i++) ...[
                  Row(
                    children: [
                      Text("S${i + 1}:", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: repsCtrls[i],
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: "Reps",
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                            filled: true,
                            fillColor: surfaceColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: weightCtrls[i],
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: "Kg",
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                            filled: true,
                            fillColor: surfaceColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                ex.studentNotes = noteCtrl.text.trim();
                ex.category = catCtrl.text.trim();
                ex.technicalFeedback = feedbackCtrl.text.trim();
                ex.rirRpe = rirCtrl.text.trim();
                ex.totalSets = setsCtrl.text.trim();
                for (int i = 0; i < 4 && i < ex.sets.length; i++) {
                  ex.sets[i].reps = repsCtrls[i].text.trim();
                  ex.sets[i].weight = weightCtrls[i].text.trim();
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: backgroundColor),
            child: const Text("APLICAR", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editDaySummary(DaySheetData day) {
    final durCtrl = TextEditingController(text: day.sessionDuration);
    final muscCtrl = TextEditingController(text: day.targetMuscles);
    final strengthCtrl = TextEditingController(text: day.strengthNotes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "DATOS DE LA SESIÓN: ${day.dayTitle}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField("Duración de la sesión (ej. 60MIN)", durCtrl),
            const SizedBox(height: 8),
            _buildDialogField("Grupo Muscular (ej. upper, piernas)", muscCtrl),
            const SizedBox(height: 8),
            _buildDialogField("Fuerza / Observaciones", strengthCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                day.sessionDuration = durCtrl.text.trim();
                day.targetMuscles = muscCtrl.text.trim();
                day.strengthNotes = strengthCtrl.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: backgroundColor),
            child: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        centerTitle: true,
        title: const Text(
          "TABLA DE CONTROL",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: "Recargar datos",
            onPressed: _loadAllTrackingData,
          ),
          IconButton(
            icon: Icon(Icons.save_rounded, color: primaryColor),
            tooltip: "Guardar Semana",
            onPressed: _isSaving ? null : _saveCurrentWeekOverrides,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                // 1. CABECERA TIPO GOOGLE SHEETS DE LA ENTRENADORA
                _buildSheetTopBanner(),

                // 2. SELECTOR DE PLAN DE RUTINA (NUEVO: ACTUAL VS HISTÓRICOS)
                _buildPlanSelectorBanner(),

                // 3. TABS ESTILO PESTAÑAS EXCEL INFERIORES
                _buildSheetTabBar(),

                // 4. VISTAS DE PESTAÑAS (SEMANAS + CONTADOR DE SERIES + DATOS GENERALES)
                Expanded(
                  child: TabBarView(
                    key: ValueKey('sheet_tab_view_${_selectedPlan?.id}_$_totalWeeksCount'),
                    controller: _tabController,
                    children: [
                      // Pestañas de Semanas 1 a N
                      for (int w = 1; w <= _totalWeeksCount; w++)
                        _buildWeekSheetView(w),

                      // Pestaña Contador de Series (Imagen 2)
                      _buildMuscleCounterView(),

                      // Pestaña Datos Generales
                      _buildGeneralDataView(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientInfoPage(
                        clientId: widget.clientId,
                        clientName: widget.clientName,
                        clientEmail: widget.clientEmail,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.accessibility_new_rounded, color: primaryColor, size: 16),
                label: Text(
                  "ESQUELETO & ENCUESTAS",
                  style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientRoutinesPage(
                        clientId: widget.clientId,
                        clientName: widget.clientName,
                        clientEmail: widget.clientEmail,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.calendar_month_rounded, color: backgroundColor, size: 16),
                label: Text(
                  "CALENDARIO DE RUTINAS",
                  style: TextStyle(color: backgroundColor, fontSize: 11, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLongDate(DateTime? date) {
    if (date == null) return "--";
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return "${date.day} de ${months[date.month - 1]}, ${date.year}";
  }

  // --- SECCIÓN 1: CABECERA TIPO PLANILLA DE ENTRENAMIENTO ---

  Widget _buildSheetTopBanner() {
    final dateStr = DateFormat("dd/MM/yyyy").format(DateTime.now());
    final planStart = _selectedPlan?.startDate ?? _startDate;
    final startStr = planStart != null ? DateFormat("dd/MM/yy").format(planStart) : "--";
    final totalPlanWeeks = _selectedPlan?.durationWeeks ?? _totalWeeksCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: burgundyAccent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fila 1: Logo, Entrenador/a, Fecha de hoy, Semanas transcurridas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: burgundyHeader.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                // Logo YO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: burgundyAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "YO",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell("Entrenador/a", _trainerName),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell("Fecha de hoy", dateStr),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell("Semanas", "$totalPlanWeeks sem"),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Fila 2: Nombre alumno, Fecha inicio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildHeaderCell("Nombre del alumno", widget.clientName),
                ),
                Expanded(
                  flex: 3,
                  child: _buildHeaderCell("Fecha de inicio", startStr),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Fila 3: Objetivo del alumno
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: _buildHeaderCell("Objetivo del alumno", _studentGoal),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // --- SECCIÓN 2: SELECTOR DE PLAN DE RUTINA Y TABS EXCEL ---

  Widget _buildPlanSelectorBanner() {
    if (_availablePlans.isEmpty) return const SizedBox.shrink();

    final plan = _selectedPlan ?? _availablePlans.first;
    final startStr = DateFormat("dd/MM/yy").format(plan.startDate);
    final endStr = DateFormat("dd/MM/yy").format(plan.endDate);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: plan.isCurrent
              ? primaryColor.withValues(alpha: 0.4)
              : cellBorderColor,
        ),
      ),
      child: InkWell(
        onTap: _showPlanSelectionModal,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: plan.isCurrent
                    ? primaryColor.withValues(alpha: 0.2)
                    : burgundyAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                plan.isCurrent ? Icons.calendar_month_rounded : Icons.history_rounded,
                color: plan.isCurrent ? primaryColor : Colors.white70,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.isCurrent ? "PLAN ACTUAL" : "PLAN HISTÓRICO",
                        style: TextStyle(
                          color: plan.isCurrent ? primaryColor : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: plan.isCurrent
                              ? primaryColor.withValues(alpha: 0.2)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${plan.durationWeeks} SEMANAS",
                          style: TextStyle(
                            color: plan.isCurrent ? primaryColor : Colors.white60,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$startStr al $endStr • ${plan.routines.length} sesiones",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Cambiar plan",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlanSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.layers_rounded, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "PLANES DE RUTINA DEL ALUMNO",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Selecciona el plan que deseas visualizar por separado:",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availablePlans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final plan = _availablePlans[index];
                      final isSelected = plan.id == _selectedPlan?.id;
                      final startStr = DateFormat("dd/MM/yyyy").format(plan.startDate);
                      final endStr = DateFormat("dd/MM/yyyy").format(plan.endDate);

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _selectPlan(plan);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withValues(alpha: 0.12)
                                : cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : cellBorderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: plan.isCurrent
                                      ? primaryColor.withValues(alpha: 0.2)
                                      : burgundyAccent.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  plan.isCurrent
                                      ? Icons.play_circle_filled_rounded
                                      : Icons.history_rounded,
                                  color: plan.isCurrent ? primaryColor : Colors.white70,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          plan.isCurrent ? "Plan Actual (En curso)" : "Plan Pasado",
                                          style: TextStyle(
                                            color: isSelected ? primaryColor : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: plan.isCurrent
                                                ? primaryColor.withValues(alpha: 0.2)
                                                : Colors.white10,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            "${plan.durationWeeks} sem",
                                            style: TextStyle(
                                              color: plan.isCurrent ? primaryColor : Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "$startStr  →  $endStr",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      "${plan.routines.length} sesiones de entrenamiento registradas",
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: primaryColor, size: 22)
                              else
                                const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: TabBar(
        key: ValueKey('sheet_tab_bar_${_selectedPlan?.id}_$_totalWeeksCount'),
        controller: _tabController,
        isScrollable: true,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        onTap: (idx) {
          if (idx < _totalWeeksCount) {
            setState(() => _selectedWeek = idx + 1);
          }
        },
        tabs: [
          for (int w = 1; w <= _totalWeeksCount; w++)
            Tab(text: "Semana $w"),
          const Tab(
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 16),
                SizedBox(width: 6),
                Text("Contador de series"),
              ],
            ),
          ),
          const Tab(
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 16),
                SizedBox(width: 6),
                Text("Datos Generales"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN 3: TABLA DE RUTINA DE LA SEMANA ---

  Widget _buildWeekSheetView(int weekNumber) {
    final days = _weeksData[weekNumber] ?? [];

    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, color: Colors.white30, size: 48),
              const SizedBox(height: 12),
              Text(
                "Sin rutinas para la Semana $weekNumber",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                "Crea rutinas para este alumno desde el Calendario de Rutinas para que se sincronicen en esta hoja.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "SEMANA $weekNumber - CONTROL DE SESIONES",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Toca para editar",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final day in days) ...[
            _buildDayStructureBlock(day),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildDayStructureBlock(DaySheetData day) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cellBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Cabecera: DÍA X: ESTRUCTURA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: burgundyHeader,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    day.dayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      "${day.exercises.length} Ejercicios",
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Editar datos de sesión",
                      onPressed: () => _editDaySummary(day),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabla con scroll horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(burgundyAccent.withValues(alpha: 0.2)),
              headingRowHeight: 34,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columnSpacing: 16,
              horizontalMargin: 12,
              border: TableBorder.all(color: cellBorderColor, width: 0.8),
              columns: const [
                DataColumn(label: Text("Notas del alumno", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Categoría de ejercicio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Ejercicios", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Feedback Técnico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Series", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("RIR/RPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Serie 1 (R/Kg)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Serie 2 (R/Kg)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Serie 3 (R/Kg)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Serie 4 (R/Kg)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: day.exercises.map((ex) {
                return DataRow(
                  onSelectChanged: (_) => _editExerciseRow(day, ex),
                  cells: [
                    DataCell(Text(ex.studentNotes.isNotEmpty ? ex.studentNotes : "--", style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: burgundyAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(ex.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    DataCell(Text(ex.exerciseName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
                    DataCell(Text(ex.technicalFeedback.isNotEmpty ? ex.technicalFeedback : "--", style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    DataCell(Center(child: Text(ex.totalSets, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))),
                    DataCell(Text(ex.rirRpe, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    DataCell(_buildSetCell(ex.sets.isNotEmpty ? ex.sets[0] : SetDetail(reps: '', weight: ''))),
                    DataCell(_buildSetCell(ex.sets.length > 1 ? ex.sets[1] : SetDetail(reps: '', weight: ''))),
                    DataCell(_buildSetCell(ex.sets.length > 2 ? ex.sets[2] : SetDetail(reps: '', weight: ''))),
                    DataCell(_buildSetCell(ex.sets.length > 3 ? ex.sets[3] : SetDetail(reps: '', weight: ''))),
                  ],
                );
              }).toList(),
            ),
          ),

          // Fila Resumen Inferior del Día (Duración, Grupo muscular, Fuerza/Observaciones)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDayFooterItem("Duración de la sesión", day.sessionDuration.isNotEmpty ? day.sessionDuration : "60MIN"),
                  _buildDividerDot(),
                  _buildDayFooterItem("Grupo Muscular", day.targetMuscles.isNotEmpty ? day.targetMuscles : "General"),
                  _buildDividerDot(),
                  _buildDayFooterItem("Fuerza / Observaciones", day.strengthNotes.isNotEmpty ? day.strengthNotes : "--"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetCell(SetDetail s) {
    if (s.reps.isEmpty && s.weight.isEmpty) {
      return const Text("--", style: TextStyle(color: Colors.white24, fontSize: 10));
    }
    return Text(
      "${s.reps}r x ${s.weight}kg",
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
    );
  }

  Widget _buildDayFooterItem(String title, String val) {
    return Row(
      children: [
        Text(
          "$title: ",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          val,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDividerDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text("•", style: TextStyle(color: primaryColor, fontSize: 12)),
    );
  }

  // --- SECCIÓN 4: PESTAÑA CONTADOR DE SERIES POR GRUPO MUSCULAR (IMAGEN 2) ---

  Widget _buildMuscleCounterView() {
    final days = _weeksData[_selectedWeek] ?? [];

    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, color: Colors.white30, size: 48),
              const SizedBox(height: 12),
              Text(
                "Sin rutinas para la Semana $_selectedWeek",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                "El contador de series se calcula automáticamente a partir de las rutinas de esta semana.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Lista exacta de 14 músculos de la Imagen 2
    final specificMuscles = MuscleConstants.specificMuscles;

    // Calcular series por músculo para cada día de la semana actual
    // Map<Músculo, List<int seriesPorDía>>
    final Map<String, List<int>> matrix = {};
    for (final m in specificMuscles) {
      matrix[m] = List.generate(days.length, (_) => 0);
    }

    for (int d = 0; d < days.length; d++) {
      final day = days[d];
      for (final ex in day.exercises) {
        final muscle = ex.category;
        final setsCount = int.tryParse(ex.totalSets) ?? 0;

        // Si coincide exactamente con uno de los 14
        if (matrix.containsKey(muscle) && matrix[muscle] != null && matrix[muscle]!.length > d) {
          matrix[muscle]![d] += setsCount;
        } else {
          // Si es general (ej. Piernas, Brazos), buscar el músculo representativo
          bool mapped = false;
          for (final sm in specificMuscles) {
            if (sm.toLowerCase() == muscle.toLowerCase()) {
              if (matrix[sm] != null && matrix[sm]!.length > d) {
                matrix[sm]![d] += setsCount;
              }
              mapped = true;
              break;
            }
          }
          if (!mapped) {
            // Mapear Deltoides si dice Hombros, etc.
            if (muscle.toLowerCase().contains('hombro')) {
              if (matrix['Deltoides anterior'] != null && matrix['Deltoides anterior']!.length > d) {
                matrix['Deltoides anterior']![d] += setsCount;
              }
            } else if (muscle.toLowerCase().contains('pecho')) {
              if (matrix['Pectoral'] != null && matrix['Pectoral']!.length > d) {
                matrix['Pectoral']![d] += setsCount;
              }
            } else if (muscle.toLowerCase().contains('brazo')) {
              if (matrix['Bíceps'] != null && matrix['Bíceps']!.length > d) {
                matrix['Bíceps']![d] += setsCount;
              }
            } else if (muscle.toLowerCase().contains('espalda')) {
              if (matrix['Espalda'] != null && matrix['Espalda']!.length > d) {
                matrix['Espalda']![d] += setsCount;
              }
            }
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "CONTADOR DE SERIES POR GRUPO MUSCULAR (SEMANA $_selectedWeek)",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: burgundyAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${days.length} DÍAS",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tabla réplica de la Imagen 2
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cellBorderColor),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(burgundyHeader),
                headingRowHeight: 38,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                columnSpacing: 18,
                horizontalMargin: 12,
                border: TableBorder.all(color: cellBorderColor, width: 0.8),
                columns: [
                  const DataColumn(
                    label: Text(
                      "CONTADOR POR GRUPO MUSCULAR",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  for (int d = 0; d < days.length; d++)
                    DataColumn(
                      label: Center(
                        child: Text(
                          "Día ${d + 1}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  const DataColumn(
                    label: Center(
                      child: Text(
                        "SUMA",
                        style: TextStyle(color: Color(0xFFAEE084), fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Center(
                      child: Text(
                        "TOTAL",
                        style: TextStyle(color: Color(0xFFAEE084), fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ),
                ],
                rows: [
                  // 14 filas de músculos
                  ...specificMuscles.map((muscle) {
                    final rowSeries = matrix[muscle] ?? [];
                    final rowSum = rowSeries.fold<int>(0, (sum, val) => sum + val);

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            muscle,
                            style: TextStyle(
                              color: rowSum > 0 ? Colors.white : Colors.white60,
                              fontWeight: rowSum > 0 ? FontWeight.w900 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        for (int d = 0; d < days.length; d++)
                          DataCell(
                            Center(
                              child: Text(
                                "${rowSeries.length > d ? rowSeries[d] : 0}",
                                style: TextStyle(
                                  color: (rowSeries.length > d && rowSeries[d] > 0)
                                      ? primaryColor
                                      : Colors.white30,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        DataCell(
                          Center(
                            child: Text(
                              "$rowSum",
                              style: TextStyle(
                                color: rowSum > 0 ? primaryColor : Colors.white38,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              "$rowSum",
                              style: TextStyle(
                                color: rowSum > 0 ? primaryColor : Colors.white38,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  // Fila Total SUMA al pie
                  DataRow(
                    color: WidgetStateProperty.all(burgundyHeader.withValues(alpha: 0.4)),
                    cells: [
                      const DataCell(
                        Text(
                          "SUMA TOTAL SESIONES",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                      for (int d = 0; d < days.length; d++)
                        DataCell(
                          Center(
                            child: Text(
                              "${specificMuscles.fold<int>(0, (sum, m) => sum + ((matrix[m]?.length ?? 0) > d ? (matrix[m]?[d] ?? 0) : 0))}",
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ),
                      DataCell(
                        Center(
                          child: Text(
                            "${specificMuscles.fold<int>(0, (sum, m) => sum + (matrix[m]?.fold<int>(0, (s, v) => s + v) ?? 0))}",
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(
                        Center(
                          child: Text(
                            "${specificMuscles.fold<int>(0, (sum, m) => sum + (matrix[m]?.fold<int>(0, (s, v) => s + v) ?? 0))}",
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN 5: PESTAÑA DATOS GENERALES ---

  Widget _buildGeneralDataView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RESUMEN DEL EXPEDIENTE DEL ALUMNO",
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cellBorderColor),
            ),
            child: Column(
              children: [
                _buildSummaryTile(Icons.person, "Nombre Completo", widget.clientName),
                const Divider(color: Colors.white10),
                _buildSummaryTile(Icons.email_outlined, "Correo Electrónico", widget.clientEmail),
                const Divider(color: Colors.white10),
                _buildSummaryTile(Icons.track_changes_rounded, "Objetivo Principal", _studentGoal),
                const Divider(color: Colors.white10),
                _buildSummaryTile(
                  Icons.calendar_today_rounded,
                  "Fecha de Inicio",
                  _formatLongDate(_startDate),
                ),
                const Divider(color: Colors.white10),
                _buildSummaryTile(Icons.timer_outlined, "Semanas Activas", "$_weeksElapsed semanas"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- MODELOS DE DATOS DE LA HOJA DE REGISTRO ---

class DaySheetData {
  String? routineId;
  int dayNumber;
  String dayTitle;
  String sessionDuration;
  String targetMuscles;
  String doms;
  String dailyWeight;
  String strengthNotes;
  List<ExerciseRowData> exercises;

  DaySheetData({
    this.routineId,
    required this.dayNumber,
    required this.dayTitle,
    required this.sessionDuration,
    required this.targetMuscles,
    this.doms = "",
    this.dailyWeight = "",
    required this.strengthNotes,
    required this.exercises,
  });

  Map<String, dynamic> toMap() {
    return {
      'routineId': routineId,
      'dayNumber': dayNumber,
      'dayTitle': dayTitle,
      'sessionDuration': sessionDuration,
      'targetMuscles': targetMuscles,
      'doms': doms,
      'dailyWeight': dailyWeight,
      'strengthNotes': strengthNotes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}

class ExerciseRowData {
  String? workoutId;
  String studentNotes;
  String category;
  String exerciseName;
  String technicalFeedback;
  String totalSets;
  String rirRpe;
  String restTime;
  List<SetDetail> sets;

  ExerciseRowData({
    this.workoutId,
    required this.studentNotes,
    required this.category,
    required this.exerciseName,
    required this.technicalFeedback,
    required this.totalSets,
    required this.rirRpe,
    this.restTime = "",
    required this.sets,
  });

  double calculateTonnage() {
    double total = 0.0;
    for (final s in sets) {
      final r = double.tryParse(s.reps) ?? 0.0;
      final w = double.tryParse(s.weight) ?? 0.0;
      total += (r * w);
    }
    return total;
  }

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'studentNotes': studentNotes,
      'category': category,
      'exerciseName': exerciseName,
      'technicalFeedback': technicalFeedback,
      'totalSets': totalSets,
      'rirRpe': rirRpe,
      'restTime': restTime,
      'sets': sets.map((s) => s.toMap()).toList(),
    };
  }
}

class SetDetail {
  String reps;
  String weight;

  SetDetail({required this.reps, required this.weight});

  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'weight': weight,
    };
  }
}
