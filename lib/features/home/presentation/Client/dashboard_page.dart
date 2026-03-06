import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  //Example events for demonstration purposes
  final Map<DateTime, List<String>> _workoutEvents = {
    DateTime.utc(2024, 6, 10): ['Chest Dat'],
    DateTime.utc(2024, 6, 12): ['Leg Day'],
    DateTime.utc(2024, 6, 15): ['Back Day'],
  };
  List<String> _getWorkoutsForDay(DateTime day) {
    return _workoutEvents[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Column(
        children: [
          //RUTINA DEL DIA
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rutina del Día',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getWorkoutsForDay(_selectedDay ?? _focusedDay).isEmpty
                        ? 'No hay ejercicios programados para hoy.'
                        : _getWorkoutsForDay(_selectedDay ?? _focusedDay).join(', '),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          //CALENDARIO
          Padding(
              padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; // update `_focusedDay` here as well
                });
              },
            ),
          )),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: _getWorkoutsForDay(_selectedDay ?? _focusedDay)
                  .map((workout) => ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(workout),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}