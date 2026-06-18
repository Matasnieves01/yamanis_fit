import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'view_workout_page.dart';
import 'package:yamanis_fit/features/home/presentation/Client/start_routine_page.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/core/widgets/branded_loading_screen.dart';

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
  final Set<String> _completedRoutineIds = {};
  final Set<DateTime> _completedDates = {};
  int _currentStreak = 0;
  bool _isAccountActive = true;
  DateTime? _activeUntil;
  bool _isLoading = true;
  String _userRole = 'user';

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

      setState(() {
        _routines.clear();
        _routines.addAll(newRoutines);
        _completedRoutineIds.clear();
        _completedRoutineIds.addAll(completedIds);
        _completedDates.clear();
        _completedDates.addAll(completedDates);
        _currentStreak = streak;
        _activeUntil = activeUntil;
        _isAccountActive = isAccountActive;
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
                      _buildStreakWidget(),
                      const SizedBox(height: 16),
                      _buildCalendarSection(),
                       const SizedBox(height: 20),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text(
                             "Rutina del Dia",
                             style: TextStyle(
                               color: Colors.white,
                               fontSize: 18,
                               fontWeight: FontWeight.bold,
                               letterSpacing: -0.5,
                             ),
                           ),
                          if (_selectedDay != null)
                            Text(
                              DateFormat('MMM dd').format(_selectedDay!),
                              style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold, fontSize: 13),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.2), secondaryColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '🔥',
              style: TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TU RACHA ACTUAL",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_currentStreak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Text(
                        _currentStreak == 1 ? "DÍA" : "DÍAS",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_currentStreak > 0) ...[
                Text(
                  _currentStreak >= 7 ? "¡IMPARABLE!" : (_currentStreak >= 3 ? "¡EXCELENTE!" : "¡SIGUE ASÍ!"),
                  style: TextStyle(
                    color: _currentStreak >= 7 ? primaryColor : (_currentStreak >= 3 ? Colors.greenAccent : Colors.orangeAccent),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.trending_up,
                  color: _currentStreak >= 7 ? primaryColor : (_currentStreak >= 3 ? Colors.greenAccent : Colors.orangeAccent),
                ),
              ] else ...[
                Text(
                  "INICIA HOY",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.bolt, color: Colors.white.withOpacity(0.3)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar() {
    return Container(
      key: const ValueKey('month'),
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceColor.withOpacity(0.2)),
      ),
      child: TableCalendar(
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
          todayDecoration: BoxDecoration(
            color: secondaryColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
          ),
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.white70),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
          rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final normalizedDate = DateTime.utc(date.year, date.month, date.day);
            final isCompletedDay = _completedDates.contains(normalizedDate);
            
            return Stack(
              children: [
                if (isCompletedDay)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: const Text(
                      '🔥',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                if (events.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: events.cast<Map<String, dynamic>>().any((r) => _isRoutineMissed(r))
                              ? Colors.redAccent
                              : events.cast<Map<String, dynamic>>().every((r) => _isRoutineCompleted(r))
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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

     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=1000&auto=format&fit=crop'),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, backgroundColor.withOpacity(0.9)],
            ),
          ),
           child: Theme(
             data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
             child: ExpansionTile(
               iconColor: primaryColor,
               collapsedIconColor: Colors.white,
               tilePadding: const EdgeInsets.all(16),
               title: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       _buildTag("${workouts.length} EJERCICIOS", primaryColor),
                       if (isCompleted)
                         Padding(
                           padding: const EdgeInsets.only(left: 6),
                           child: _buildTag("✓ COMPLETADA", Colors.greenAccent),
                         ),
                       if (isMissed)
                         Padding(
                           padding: const EdgeInsets.only(left: 6),
                           child: _buildTag("MISSED", Colors.redAccent),
                         ),
                     ],
                   ),
                   const SizedBox(height: 10),
                   Text(
                     (routine['name'] ?? 'Untitled').toUpperCase(),
                     style: const TextStyle(
                       color: Colors.white,
                       fontSize: 19,
                       fontWeight: FontWeight.w900,
                       height: 1.1,
                       letterSpacing: -0.5,
                     ),
                   ),
                 ],
               ),
               subtitle: Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(
                   isCompleted
                       ? "Esta rutina ya ha sido completada"
                       : isMissed
                           ? "Rutina pendiente (Pasada)"
                           : !canStart
                               ? "Solo puedes iniciar esta rutina en su dia programado"
                               : "Toca para ver los ejercicios",
                   style: TextStyle(
                     color: isCompleted
                         ? Colors.greenAccent.withOpacity(0.7)
                         : isMissed
                             ? Colors.redAccent.withOpacity(0.8)
                             : Colors.white.withOpacity(0.7),
                     fontSize: 12,
                   ),
                 ),
               ),
               children: [
                 // Mostrar PDF de plan de alimentación si existe
                 if ((routine['nutritionPlanUrl'] as String?)?.isNotEmpty ?? false)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: GestureDetector(
                       onTap: () async {
                         final url = routine['nutritionPlanUrl'] as String;
                         if (await canLaunchUrl(Uri.parse(url))) {
                           await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                         } else {
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(
                                 content: Text('No se pudo abrir el enlace'),
                                 backgroundColor: Colors.redAccent,
                               ),
                             );
                           }
                         }
                       },
                       child: Container(
                         width: double.infinity,
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: secondaryColor.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: secondaryColor.withOpacity(0.3)),
                         ),
                         child: Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(
                                 color: secondaryColor.withOpacity(0.2),
                                 borderRadius: BorderRadius.circular(10),
                               ),
                               child: Icon(Icons.file_download_rounded, color: secondaryColor, size: 24),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     'PLAN DE ALIMENTACIÓN',
                                     style: TextStyle(
                                       color: secondaryColor,
                                       fontWeight: FontWeight.bold,
                                       fontSize: 12,
                                       letterSpacing: 0.5,
                                     ),
                                   ),
                                   const SizedBox(height: 4),
                                   Text(
                                     'Descarga tu plan personalizado',
                                     style: TextStyle(
                                       color: Colors.white.withOpacity(0.7),
                                       fontSize: 12,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             Icon(Icons.open_in_new, color: secondaryColor, size: 20),
                           ],
                         ),
                       ),
                     ),
                   ),
                  // Ejercicios compactos
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EJERCICIOS',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...workouts.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final workout = entry.value;
                          final exercises = (workout['exercises'] as List?) ?? [];

                          return Column(
                            children: [
                              ...exercises.map((ex) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    onTap: (isCompleted || !canStart)
                                        ? null
                                        : () {
                                            if (ex['workoutId'] != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ViewWorkoutPage(
                                                    workoutId: ex['workoutId'],
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ex['workoutName'] ?? 'Unknown',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "${workout['sets'] ?? '0'}x${ex['reps'] ?? '0'}",
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (!isCompleted && canStart) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.chevron_right, color: primaryColor, size: 16),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              if (idx < workouts.length - 1) const SizedBox(height: 8),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  Padding(
                   padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       GestureDetector(
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
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                           decoration: BoxDecoration(
                             color: (isCompleted || !canStart) ? Colors.grey : (isMissed ? Colors.redAccent : primaryColor),
                             borderRadius: BorderRadius.circular(12),
                             boxShadow: [
                               BoxShadow(
                                 color: ((isCompleted || !canStart) ? Colors.grey : (isMissed ? Colors.redAccent : primaryColor)).withOpacity(0.3),
                                 blurRadius: 15,
                                 offset: const Offset(0, 5),
                               )
                             ],
                           ),
                           child: Text(
                             isCompleted
                                 ? "COMPLETADA"
                                 : canStart
                                     ? (isMissed ? "COMPLETAR" : "EMPEZAR")
                                     : "NO DISPONIBLE",
                             style: TextStyle(
                               color: backgroundColor,
                               fontWeight: FontWeight.w900,
                               fontSize: 12,
                               letterSpacing: 0.5,
                             ),
                           ),
                         ),
                       ),
                     ],
                   ),
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

    final ts = routine['date'] as Timestamp?;
    if (ts == null) return false;
    final routineDay = _normalizeDay(ts.toDate());
    final today = _normalizeDay(DateTime.now());

    return !routineDay.isAfter(today);
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
