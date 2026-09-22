import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';
import 'package:yamanis_fit/core/services/predetermined_routine_service.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/features/home/presentation/Client/data_sheet_page.dart';
import 'package:yamanis_fit/features/home/presentation/Client/widgets/data_sheet_required_dialog.dart';
import 'package:yamanis_fit/models/predetermined_routine.dart';
import 'package:yamanis_fit/models/routine_request.dart';

class PredeterminedRoutineDetailPage extends StatefulWidget {
  final PredeterminedRoutine routine;
  final bool hasActiveRoutine;
  final RoutineRequest? pendingRequest;

  const PredeterminedRoutineDetailPage({
    super.key,
    required this.routine,
    required this.hasActiveRoutine,
    this.pendingRequest,
  });

  @override
  State<PredeterminedRoutineDetailPage> createState() =>
      _PredeterminedRoutineDetailPageState();
}

class _PredeterminedRoutineDetailPageState
    extends State<PredeterminedRoutineDetailPage> {
  bool _isRequesting = false;
  late bool _hasActive;
  RoutineRequest? _pending;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161D27);
  final Color surfaceColor = const Color(0xFF1F2937);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _hasActive = widget.hasActiveRoutine;
    _pending = widget.pendingRequest;
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return 'Día $weekday';
    }
  }

  Future<void> _handleRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Validación obligatoria: El usuario debe tener la planilla de datos completa
    final hasCompleted = await BiometricsService.hasCompletedDataSheet(user.uid);
    if (!hasCompleted) {
      if (!mounted) return;
      final fillNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DataSheetRequiredDialog(
          isForRoutineRequest: true,
        ),
      );

      if (fillNow == true && mounted) {
        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const DataSheetPage(isRequiredForRoutine: true),
          ),
        );
        if (completed != true) return;
      } else {
        return;
      }
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Solicitar Programa',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '¿Deseas solicitar a la entrenadora que te asigne "${widget.routine.name}" en tu calendario de entrenamiento?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('CONFIRMAR SOLICITUD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRequesting = true);

    try {
      await PredeterminedRoutineService.requestRoutine(
        userId: user.uid,
        userEmail: user.email ?? 'Sin correo',
        userName: user.displayName ?? user.email?.split('@').first ?? 'Cliente',
        routine: widget.routine,
      );

      if (!mounted) return;
      setState(() {
        _isRequesting = false;
        _pending = RoutineRequest(
          id: '${user.uid}_${widget.routine.id}',
          userId: user.uid,
          userEmail: user.email ?? '',
          userName: user.displayName ?? 'Cliente',
          predeterminedRoutineId: widget.routine.id,
          routineName: widget.routine.name,
          status: 'pending',
          requestedAt: DateTime.now(),
        );
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: primaryColor),
              const SizedBox(width: 8),
              Text('¡SOLICITUD ENVIADA!', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Tu entrenadora ha recibido la solicitud. Te notificaremos en cuanto revise tu perfil y la asigne a tu calendario.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: backgroundColor,
              ),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isThisPending = _pending?.predeterminedRoutineId == widget.routine.id;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Portada AppBar expandible
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: backgroundColor,
                elevation: 0,
                leading: const AppBackButton(),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.routine.coverImageUrl.isNotEmpty)
                        Image.network(
                          widget.routine.coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: cardColor),
                        )
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2B3A4E), Color(0xFF131A24)],
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.fitness_center_rounded, size: 64, color: primaryColor.withValues(alpha: 0.3)),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              backgroundColor,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Contenido
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Insignia de Nivel y Semanas
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.routine.level.toUpperCase(),
                              style: TextStyle(
                                color: backgroundColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.routine.durationWeeks} Semanas',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.routine.daysPerWeek} días/sem',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Título principal
                      Text(
                        widget.routine.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Descripción
                      if (widget.routine.description.isNotEmpty) ...[
                        Text(
                          widget.routine.description,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Grupos musculares
                      if (widget.routine.muscleFocus.isNotEmpty) ...[
                        const Text(
                          'Enfoque Muscular:',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.routine.muscleFocus.map((m) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                      ],

                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),

                      // Estructura de días y ejercicios
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: primaryColor, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'ESTRUCTURA DEL PROGRAMA',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (widget.routine.days.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Este programa incluye sesiones diseñadas semanalmente.',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        )
                      else
                        ...widget.routine.days.map((day) => _buildDayCard(day)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Barra inferior flotante de solicitud
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(isThisPending),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(PredeterminedDayPlan day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          collapsedIconColor: Colors.white54,
          iconColor: primaryColor,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fitness_center_rounded, color: primaryColor, size: 16),
          ),
          title: Text(
            day.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '${_weekdayName(day.targetWeekday)} • ${day.workouts.length} ejercicios',
            style: TextStyle(color: primaryColor.withValues(alpha: 0.8), fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (day.notes.isNotEmpty) ...[
                    Text(
                      'Instrucciones: ${day.notes}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...day.workouts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final w = entry.value;
                    final String name = (w['workoutName'] ?? w['name'] ?? 'Ejercicio ${index + 1}').toString();
                    final String sets = (w['sets'] ?? '').toString();
                    final String reps = (w['reps'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          if (sets.isNotEmpty || reps.isNotEmpty || (w['weight'] != null && (w['weight'] as String).isNotEmpty))
                            Text(
                              [
                                if (sets.isNotEmpty) '$sets series',
                                if (reps.isNotEmpty) '$reps reps',
                                if (w['weight'] != null && (w['weight'] as String).isNotEmpty) '${w['weight']} kg',
                              ].join(' • '),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
       ),
      ),
    );
  }

  Widget _buildBottomActionBar(bool isThisPending) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasActive) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tienes una rutina activa en tu calendario. No puedes solicitar otra hasta completarla.',
                        style: TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _hasActive || isThisPending || _isRequesting
                    ? null
                    : _handleRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: isThisPending ? Colors.orangeAccent : surfaceColor,
                  foregroundColor: backgroundColor,
                  disabledForegroundColor: isThisPending ? Colors.black : Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isRequesting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isThisPending
                                ? Icons.hourglass_top_rounded
                                : _hasActive
                                    ? Icons.lock_outline_rounded
                                    : Icons.send_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isThisPending
                                ? 'SOLICITUD PENDIENTE DE APROBACIÓN'
                                : _hasActive
                                    ? 'YA TIENES UNA RUTINA ACTIVA'
                                    : 'SOLICITAR PROMOCIÓN',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
