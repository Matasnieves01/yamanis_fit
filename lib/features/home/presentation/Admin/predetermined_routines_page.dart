import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';
import 'package:yamanis_fit/core/services/predetermined_routine_service.dart';
import 'package:yamanis_fit/models/predetermined_routine.dart';
import 'package:yamanis_fit/models/routine_request.dart';
import 'create_predetermined_routine_page.dart';

class PredeterminedRoutinesPage extends StatefulWidget {
  const PredeterminedRoutinesPage({super.key});

  @override
  State<PredeterminedRoutinesPage> createState() =>
      _PredeterminedRoutinesPageState();
}

class _PredeterminedRoutinesPageState extends State<PredeterminedRoutinesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161D27);
  final Color surfaceColor = const Color(0xFF1F2937);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteRoutine(PredeterminedRoutine routine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Eliminar Programa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás segura de eliminar "${routine.name}"? Los usuarios que ya lo tengan asignado no se verán afectados.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('predetermined_routines')
          .doc(routine.id)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promoción eliminada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  /// Proceso de aprobación con verificación estricta de rutina activa
  Future<void> _handleApproveRequest(RoutineRequest request) async {
    // 1. Obtener los detalles del programa solicitado
    final routineDoc = await FirebaseFirestore.instance
        .collection('predetermined_routines')
        .doc(request.predeterminedRoutineId)
        .get();

    if (!routineDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El programa solicitado ya no existe en la base de datos.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final routine = PredeterminedRoutine.fromFirestore(routineDoc);

    // 2. VALIDACIÓN ESTRICTA: ¿El usuario tiene su planilla completa?
    final hasCompletedSheet = await BiometricsService.hasCompletedDataSheet(request.userId);
    if (!hasCompletedSheet) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PLANILLA INCOMPLETA',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El cliente ${request.userName} (${request.userEmail}) aún no ha completado su planilla de medidas y antecedentes de salud obligatorios.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Por políticas de seguridad y prescripción de ejercicio, no es posible asignarle un plan hasta que el cliente ingrese sus medidas y antecedentes clínicos.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      return;
    }

    // 3. VALIDACIÓN ESTRICTA: ¿El usuario ya tiene una rutina asignada?
    final hasActive = await PredeterminedRoutineService.userHasActiveRoutine(request.userId);

    if (hasActive) {
      if (!mounted) return;
      // BLOQUEAR APROBACIÓN
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ASIGNACIÓN BLOQUEADA',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El cliente ${request.userName} (${request.userEmail}) ya tiene una rutina activa asignada en su calendario.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Por regla de entrenamiento, un usuario solo puede tener una rutina a la vez. No es posible asignarle un nuevo programa hasta que finalice sus sesiones actuales o se le retiren desde Clientes.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    // 3. Si NO tiene rutina activa, seleccionar fecha de inicio y aprobar
    DateTime startDate = DateTime.now();
    final bool? confirmApproval = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Aprobar y Asignar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asignar "${routine.name}" a ${request.userName}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Text(
                'Duración: ${routine.durationWeeks} semanas (${routine.daysPerWeek} días/semana)',
                style: TextStyle(color: primaryColor, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Fecha de inicio del plan:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(primary: primaryColor, surface: cardColor),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() => startDate = picked);
                  }
                },
                icon: Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                label: Text(
                  '${startDate.day}/${startDate.month}/${startDate.year}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
              ),
              child: const Text('ASIGNAR AL CALENDARIO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmApproval != true) return;

    try {
      final sessionsCount = await PredeterminedRoutineService.approveAndAssignRoutine(
        requestId: request.id,
        routine: routine,
        targetUserId: request.userId,
        targetUserName: request.userName,
        startDate: startDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Promoción asignada con éxito ($sessionsCount sesiones generadas en su calendario).'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleRejectRequest(RoutineRequest request) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rechazar Solicitud', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Deseas rechazar la solicitud de ${request.userName} para "${request.routineName}"?',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Motivo del rechazo (Opcional)',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('RECHAZAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PredeterminedRoutineService.rejectRoutineRequest(
        requestId: request.id,
        targetUserId: request.userId,
        routineName: request.routineName,
        reason: reasonController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'PROMOCIONES',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(text: 'MIS PROMOCIONES'),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('routine_requests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data?.docs.length ?? 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('SOLICITUDES'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('AGREGAR PROMOCIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePredeterminedRoutinePage()),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProgramsTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildProgramsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predetermined_routines')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_offer_outlined, size: 56, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'Aún no has creado promociones',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Agrega una promoción creando una rutina para que tus clientes puedan solicitarla y asignársela.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final routines = docs.map((d) => PredeterminedRoutine.fromFirestore(d)).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: routines.length,
          itemBuilder: (context, index) {
            final routine = routines[index];
            return _buildAdminRoutineCard(routine);
          },
        );
      },
    );
  }

  Widget _buildAdminRoutineCard(PredeterminedRoutine routine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    routine.level.toUpperCase(),
                    style: TextStyle(color: backgroundColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${routine.durationWeeks} semanas • ${routine.daysPerWeek} días/sem',
                  style: TextStyle(color: primaryColor.withValues(alpha: 0.8), fontSize: 12),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: cardColor,
                  onSelected: (val) {
                    if (val == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatePredeterminedRoutinePage(routineToEdit: routine),
                        ),
                      );
                    } else if (val == 'delete') {
                      _deleteRoutine(routine);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                          SizedBox(width: 8),
                          Text('Editar', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              routine.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (routine.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                routine.description,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '${routine.totalWorkoutsCount} ejercicios en total divididos en ${routine.days.length} días.',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('routine_requests')
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 54, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay solicitudes de programas',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cuando un cliente solicite un plan predeterminado, aparecerá aquí.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final requests = docs.map((d) => RoutineRequest.fromFirestore(d)).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return _buildRequestCard(req);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(RoutineRequest request) {
    final bool isPending = request.isPending;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? Colors.orangeAccent.withValues(alpha: 0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: surfaceColor,
                child: Text(
                  request.userName.isNotEmpty ? request.userName[0].toUpperCase() : 'U',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      request.userEmail,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? Colors.orangeAccent.withValues(alpha: 0.15)
                      : request.isApproved
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: isPending
                        ? Colors.orangeAccent
                        : request.isApproved
                            ? Colors.greenAccent
                            : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Programa solicitado: ${request.routineName}',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Botones de acción si está pendiente
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApproveRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Aprobar y Asignar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
