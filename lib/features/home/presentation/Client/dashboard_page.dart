import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'view_workout_page.dart';
import 'start_routine_page.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> _routines = {};
  final Set<String> _completedRoutineIds = {};
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

       if(!mounted) return;

      final userData = userDoc.data() ?? {};
      _userRole = (userData['role'] ?? 'user').toString().toLowerCase();

      final completedIds = <String>{};
      for (var logDoc in logsSnapshot.docs) {
        final logData = logDoc.data();
        final routineId = logData['routineId'];
        if (routineId != null) {
          completedIds.add(routineId);
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
      
      // Admin bypass: Admins are always active and don't need expiration dates
      final isAccountActive = _userRole == 'admin' || (isEnabled && (activeUntil == null || activeUntil.isAfter(DateTime.now())));

      setState(() {
        _routines.clear();
        _routines.addAll(newRoutines);
        _completedRoutineIds.clear();
        _completedRoutineIds.addAll(completedIds);
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // App Logo instead of text
                          Image.asset(
                            'assets/logos/logo.png',
                            height: 60,
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
                            onPressed: _fetchRoutines,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildMonthCalendar(),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Rutina del Dia",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (_selectedDay != null)
                            Text(
                              DateFormat('MMM dd').format(_selectedDay!),
                              style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                        ...routinesForSelectedDay.map((routine) => _buildProtocolCard(routine)).toList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMonthCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: surfaceColor.withOpacity(0.2)),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
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
            if (events.isEmpty) return null;
            final routines = events.cast<Map<String, dynamic>>();
            final anyMissed = routines.any((routine) => _isRoutineMissed(routine));
            final allCompleted = routines.every((routine) => _isRoutineCompleted(routine));

            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: anyMissed
                      ? Colors.redAccent
                      : allCompleted
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProtocolCard(Map<String, dynamic> routine) {
    final workouts = routine['workouts'] as List<dynamic>? ?? [];
    final isCompleted = _isRoutineCompleted(routine);
    final isMissed = _isRoutineMissed(routine);
    final canStart = _canStartRoutine(routine);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(32),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=1000&auto=format&fit=crop'),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
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
              tilePadding: const EdgeInsets.all(24),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTag("INTENSIDAD ALTA", primaryColor),
                      const SizedBox(width: 8),
                      _buildTag("POWER", secondaryColor),
                      if (isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildTag("✓ COMPLETADA", Colors.greenAccent),
                        ),
                      if (isMissed)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildTag("MISSED", Colors.redAccent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    (routine['name'] ?? 'Untitled').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1.0,
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
                              : "Protocolo enfocado en hipertrofia y potencia muscular.",
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.greenAccent.withOpacity(0.7)
                        : isMissed
                            ? Colors.redAccent.withOpacity(0.8)
                            : Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ),
              children: [
                ...workouts.map((workout) {
                  final exercises = (workout['exercises'] as List?) ?? [];
                  final isSuperset = exercises.length > 1;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: isSuperset ? Border.all(color: secondaryColor.withOpacity(0.3)) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSuperset)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildTag("SUPERSET", secondaryColor),
                          ),
                        Text(
                          'Sets: ${workout['sets'] ?? '0'}',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ...exercises.map((ex) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              ex['workoutName'] ?? 'Unknown Workout',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              'Reps: ${ex['reps'] ?? '0'} | ${ex['weight'] ?? '0'}kg',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                            ),
                            trailing: Icon(Icons.play_circle_fill, color: primaryColor),
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
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildStatInfo("WORKOUTS", "${workouts.length}"),
                          const SizedBox(width: 20),
                          _buildStatInfo("NIVEL", "ADV", color: primaryColor),
                        ],
                      ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _buildStatInfo(String label, String value, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
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

  Widget _buildAccessBadge() {
    if (_isAccountActive) return const SizedBox.shrink();

    final dateText = _activeUntil == null
        ? 'No active plan'
        : "Expired on ${DateFormat('dd MMM yyyy').format(_activeUntil!)}";

    return Container(
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
              'Account expired - $dateText',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
