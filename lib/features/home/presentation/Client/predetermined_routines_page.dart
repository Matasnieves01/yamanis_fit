import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/predetermined_routine_service.dart';
import 'package:yamanis_fit/models/predetermined_routine.dart';
import 'package:yamanis_fit/models/routine_request.dart';
import 'predetermined_routine_detail_page.dart';

class PredeterminedRoutinesPage extends StatefulWidget {
  const PredeterminedRoutinesPage({super.key});

  @override
  State<PredeterminedRoutinesPage> createState() => _PredeterminedRoutinesPageState();
}

class _PredeterminedRoutinesPageState extends State<PredeterminedRoutinesPage> {
  String _selectedLevel = 'all'; // 'all', 'Principiante', 'Intermedio', 'Avanzado'
  bool _hasActiveRoutine = false;
  bool _isCheckingStatus = true;
  RoutineRequest? _pendingRequest;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161D27);
  final Color surfaceColor = const Color(0xFF1F2937);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _checkClientStatus();
  }

  Future<void> _checkClientStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isCheckingStatus = false);
      return;
    }

    final hasActive = await PredeterminedRoutineService.userHasActiveRoutine(user.uid);
    final pending = await PredeterminedRoutineService.getPendingRequestForUser(user.uid);

    if (mounted) {
      setState(() {
        _hasActiveRoutine = hasActive;
        _pendingRequest = pending;
        _isCheckingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'RUTINAS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: cardColor,
        onRefresh: _checkClientStatus,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Banner informativo según el estado de la rutina del cliente
            SliverToBoxAdapter(
              child: _buildStatusBanner(),
            ),

            // Chips de filtrado por nivel
            SliverToBoxAdapter(
              child: _buildLevelFilterChips(),
            ),

            // Listado de programas
            _buildProgramsStream(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_isCheckingStatus) {
      return const SizedBox(height: 8);
    }

    if (_hasActiveRoutine) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rutina activa en curso',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tienes un plan asignado en tu Inicio. Para solicitar uno nuevo, debes completar tu plan actual.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_pendingRequest != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solicitud en revisión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pediste acceso a "${_pendingRequest!.routineName}". La entrenadora la revisará pronto.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(Icons.fitness_center_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Explora el catálogo de rutinas y solicita acceso al plan que desees para tu calendario.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelFilterChips() {
    final levels = [
      {'label': 'Todos', 'value': 'all'},
      {'label': 'Principiante', 'value': 'Principiante'},
      {'label': 'Intermedio', 'value': 'Intermedio'},
      {'label': 'Avanzado', 'value': 'Avanzado'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: levels.map((lvl) {
          final isSelected = _selectedLevel == lvl['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(lvl['label']!),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedLevel = lvl['value']!),
              backgroundColor: surfaceColor.withValues(alpha: 0.5),
              selectedColor: primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? backgroundColor : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.08),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgramsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predetermined_routines')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFAEE084)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'Error al cargar programas: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final routines = docs
            .map((doc) => PredeterminedRoutine.fromFirestore(doc))
            .where((r) {
              if (_selectedLevel == 'all') return true;
              return r.level.toLowerCase() == _selectedLevel.toLowerCase();
            })
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (routines.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center_outlined, size: 54, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay rutinas disponibles en este nivel',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pronto la entrenadora agregará nuevas rutinas a su catálogo.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildRoutineCard(routines[index]),
              childCount: routines.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoutineCard(PredeterminedRoutine routine) {
    final bool isThisPending = _pendingRequest?.predeterminedRoutineId == routine.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isThisPending
              ? Colors.orangeAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PredeterminedRoutineDetailPage(
                  routine: routine,
                  hasActiveRoutine: _hasActiveRoutine,
                  pendingRequest: _pendingRequest,
                ),
              ),
            );
            _checkClientStatus();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera / Portada del programa
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (routine.coverImageUrl.isNotEmpty)
                        Image.network(
                          routine.coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildHeaderPlaceholder(routine),
                        )
                      else
                        _buildHeaderPlaceholder(routine),

                      // Sombra degradada
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),

                      // Insignias flotantes en la imagen
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            routine.level.toUpperCase(),
                            style: TextStyle(
                              color: backgroundColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: routine.isFree
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.92)
                                    : const Color(0xFFD97706).withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                routine.isFree ? 'GRATIS' : '\$${routine.price.toStringAsFixed(2)} USD',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_rounded, color: primaryColor, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${routine.durationWeeks} Sem',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Text(
                          routine.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Contenido y detalles
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (routine.description.isNotEmpty) ...[
                      Text(
                        routine.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Métricas del plan
                    Row(
                      children: [
                        _buildMetric(Icons.repeat_rounded, '${routine.daysPerWeek} días/sem'),
                        const SizedBox(width: 14),
                        _buildMetric(Icons.flash_on_rounded, 'Intensidad ${routine.intensity}'),
                        const Spacer(),
                        if (routine.isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Gratis',
                              style: TextStyle(color: Color(0xFF81C784), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Text(
                            '\$${routine.price.toStringAsFixed(2)} USD',
                            style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                      ],
                    ),

                    if (routine.muscleFocus.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: routine.muscleFocus.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: surfaceColor.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Botón ver / solicitar
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PredeterminedRoutineDetailPage(
                                routine: routine,
                                hasActiveRoutine: _hasActiveRoutine,
                                pendingRequest: _pendingRequest,
                              ),
                            ),
                          );
                          _checkClientStatus();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isThisPending
                              ? Colors.orangeAccent
                              : _hasActiveRoutine
                                  ? surfaceColor
                                  : primaryColor,
                          foregroundColor: isThisPending || !_hasActiveRoutine ? backgroundColor : Colors.white70,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isThisPending
                                  ? Icons.hourglass_top_rounded
                                  : _hasActiveRoutine
                                      ? Icons.remove_red_eye_rounded
                                      : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isThisPending
                                  ? 'SOLICITUD ENVIADA'
                                  : _hasActiveRoutine
                                      ? 'VER DETALLES'
                                      : routine.isFree
                                          ? 'SOLICITAR GRATIS'
                                          : 'OBTENER • \$${routine.price.toStringAsFixed(2)} USD',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
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
    );
  }

  Widget _buildMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: primaryColor),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildHeaderPlaceholder(PredeterminedRoutine routine) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF263242), Color(0xFF131A24)],
        ),
      ),
      child: Center(
        child: Icon(Icons.fitness_center_rounded, size: 48, color: primaryColor.withValues(alpha: 0.3)),
      ),
    );
  }
}
