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

  Future<void> _duplicateRoutine(Map<String, dynamic> routine) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Duplicar Rutina', style: TextStyle(color: Colors.white)),
        content: const Text('¿Para quién quieres duplicar esta rutina?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'same'),
            child: Text('PARA ${widget.clientName.toUpperCase()}', style: TextStyle(color: primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'other'),
            child: const Text('OTRO CLIENTE...', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (choice == 'same') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateRoutinePage(
            clientId: widget.clientId,
            clientEmail: widget.clientEmail,
            initialRoutineData: routine,
          ),
        ),
      ).then((_) => _loadClientData());
    } else if (choice == 'other') {
      if (!mounted) return;
      final selectedClient = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _ClientPicker(
          backgroundColor: backgroundColor,
          surfaceColor: surfaceColor,
          primaryColor: primaryColor,
        ),
      );

      if (selectedClient != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateRoutinePage(
              clientId: selectedClient['id'],
              clientEmail: selectedClient['email'],
              initialRoutineData: routine,
            ),
          ),
        ).then((_) => _loadClientData());
      }
    }
  }

  void _showAdjustProgressDialog(Map<String, dynamic> routine, String routineId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final List<Map<String, dynamic>> workouts = (routine['workouts'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)).toList();

        // Controllers: for each workout -> for each exercise keep controllers for reps and weight
        final List<List<TextEditingController>> repsControllers = [];
        final List<List<TextEditingController>> weightControllers = [];

        for (var w in workouts) {
          final List exercises = (w['exercises'] as List?) ?? [w];
          final List<TextEditingController> repsRow = [];
          final List<TextEditingController> weightRow = [];
          for (var ex in exercises) {
            repsRow.add(TextEditingController(text: (ex['reps'] ?? '').toString()));
            weightRow.add(TextEditingController(text: (ex['weight'] ?? '').toString()));
          }
          repsControllers.add(repsRow);
          weightControllers.add(weightRow);
        }

        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Text('Ajustar Progreso - ${routine['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: workouts.length,
                      itemBuilder: (context, wi) {
                        final w = workouts[wi];
                        final exercises = (w['exercises'] as List?) ?? [w];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: surfaceColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: surfaceColor.withValues(alpha: 0.12))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Series: ${w['sets'] ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 8),
                              ...exercises.asMap().entries.map((entry) {
                                final exIdx = entry.key;
                                final ex = Map<String, dynamic>.from(entry.value as Map);
                                final repsCtrl = repsControllers[wi][exIdx];
                                final weightCtrl = weightControllers[wi][exIdx];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text((ex['workoutName'] ?? 'Ejercicio').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                        IconButton(
                                          icon: const Icon(Icons.refresh, color: Colors.white38, size: 18),
                                          onPressed: () {
                                            repsCtrl.text = (ex['reps'] ?? '').toString();
                                            weightCtrl.text = (ex['weight'] ?? '').toString();
                                            setModalState(() {});
                                          },
                                          tooltip: 'Restablecer a planeado',
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: repsCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(labelText: 'Reps', filled: true, fillColor: Colors.white.withValues(alpha: 0.03)),
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 110,
                                          child: TextFormField(
                                            controller: weightCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(labelText: 'Peso (kg)', filled: true, fillColor: Colors.white.withValues(alpha: 0.03)),
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCELAR', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Build updated workouts structure
                            try {
                              final messenger = ScaffoldMessenger.of(this.context);
                              final admin = FirebaseAuth.instance.currentUser;
                              if (admin == null) return;

                              final List<Map<String, dynamic>> updatedWorkouts = [];
                              for (var wi = 0; wi < workouts.length; wi++) {
                                final w = Map<String, dynamic>.from(workouts[wi]);
                                final List originalExercises = (w['exercises'] as List?) ?? [w];
                                final List<Map<String, dynamic>> newExercises = [];
                                for (var ei = 0; ei < originalExercises.length; ei++) {
                                  final ex = Map<String, dynamic>.from(originalExercises[ei] as Map);
                                  final String newReps = repsControllers[wi][ei].text.trim();
                                  final String newWeight = weightControllers[wi][ei].text.trim();
                                  if (newReps.isNotEmpty) ex['reps'] = newReps;
                                  if (newWeight.isNotEmpty) ex['weight'] = newWeight;
                                  newExercises.add(ex);
                                }
                                w['exercises'] = newExercises;
                                updatedWorkouts.add(w);
                              }

                              await FirebaseFirestore.instance.collection('routines').doc(routineId).update({
                                'workouts': updatedWorkouts,
                                'updatedAt': FieldValue.serverTimestamp(),
                                'updatedBy': admin.uid,
                              });

                              if (!mounted) return;
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              messenger.showSnackBar(const SnackBar(content: Text('Progreso ajustado correctamente'), backgroundColor: Colors.green));
                              await _loadClientData();
                            } catch (e) {
                              if (!mounted || !context.mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error ajustando progreso: $e'), backgroundColor: Colors.redAccent));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                          child: const Text('GUARDAR CAMBIOS'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
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
                 child: Align(
                   alignment: Alignment.centerRight,
                   child: Wrap(
                     spacing: 8,
                     runSpacing: 8,
                     alignment: WrapAlignment.end,
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
                         onPressed: () => _duplicateRoutine(routine),
                         icon: const Icon(Icons.copy_outlined, size: 18, color: Colors.cyanAccent),
                         label: const Text('Duplicar', style: TextStyle(color: Colors.cyanAccent)),
                       ),
                       TextButton.icon(
                         onPressed: () => _showAdjustProgressDialog(routine, routineId),
                         icon: const Icon(Icons.trending_up, size: 18, color: Colors.orangeAccent),
                         label: const Text('Ajustar Progreso', style: TextStyle(color: Colors.orangeAccent)),
                       ),
                       TextButton.icon(
                         onPressed: () => _deleteRoutine(routineId),
                         icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                         label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                       ),
                     ],
                   ),
                 ),
               ),
              ...workouts.map((workout) {
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      (workout['workoutName'] ?? 'Desconocido').toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${workout['sets'] ?? '-'} x ${workout['reps'] ?? '-'} @ ${workout['weight'] ?? '-'}kg',
                      style: TextStyle(color: primaryColor, fontSize: 12),
                    ),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountCard(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
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

                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
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
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rutinas para ${_selectedDay == null ? '-' : _formatDate(_selectedDay!)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      IconButton(
                        onPressed: _loadClientData,
                        icon: Icon(Icons.refresh, color: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildSelectedDayRoutines(),
                  const SizedBox(height: 24),
                  // DANGER ZONE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _ClientPicker extends StatefulWidget {
  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryColor;

  const _ClientPicker({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryColor,
  });

  @override
  State<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<_ClientPicker> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Seleccionar Cliente',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error', style: TextStyle(color: Colors.white)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final clients = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index].data() as Map<String, dynamic>;
                    final clientId = clients[index].id;
                    final name = client['name'] ?? 'Sin nombre';
                    final email = client['email'] ?? '';

                    return ListTile(
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(email, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () => Navigator.pop(context, {'id': clientId, 'email': email, 'name': name}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
