import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'view_workout_page.dart';
import 'package:yamanis_fit/features/home/presentation/Client/start_routine_page.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/core/widgets/branded_loading_screen.dart';
import 'data_sheet_page.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isWeekView = false;
  final Map<DateTime, List<Map<String, dynamic>>> _routines = {};

  static const List<String> _esWeekdays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
  static const List<String> _esMonths = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  static const List<String> _fullMonths = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  final Set<String> _completedRoutineIds = {};
  final Set<DateTime> _completedDates = {};
  int _currentStreak = 0;
  int _maxStreak = 0;
  bool _isAccountActive = true;
  DateTime? _activeUntil;
  bool _isLoading = true;
  String _userRole = 'user';
  bool _hasCompletedDataSheet = true;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchRoutines();
  }

  Future<void> _fetchRoutines() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('routines')
          .where('clientId', isEqualTo: user.uid)
          .get();

      final logsSnapshot = await FirebaseFirestore.instance
          .collection('routine_logs')
          .where('userId', isEqualTo: user.uid)
          .get();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final userData = userDoc.data() ?? {};
      _userRole = (userData['role'] ?? 'user').toString().toLowerCase();

      final completedIds = <String>{};
      final completedDates = <DateTime>{};
      for (var logDoc in logsSnapshot.docs) {
        final logData = logDoc.data();
        final routineId = logData['routineId'];
        if (routineId != null) {
          completedIds.add(routineId);
        }
        final Timestamp? logTs = logData['date'];
        if (logTs != null) {
          final logDate = logTs.toDate();
          completedDates.add(DateTime.utc(logDate.year, logDate.month, logDate.day));
        }
      }

      final Map<DateTime, List<Map<String, dynamic>>> newRoutines = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final Timestamp timestamp = data['date'];
        final DateTime date = timestamp.toDate();
        final DateTime normalizedDate = DateTime.utc(date.year, date.month, date.day);

        if (newRoutines[normalizedDate] == null) {
          newRoutines[normalizedDate] = [];
        }
        newRoutines[normalizedDate]!.add(data);
      }

      final activeUntil = (userData['activeUntil'] as Timestamp?)?.toDate();
      final isEnabled = userData['isActive'] == true;
      
      final isAccountActive = _userRole == 'admin' || (isEnabled && (activeUntil == null || activeUntil.isAfter(DateTime.now())));

      // Calculate streak
      // New logic:
      // - A streak only ends if the user misses a day where they had a scheduled routine.
      // - Days without any routine do NOT break the streak (they are ignored).
      // - The user has a number of "forgiveness" opportunities (allowedMisses) to skip scheduled
      //   routine days without the streak breaking. Those skipped scheduled days do not
      //   increment the streak, but also do not immediately break it until the allowance is used up.
      int streak = 0;
      const int allowedMisses = 5;
      int missesUsed = 0;

      DateTime today = DateTime.now();
      DateTime checkDate = DateTime.utc(today.year, today.month, today.day);

      // We'll scan backwards day-by-day. For each day that has at least one scheduled routine
      // we consider it a "required" day. If the user completed that day we increment the streak.
      // If they didn't complete it we consume one miss allowance. If misses exceed allowedMisses
      // the streak ends at that point.
      // Days with no scheduled routine are ignored and do not affect the streak.
      // To avoid infinite loops, stop if we go back more than 2 years.
      final earliestStop = checkDate.subtract(const Duration(days: 365 * 2));
      while (!checkDate.isBefore(earliestStop)) {
        final normalized = DateTime.utc(checkDate.year, checkDate.month, checkDate.day);

        final hasRoutineScheduled = newRoutines.containsKey(normalized);

        if (hasRoutineScheduled) {
          if (completedDates.contains(normalized)) {
            // Completed required day -> counts towards streak
            streak++;
          } else {
            // Missed a required day
            if (missesUsed < allowedMisses) {
              // Use one forgiveness opportunity and continue scanning further back
              missesUsed++;
            } else {
              // No more forgiveness left: streak ends here
              break;
            }
          }
        }

        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      int calculatedMax = 0;
      if (userData['maxStreak'] is num) {
        calculatedMax = (userData['maxStreak'] as num).toInt();
      }
      if (streak > calculatedMax) calculatedMax = streak;

      if (completedDates.isNotEmpty) {
        final sortedDates = completedDates.toList()..sort();
        int tempRun = 0;
        DateTime? previousDate;
        for (var d in sortedDates) {
          if (previousDate == null || d.difference(previousDate).inDays == 1) {
            tempRun++;
          } else {
            tempRun = 1;
          }
          if (tempRun > calculatedMax) calculatedMax = tempRun;
          previousDate = d;
        }
      }
      if (calculatedMax < 14) {
        calculatedMax = 14;
      }

      bool isSheetComplete = true;
      if (_userRole == 'user') {
        isSheetComplete = await BiometricsService.hasCompletedDataSheet(user.uid);
      }

      setState(() {
        _routines.clear();
        _routines.addAll(newRoutines);
        _completedRoutineIds.clear();
        _completedRoutineIds.addAll(completedIds);
        _completedDates.clear();
        _completedDates.addAll(completedDates);
        _currentStreak = streak;
        _maxStreak = calculatedMax;
        _activeUntil = activeUntil;
        _isAccountActive = isAccountActive;
        _hasCompletedDataSheet = isSheetComplete;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }


  List<Map<String, dynamic>> _getRoutinesForDay(DateTime day) {
    return _routines[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  Widget _buildDataSheetPendingBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E2214),
            Color(0xFF181B22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orangeAccent.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_late_rounded,
                  color: Colors.orangeAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Planilla y Medidas pendientes",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Debes completar tus medidas corporales y la encuesta de salud para que tu entrenadora pueda diseñar y asignarte tu plan de entrenamiento.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () async {
                final completed = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DataSheetPage()),
                );
                if (completed == true) {
                  _fetchRoutines();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "COMPLETAR PLANILLA AHORA",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routinesForSelectedDay = _getRoutinesForDay(_selectedDay ?? _focusedDay);

    if (_isLoading) {
      return const BrandedLoadingScreen();
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset(
                            'assets/logos/logo.png',
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              "YAMANI'S FIT",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: primaryColor),
                            onPressed: () {
                              _fetchRoutines();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_userRole == 'user' && !_hasCompletedDataSheet) ...[
                        _buildDataSheetPendingBanner(),
                        const SizedBox(height: 16),
                      ],
                      _buildStreakWidget(),
                      const SizedBox(height: 16),
                      _buildCalendarSection(),
                       const SizedBox(height: 20),
                       Row(
                          children: [
                            const Text(
                              "Rutina del Día",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (_selectedDay != null && isSameDay(_selectedDay, DateTime.now())) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: primaryColor.withOpacity(0.35)),
                                ),
                                child: Text(
                                  "HOY",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (_selectedDay != null)
                              Text(
                                "${_esMonths[_selectedDay!.month - 1]} ${_selectedDay!.day}",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                          ],
                        ),
                       const SizedBox(height: 10),
                       _buildAccessBadge(),
                       if (routinesForSelectedDay.isEmpty)
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(40),
                           decoration: BoxDecoration(
                             color: surfaceColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(24),
                             border: Border.all(color: surfaceColor.withOpacity(0.2)),
                           ),
                           child: const Center(
                             child: Text(
                               'No hay rutinas para hoy',
                               style: TextStyle(color: Colors.white70, fontSize: 16),
                             ),
                           ),
                         )
                       else
                         ...routinesForSelectedDay.map((routine) => _buildProtocolCard(routine)),
                       const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStreakWidget() {
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final isTodayCompleted = _completedDates.contains(todayUtc);
    final routinesToday = _getRoutinesForDay(todayUtc);
    final hasRoutineToday = routinesToday.isNotEmpty;

    // Start of week (Monday)
    final daysToMonday = (todayUtc.weekday == DateTime.monday) ? 0 : (todayUtc.weekday - DateTime.monday);
    final monday = todayUtc.subtract(Duration(days: daysToMonday));

    int completedThisWeek = 0;
    for (int i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      if (_completedDates.contains(d)) {
        completedThisWeek++;
      }
    }

    final displayMaxStreak = _maxStreak > 0 ? _maxStreak : (_currentStreak > 14 ? _currentStreak : 14);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF13181E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD97706).withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Big Flame Badge, Streak Count, Record Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Glowing flame container with x1 badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        center: Alignment.center,
                        radius: 0.8,
                        colors: [
                          Color(0xFF422213),
                          Color(0xFF1D1410),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.25),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '🔥',
                      style: TextStyle(fontSize: 26),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF191009),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF9800).withOpacity(0.7),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'x${_currentStreak > 0 ? _currentStreak : 1}',
                        style: const TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Middle: RACHA ACTIVA & Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentStreak > 0 ? const Color(0xFFFFA726) : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentStreak > 0 ? "RACHA ACTIVA" : "RACHA INACTIVA",
                          style: TextStyle(
                            color: _currentStreak > 0 ? const Color(0xFFFFA726) : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$_currentStreak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _currentStreak == 1 ? "DÍA DE RACHA" : "DÍAS DE RACHA",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Record pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF221A13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFB300).withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RÉCORD',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '$displayMaxStreak DÍAS',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Middle Banner: Bolt message + Status badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFFD54F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTodayCompleted
                        ? "¡Increíble trabajo! Racha asegurada por hoy."
                        : (hasRoutineToday
                            ? "¡Entrena hoy para mantener tu racha viva!"
                            : "Día de descanso programado. ¡Tu racha está a salvo!"),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isTodayCompleted
                        ? primaryColor.withOpacity(0.18)
                        : (hasRoutineToday
                            ? const Color(0xFF262D20)
                            : Colors.white.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTodayCompleted
                          ? primaryColor.withOpacity(0.4)
                          : (hasRoutineToday
                              ? primaryColor.withOpacity(0.3)
                              : Colors.white.withOpacity(0.15)),
                    ),
                  ),
                  child: Text(
                    isTodayCompleted
                        ? "HOY\nCOMPLETADO"
                        : (hasRoutineToday ? "HOY\nPENDIENTE" : "DESCANSO"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isTodayCompleted || hasRoutineToday
                          ? const Color(0xFFAEE084)
                          : Colors.white70,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bottom section: ESTA SEMANA + Weekday buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESTA SEMANA',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$completedThisWeek / 7 DÍAS',
                style: const TextStyle(
                  color: Color(0xFFFFA726),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 7 days row: L, M, X, J, V, S, D
          Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final dayLetter = ['L', 'M', 'X', 'J', 'V', 'S', 'D'][i];
              final isCompleted = _completedDates.contains(day);
              final isToday = isSameDay(day, todayUtc);
              final hasScheduled = _getRoutinesForDay(day).isNotEmpty;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                      _focusedDay = day;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                      left: i == 0 ? 0 : 3,
                      right: i == 6 ? 0 : 3,
                    ),
                    height: 52,
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF17241A)
                          : (isCompleted
                              ? const Color(0xFF261812)
                              : Colors.white.withOpacity(0.025)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? primaryColor
                            : (isCompleted
                                ? const Color(0xFFD97706).withOpacity(0.45)
                                : Colors.white.withOpacity(0.06)),
                        width: isToday ? 1.8 : 1,
                      ),
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLetter,
                          style: TextStyle(
                            color: isToday
                                ? primaryColor
                                : (isCompleted
                                    ? const Color(0xFFFFA726)
                                    : Colors.white.withOpacity(0.35)),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isCompleted)
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 12),
                          )
                        else if (isToday)
                          Icon(
                            Icons.track_changes_rounded,
                            color: primaryColor,
                            size: 15,
                          )
                        else
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: hasScheduled
                                  ? const Color(0xFFFFA726).withOpacity(0.6)
                                  : Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    return Container(
      key: const ValueKey('month'),
      decoration: BoxDecoration(
        color: const Color(0xFF13181E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _getRoutinesForDay(day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              weekendTextStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF4ADE80), size: 24),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF4ADE80), size: 24),
              headerPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, date) {
                final monthName = "${_fullMonths[date.month - 1]} ${date.year}";
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261810),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              _currentStreak > 0 ? 'Racha activa' : 'Racha inactiva',
                              style: const TextStyle(
                                color: Color(0xFFFFA726),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              defaultBuilder: (context, date, _) => _buildCalendarDayCell(date),
              todayBuilder: (context, date, _) => _buildCalendarDayCell(date, isTodaySpecial: true),
              selectedBuilder: (context, date, _) => _buildCalendarDayCell(date, isSelectedSpecial: true),
            ),
          ),
          // Legend below calendar
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('🔥', 'Día en Racha'),
                _buildLegendDot(primaryColor, 'Hoy (Objetivo)'),
                _buildLegendDot(const Color(0xFFFFA726), 'Programado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell(
    DateTime date, {
    bool isTodaySpecial = false,
    bool isSelectedSpecial = false,
  }) {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    final isCompleted = _completedDates.contains(normalizedDate);
    final now = DateTime.now();
    final isToday = isSameDay(date, now);
    final routines = _getRoutinesForDay(date);
    final hasRoutine = routines.isNotEmpty;
    final isSelected = isSameDay(date, _selectedDay);

    Color? ringColor;
    if (isToday) {
      ringColor = primaryColor;
    } else if (isCompleted) {
      ringColor = const Color(0xFFD97706).withOpacity(0.5);
    } else if (isSelected) {
      ringColor = Colors.white.withOpacity(0.5);
    }

    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? (isCompleted ? primaryColor.withOpacity(0.2) : const Color(0xFF1E2B1E))
                  : (isCompleted
                      ? const Color(0xFF281912)
                      : (isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent)),
              border: ringColor != null
                  ? Border.all(color: ringColor, width: isToday ? 2.0 : 1.2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isToday
                        ? primaryColor
                        : (isCompleted
                            ? const Color(0xFFFFB74D)
                            : Colors.white),
                    fontWeight: isToday || isCompleted || isSelected
                        ? FontWeight.w900
                        : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (isCompleted && !isToday)
                  Positioned(
                    bottom: -3,
                    child: const Text('🔥', style: TextStyle(fontSize: 8)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Dot indicator
          if (isToday)
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFFA726),
                shape: BoxShape.circle,
              ),
            )
          else if (isCompleted)
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF2DD4BF),
                shape: BoxShape.circle,
              ),
            )
          else if (hasRoutine)
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFFA726),
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String iconText, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(iconText, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Calendario híbrido (Mensual / Semanal)
  // ---------------------------------------------------------------------------

  Widget _buildCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Calendario",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            _buildViewToggle(),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
          child: _isWeekView ? _buildWeekView() : _buildMonthCalendar(),
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip('Mensual', !_isWeekView, () {
            if (_isWeekView) setState(() => _isWeekView = false);
          }),
          _toggleChip('Semanal', _isWeekView, () {
            if (!_isWeekView) setState(() => _isWeekView = true);
          }),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? backgroundColor : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DateTime _startOfWeek(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - 1)); // lunes
  }

  String _weekRangeLabel(DateTime start, DateTime end) {
    final startMonth = _esMonths[start.month - 1];
    final endMonth = _esMonths[end.month - 1];
    if (start.month == end.month) {
      return '${start.day} - ${end.day} $endMonth';
    }
    return '${start.day} $startMonth - ${end.day} $endMonth';
  }

  Widget _buildWeekView() {
    final weekStart = _startOfWeek(_focusedDay);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final weekEnd = days.last;

    int totalScheduled = 0;
    int totalCompleted = 0;
    for (final d in days) {
      final routines = _getRoutinesForDay(d);
      totalScheduled += routines.length;
      totalCompleted += routines.where(_isRoutineCompleted).length;
    }
    final progress = totalScheduled == 0 ? 0.0 : totalCompleted / totalScheduled;

    return Container(
      key: const ValueKey('week'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Navegación de semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _weekNavButton(Icons.chevron_left, () {
                setState(() {
                  _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                });
              }),
              Column(
                children: [
                  Text(
                    _weekRangeLabel(weekStart, weekEnd),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    weekStart.year.toString(),
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
              _weekNavButton(Icons.chevron_right, () {
                setState(() {
                  _focusedDay = _focusedDay.add(const Duration(days: 7));
                });
              }),
            ],
          ),
          const SizedBox(height: 14),
          _buildWeeklyProgress(totalCompleted, totalScheduled, progress),
          const SizedBox(height: 6),
          ...days.map(_buildDayBlock),
        ],
      ),
    );
  }

  Widget _weekNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 22),
      ),
    );
  }

  Widget _buildWeeklyProgress(int completed, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PROGRESO SEMANAL",
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                total == 0 ? "Sin rutinas" : "$completed/$total rutinas",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0 ? Colors.greenAccent : primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBlock(DateTime day) {
    final routines = _getRoutinesForDay(day);
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, _selectedDay);
    final normalized = DateTime.utc(day.year, day.month, day.day);
    final isStreakDay = _completedDates.contains(normalized);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.10) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(0.6)
                : isToday
                    ? secondaryColor.withOpacity(0.6)
                    : Colors.white.withOpacity(0.06),
            width: (isSelected || isToday) ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pastilla de fecha
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    _esWeekdays[day.weekday - 1],
                    style: TextStyle(
                      color: isToday ? primaryColor : Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? primaryColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday ? null : Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isToday ? backgroundColor : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isStreakDay)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text('🔥', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: routines.isEmpty
                  ? _buildRestRow()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < routines.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _buildWeekEventCard(routines[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestRow() {
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.bedtime_outlined, color: Colors.white.withOpacity(0.25), size: 16),
          const SizedBox(width: 8),
          Text(
            'Día de descanso',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekEventCard(Map<String, dynamic> routine) {
    final workouts = routine['workouts'] as List<dynamic>? ?? [];
    final exerciseCount = workouts.fold<int>(
      0,
      (sum, w) => sum + (((w as Map)['exercises'] as List?)?.length ?? 0),
    );
    final isCompleted = _isRoutineCompleted(routine);
    final isMissed = _isRoutineMissed(routine);

    final Color statusColor = isCompleted
        ? Colors.greenAccent
        : isMissed
            ? Colors.redAccent
            : primaryColor;
    final String statusLabel = isCompleted
        ? 'Completada'
        : isMissed
            ? 'Pendiente'
            : 'Programada';
    final IconData statusIcon = isCompleted
        ? Icons.check_circle_rounded
        : isMissed
            ? Icons.error_outline_rounded
            : Icons.schedule_rounded;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de color (categoría/estado)
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (routine['name'] ?? 'Rutina').toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.fitness_center, color: Colors.white.withOpacity(0.4), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '$exerciseCount ejercicios',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(Map<String, dynamic> routine) {
    final workouts = routine['workouts'] as List<dynamic>? ?? [];
    final isCompleted = _isRoutineCompleted(routine);
    final isMissed = _isRoutineMissed(routine);
    final canStart = _canStartRoutine(routine);

    final List<_RoutineDisplayExercise> flattenedExercises = [];
    int exCounter = 1;
    int calculatedTotalSets = 0;

    for (var w in workouts) {
      if (w is! Map) continue;
      final setsStr = (w['sets'] ?? '3').toString();
      final setsInt = int.tryParse(setsStr) ?? 3;
      calculatedTotalSets += setsInt;

      final exerciseList = (w['exercises'] as List?) ?? [];
      if (exerciseList.isNotEmpty) {
        for (var ex in exerciseList) {
          if (ex is! Map) continue;
          flattenedExercises.add(
            _RoutineDisplayExercise(
              index: exCounter++,
              name: (ex['workoutName'] ?? ex['name'] ?? 'Ejercicio').toString(),
              workoutId: ex['workoutId']?.toString(),
              sets: setsStr,
              reps: (ex['reps'] ?? '10').toString(),
              weight: (ex['weight'] ?? '').toString(),
              description: (ex['description'] ?? ex['notes'] ?? '').toString(),
            ),
          );
        }
      } else if (w['workoutName'] != null || w['name'] != null) {
        flattenedExercises.add(
          _RoutineDisplayExercise(
            index: exCounter++,
            name: (w['workoutName'] ?? w['name'] ?? 'Ejercicio').toString(),
            workoutId: w['workoutId']?.toString(),
            sets: setsStr,
            reps: (w['reps'] ?? '10').toString(),
            weight: (w['weight'] ?? '').toString(),
            description: (w['description'] ?? w['notes'] ?? '').toString(),
          ),
        );
      }
    }

    final totalExercises = flattenedExercises.length;
    final totalSets = calculatedTotalSets;

    String muscleFocusStr = '';
    if (routine['muscleFocus'] is List) {
      muscleFocusStr = (routine['muscleFocus'] as List).map((e) => e.toString()).join(' & ');
    } else if (routine['muscleFocus'] != null && routine['muscleFocus'].toString().isNotEmpty) {
      muscleFocusStr = routine['muscleFocus'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF13191F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            (routine['name'] ?? 'Rutina').toString().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle: "5 ejercicios • 17 series totales • Pierna & Core"
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: '$totalExercises ejercicios'),
                const TextSpan(text: '  •  '),
                TextSpan(text: '$totalSets series totales'),
                if (muscleFocusStr.isNotEmpty) ...[
                  const TextSpan(text: '  •  '),
                  TextSpan(
                    text: muscleFocusStr,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Header "LISTA DE EJERCICIOS" / "DESLIZA PARA VER MÁS"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LISTA DE EJERCICIOS',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              if (flattenedExercises.length > 3)
                Text(
                  'DESLIZA PARA VER MÁS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Exercise list
          if (flattenedExercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay ejercicios registrados',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: flattenedExercises.length > 3 ? 320 : (flattenedExercises.length * 76.0),
              ),
              child: RawScrollbar(
                thumbColor: Colors.white.withOpacity(0.18),
                radius: const Radius.circular(4),
                thickness: 3,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: flattenedExercises.length > 3
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: flattenedExercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildExerciseItem(flattenedExercises[index]);
                  },
                ),
              ),
            ),
          // Plan de alimentación si existe
          if ((routine['nutritionPlanUrl'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            _buildNutritionPlanCard(routine['nutritionPlanUrl'] as String),
          ],
          const SizedBox(height: 18),
          // Bottom start routine button
          _buildStartRoutineButton(
            routine: routine,
            totalExercises: totalExercises,
            isCompleted: isCompleted,
            isMissed: isMissed,
            canStart: canStart,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(_RoutineDisplayExercise item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (item.workoutId != null)
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewWorkoutPage(workoutId: item.workoutId!),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${item.index}',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty || item.weight.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description.isNotEmpty
                            ? item.description
                            : (item.weight.isNotEmpty ? '${item.weight} kg' : ''),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.sets} × ${item.reps}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  if (item.weight.isNotEmpty && item.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${item.weight} kg',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionPlanCard(String url) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo abrir el enlace del plan de alimentación'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: secondaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: secondaryColor.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.file_download_rounded, color: secondaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAN DE ALIMENTACIÓN',
                    style: TextStyle(
                      color: secondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Descarga tu plan personalizado (PDF)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: secondaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStartRoutineButton({
    required Map<String, dynamic> routine,
    required int totalExercises,
    required bool isCompleted,
    required bool isMissed,
    required bool canStart,
  }) {
    final buttonColor = isCompleted
        ? Colors.white.withOpacity(0.12)
        : (!canStart
            ? Colors.white.withOpacity(0.08)
            : (isMissed ? const Color(0xFFFF5252) : primaryColor));

    final textColor = (isCompleted || !canStart)
        ? Colors.white70
        : const Color(0xFF11151C);

    final iconBgColor = (isCompleted || !canStart)
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFF11151C);

    final iconColor = (isCompleted || !canStart)
        ? Colors.white70
        : (isMissed ? const Color(0xFFFF5252) : primaryColor);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: (!isCompleted && canStart)
            ? [
                BoxShadow(
                  color: (isMissed ? const Color(0xFFFF5252) : primaryColor).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: buttonColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: (isCompleted || !canStart)
              ? null
              : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StartRoutinePage(
                        routine: routine,
                        routineId: routine['id'],
                      ),
                    ),
                  );

                  if (result == true) {
                    _fetchRoutines();
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCompleted
                        ? "RUTINA COMPLETADA"
                        : canStart
                            ? (isMissed ? "COMPLETAR RUTINA" : "EMPEZAR RUTINA")
                            : "NO DISPONIBLE",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$totalExercises ejer',
                  style: TextStyle(
                    color: textColor.withOpacity(0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }


   DateTime _normalizeDay(DateTime date) => DateTime.utc(date.year, date.month, date.day);

   /// Get the start of the current week (Monday)
   DateTime _getWeekStart() {
     final now = DateTime.now();
     final today = _normalizeDay(now);
     final daysToMonday = (today.weekday == DateTime.monday) ? 0 : (today.weekday - DateTime.monday);
     return today.subtract(Duration(days: daysToMonday));
   }

   /// Get the end of the current week (Sunday at 23:59:59)
   DateTime _getWeekEnd() {
     final now = DateTime.now();
     final today = _normalizeDay(now);
     final daysToSunday = (today.weekday == DateTime.sunday) ? 0 : (DateTime.sunday - today.weekday);
     return today.add(Duration(days: daysToSunday));
   }

   /// Check if a routine is in the current week (Monday-Sunday)
   bool _isRoutineInCurrentWeek(Map<String, dynamic> routine) {
     final ts = routine['date'] as Timestamp?;
     if (ts == null) return false;
     final routineDay = _normalizeDay(ts.toDate());
     final weekStart = _getWeekStart();
     final weekEnd = _getWeekEnd();
     return !routineDay.isBefore(weekStart) && !routineDay.isAfter(weekEnd);
   }

   bool _isRoutineCompleted(Map<String, dynamic> routine) {
     return _completedRoutineIds.contains((routine['id'] ?? '').toString());
   }

   bool _isRoutineMissed(Map<String, dynamic> routine) {
     final ts = routine['date'] as Timestamp?;
     if (ts == null) return false;
     final routineDay = _normalizeDay(ts.toDate());
     final today = _normalizeDay(DateTime.now());
     return routineDay.isBefore(today) && !_isRoutineCompleted(routine);
   }

   bool _canStartRoutine(Map<String, dynamic> routine) {
     final isCompleted = _isRoutineCompleted(routine);
     if (isCompleted) return false;

     // Permite iniciar cualquier rutina que esté en la semana actual (desbloqueo semanal)
     return _isRoutineInCurrentWeek(routine);
   }

   /// Check if a routine is within 24 hours of being completed (grace period)
   bool _isInGracePeriod(Map<String, dynamic> routine) {
     final logId = routine['id'] ?? '';
     if (logId.isEmpty) return false;

     // Check the completed routine logs
     // This will be updated when we fetch routine_logs
     // For now, return false - will be enhanced in the future
     return false;
   }

  Future<void> _openWhatsApp() async {
    const phone = '50769184836';
    final message = Uri.encodeComponent(
      'Hola! Mi membresía expiró y quiero renovarla. ¿Me puedes ayudar?',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  Widget _buildAccessBadge() {
    if (_isAccountActive) return const SizedBox.shrink();

    final dateText = _activeUntil == null
        ? 'No active plan'
        : "Expired on ${DateFormat('dd MMM yyyy').format(_activeUntil!)}";

    return GestureDetector(
      onTap: _openWhatsApp,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Account expired - $dateText. Toca para renovar por WhatsApp',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const Icon(Icons.chat_bubble_rounded, color: Colors.redAccent, size: 16),
          ],
        ),
      ),
    );
  }


}

class _RoutineDisplayExercise {
  final int index;
  final String name;
  final String? workoutId;
  final String sets;
  final String reps;
  final String weight;
  final String description;

  _RoutineDisplayExercise({
    required this.index,
    required this.name,
    this.workoutId,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.description,
  });
}
