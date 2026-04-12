import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'create_routine_page.dart';

class ClientRoutinesPage extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientEmail;

  const ClientRoutinesPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
  });

  @override
  State<ClientRoutinesPage> createState() => _ClientRoutinesPageState();
}

class _ClientRoutinesPageState extends State<ClientRoutinesPage> {
  final Map<DateTime, List<Map<String, dynamic>>> _clientRoutines = {};
  final Set<String> _completedRoutineIds = {};

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isLoading = true;
  bool _isActivating = false;
  bool _isDeletingUser = false;

  bool _accountEnabled = false;
  DateTime? _activeUntil;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime.utc(now.year, now.month, now.day);
    _loadClientData();
  }

  DateTime _normalizeDay(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  bool get _isAccountActiveNow {
    if (!_accountEnabled || _activeUntil == null) return false;
    return _activeUntil!.isAfter(DateTime.now());
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);

    try {
      final routinesSnapshot = await FirebaseFirestore.instance
          .collection('routines')
          .where('clientId', isEqualTo: widget.clientId)
          .get();

      final logsSnapshot = await FirebaseFirestore.instance
          .collection('routine_logs')
          .where('userId', isEqualTo: widget.clientId)
          .get();

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.clientId)
          .get();

      final completedIds = <String>{};
      for (final logDoc in logsSnapshot.docs) {
        final logData = logDoc.data();
        final routineId = logData['routineId'];
        if (routineId is String && routineId.isNotEmpty) {
          completedIds.add(routineId);
        }
      }

      final Map<DateTime, List<Map<String, dynamic>>> routinesByDay = {};
      for (final doc in routinesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final Timestamp timestamp = data['date'];
        final normalizedDate = _normalizeDay(timestamp.toDate());
        routinesByDay.putIfAbsent(normalizedDate, () => []);
        routinesByDay[normalizedDate]!.add(data);
      }

      final userData = userSnapshot.data() ?? {};
      final activeUntilTs = userData['activeUntil'] as Timestamp?;

      if (!mounted) return;
      setState(() {
        _clientRoutines
          ..clear()
          ..addAll(routinesByDay);
        _completedRoutineIds
          ..clear()
          ..addAll(completedIds);
        _accountEnabled = userData['isActive'] == true;
        _activeUntil = activeUntilTs?.toDate();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando datos: $e')),
      );
    }
  }

  Future<void> _activateFor30Days() async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    setState(() => _isActivating = true);

    try {
      final activeUntil = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance.collection('users').doc(widget.clientId).set({
        'isActive': true,
        'activeUntil': Timestamp.fromDate(activeUntil),
        'activatedAt': FieldValue.serverTimestamp(),
        'activatedBy': admin.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta activada por 30 días')),
      );
      await _loadClientData();
      if (!mounted) return;
      setState(() => _isActivating = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error activando cuenta: $e')),
      );
      setState(() => _isActivating = false);
    }
  }

  Future<void> _handleDeleteUser() async {
    final passwordController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Confirmar Eliminación', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para eliminar a ${widget.clientName}, ingresa tu contraseña de administrador:',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Contraseña',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR USUARIO', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final password = passwordController.text;
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes ingresar la contraseña')));
        return;
      }

      setState(() => _isDeletingUser = true);

      try {
        // Re-authenticate admin
        final User? admin = FirebaseAuth.instance.currentUser;
        if (admin != null && admin.email != null) {
          AuthCredential credential = EmailAuthProvider.credential(
            email: admin.email!,
            password: password,
          );
          
          await admin.reauthenticateWithCredential(credential);
          
          // Delete from Firestore
          await FirebaseFirestore.instance.collection('users').doc(widget.clientId).delete();
          
          // Note: This only deletes the document. Full Auth deletion usually requires 
          // a Cloud Function for security, but we'll delete the profile first.
          
          if (mounted) {
            Navigator.pop(context); // Go back to clients list
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario eliminado correctamente')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de validación: Contraseña incorrecta o error de red')),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeletingUser = false);
      }
    }
  }

  bool _isRoutineCompleted(Map<String, dynamic> routine) {
    final id = (routine['id'] ?? '').toString();
    return _completedRoutineIds.contains(id);
  }

  bool _isRoutineMissed(Map<String, dynamic> routine) {
    final timestamp = routine['date'] as Timestamp?;
    if (timestamp == null) return false;
    final routineDay = _normalizeDay(timestamp.toDate());
    final today = _normalizeDay(DateTime.now());
    return routineDay.isBefore(today) && !_isRoutineCompleted(routine);
  }

  Future<void> _deleteRoutine(String routineId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: const Text('Esto eliminará la asignación de rutina para este cliente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('routines').doc(routineId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutina eliminada')),
      );
      await _loadClientData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error eliminando rutina: $e')),
      );
    }
  }

  Widget _buildAccountCard() {
    final now = DateTime.now();
    final isActive = _isAccountActiveNow;
    final daysLeft = _activeUntil == null
        ? 0
        : _activeUntil!.difference(DateTime(now.year, now.month, now.day)).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? primaryColor.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Acceso a la Cuenta',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? primaryColor.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'ACTIVO' : 'EXPIRADO',
                  style: TextStyle(
                    color: isActive ? primaryColor : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _activeUntil == null
                ? 'Sin período activo establecido.'
                : 'Activo hasta ${_formatDate(_activeUntil!)}${isActive ? ' ($daysLeft días restantes)' : ''}',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isActivating ? null : _activateFor30Days,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(isActive ? 'REACTIVAR POR 30 DÍAS' : 'ACTIVAR POR 30 DÍAS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayRoutines() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final routines = _clientRoutines[_selectedDay!] ?? [];
    if (routines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
        ),
        child: const Text(
          'No hay rutinas este día',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        final routineId = (routine['id'] ?? '').toString();
        final isCompleted = _isRoutineCompleted(routine);
        final isMissed = _isRoutineMissed(routine);
        final workouts = routine['workouts'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.greenAccent.withValues(alpha: 0.08)
                : isMissed
                    ? Colors.redAccent.withValues(alpha: 0.08)
                    : surfaceColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? Colors.greenAccent.withValues(alpha: 0.4)
                  : isMissed
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : surfaceColor.withValues(alpha: 0.2),
            ),
          ),
          child: ExpansionTile(
            iconColor: primaryColor,
            collapsedIconColor: Colors.white,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    (routine['name'] ?? 'Sin nombre').toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isCompleted)
                  const Text('✓', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                if (isMissed)
                  const Text('PERDIDA', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
              ],
            ),
            subtitle: Text(
              '${workouts.length} ejercicios ${isCompleted ? '- Completada' : isMissed ? '- Perdida' : '- Pendiente'}',
              style: TextStyle(
                color: isCompleted
                    ? Colors.greenAccent
                    : isMissed
                        ? Colors.redAccent
                        : Colors.white60,
                fontSize: 12,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateRoutinePage(
                              clientId: widget.clientId,
                              clientEmail: widget.clientEmail,
                              initialRoutineId: routineId,
                              initialRoutineData: routine,
                            ),
                          ),
                        ).then((_) => _loadClientData());
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteRoutine(routineId),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
              ...workouts.map((workout) {
                return ListTile(
                  dense: true,
                  title: Text(
                    (workout['workoutName'] ?? 'Desconocido').toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${workout['sets'] ?? '-'} x ${workout['reps'] ?? '-'} @ ${workout['weight'] ?? '-'}kg',
                    style: TextStyle(color: primaryColor, fontSize: 12),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.clientName),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateRoutinePage(
                              clientId: widget.clientId,
                              clientEmail: widget.clientEmail,
                            ),
                          ),
                        ).then((_) => _loadClientData());
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('CREAR NUEVA RUTINA', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: backgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: (day) => _clientRoutines[_normalizeDay(day)] ?? [],
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = _normalizeDay(selectedDay);
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(color: secondaryColor.withValues(alpha: 0.3), shape: BoxShape.circle),
                        defaultTextStyle: const TextStyle(color: Colors.white),
                        weekendTextStyle: const TextStyle(color: Colors.white70),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                              width: 7,
                              height: 7,
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
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rutinas para ${_selectedDay == null ? '-' : _formatDate(_selectedDay!)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        onPressed: _loadClientData,
                        icon: Icon(Icons.refresh, color: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSelectedDayRoutines(),
                  const SizedBox(height: 40),
                  // DANGER ZONE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ZONA DE PELIGRO',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Eliminar este usuario borrará permanentemente su perfil de la base de datos.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isDeletingUser ? null : _handleDeleteUser,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isDeletingUser 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                              : const Text('ELIMINAR USUARIO DEFINITIVAMENTE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
