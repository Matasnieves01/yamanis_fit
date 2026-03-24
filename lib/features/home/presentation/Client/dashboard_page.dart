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
  bool _isLoading = true;

  // Updated Color Palette
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

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('routines')
          .where('clientId', isEqualTo: user.uid)
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> newRoutines = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // Store document ID
        final Timestamp timestamp = data['date'];
        final DateTime date = timestamp.toDate();
        // Normalize to UTC noon to avoid timezone shift issues when selecting days
        final DateTime normalizedDate = DateTime.utc(date.year, date.month, date.day);

        if (newRoutines[normalizedDate] == null) {
          newRoutines[normalizedDate] = [];
        }
        newRoutines[normalizedDate]!.add(data);
      }

      setState(() {
        _routines.clear();
        _routines.addAll(newRoutines);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching routines: $e");
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
                      // Top Bar (Simplified)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: surfaceColor.withOpacity(0.3),
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: primaryColor),
                            onPressed: _fetchRoutines,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Month Calendar Section
                      _buildMonthCalendar(),
                      const SizedBox(height: 40),
                      // Today's Protocol Title
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
                      // Protocol Cards
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
        eventLoader: _getRoutinesForDay,
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
            color: secondaryColor,
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
      ),
    );
  }

  Widget _buildProtocolCard(Map<String, dynamic> routine) {
    final workouts = routine['workouts'] as List<dynamic>? ?? [];

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
                  "Protocolo enfocado en hipertrofia y potencia muscular.",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ),
              children: [
                ...workouts.map((workout) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    title: Text(
                      workout['workoutName'] ?? 'Unknown Workout',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Sets: ${workout['sets']} | Reps: ${workout['reps']} | ${workout['weight']}kg',
                      style: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 13),
                    ),
                    trailing: Icon(Icons.play_circle_fill, color: primaryColor),
                    onTap: () {
                      if (workout['workoutId'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewWorkoutPage(
                              workoutId: workout['workoutId'],
                            ),
                          ),
                        );
                      }
                    },
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StartRoutinePage(
                                routine: routine,
                                routineId: routine['id'],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Text(
                            "EMPEZAR",
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
}
