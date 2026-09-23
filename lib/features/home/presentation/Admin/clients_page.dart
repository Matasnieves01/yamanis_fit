import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/models/user_data_sheet.dart';
import 'client_routines_page.dart';
import 'client_info_page.dart';
import 'client_tracking_sheet_page.dart';

enum ClientFilter { all, active, expired, pendingData }

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  ClientFilter _currentFilter = ClientFilter.all;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color cardColor = const Color(0xFF161F2C);
  final Color surfaceColor = const Color(0xFF1E2838);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color accentAmber = const Color(0xFFFFB74D);
  final Color accentRed = const Color(0xFFFF5252);

  Stream<QuerySnapshot<Map<String, dynamic>>> getClients() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isClientActive(Map<String, dynamic> data) {
    final bool isEnabled = data['isActive'] == true;
    final DateTime? activeUntil = (data['activeUntil'] as Timestamp?)?.toDate();
    return isEnabled && activeUntil != null && activeUntil.isAfter(DateTime.now());
  }

  bool _isDataSheetComplete(Map<String, dynamic> data, String userId) {
    if (data['dataSheet'] is Map) {
      final dsMap = Map<String, dynamic>.from(data['dataSheet']);
      final ds = UserDataSheet.fromMap(dsMap, userId);
      return ds.isComplete;
    }
    return data['hasCompletedDataSheet'] == true;
  }

  String _formatExpirationDate(DateTime? date) {
    if (date == null) return "Sin fecha";
    try {
      return DateFormat("d MMM yyyy", "es").format(date);
    } catch (_) {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  String _getInitials(String fullName, String email) {
    final trimmed = fullName.trim();
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(' ');
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return "${parts[0][0]}${parts[1][0]}".toUpperCase();
      }
      return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
    }
    if (email.isNotEmpty) {
      return email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
    }
    return "CL";
  }

  Future<void> _cancelSubscription(String userId, String userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text(
              "CANCELAR SUSCRIPCIÓN",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "¿Estás seguro de que deseas cancelar la suscripción de $userName? El usuario perderá el acceso a las rutinas de inmediato.",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("VOLVER", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("CANCELAR AHORA", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isActive': false,
          'activeUntil': null,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Suscripción cancelada correctamente'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  void _openClientInfo(String clientId, String clientName, String clientEmail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientInfoPage(
          clientId: clientId,
          clientName: clientName,
          clientEmail: clientEmail,
        ),
      ),
    );
  }

  void _openClientRoutines(String clientId, String clientName, String clientEmail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientRoutinesPage(
          clientId: clientId,
          clientName: clientName,
          clientEmail: clientEmail,
        ),
      ),
    );
  }

  void _openClientTrackingSheet(String clientId, String clientName, String clientEmail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientTrackingSheetPage(
          clientId: clientId,
          clientName: clientName,
          clientEmail: clientEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "CLIENTES",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getClients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar clientes: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Calcular métricas
          int activeCount = 0;
          int expiredCount = 0;
          int pendingDataCount = 0;

          for (final doc in allDocs) {
            final data = doc.data();
            final isActive = _isClientActive(data);
            final hasDataSheet = _isDataSheetComplete(data, doc.id);

            if (isActive) {
              activeCount++;
            } else {
              expiredCount++;
            }

            if (!hasDataSheet) {
              pendingDataCount++;
            }
          }

          // Filtrar por texto y por filtro seleccionado
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data();
            final firstName = (data['firstName'] ?? '').toString().toLowerCase();
            final lastName = (data['lastName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final fullName = "$firstName $lastName".trim();

            final matchesSearch = _searchQuery.isEmpty ||
                firstName.contains(_searchQuery) ||
                lastName.contains(_searchQuery) ||
                fullName.contains(_searchQuery) ||
                email.contains(_searchQuery);

            if (!matchesSearch) return false;

            final isActive = _isClientActive(data);
            final hasDataSheet = _isDataSheetComplete(data, doc.id);

            switch (_currentFilter) {
              case ClientFilter.all:
                return true;
              case ClientFilter.active:
                return isActive;
              case ClientFilter.expired:
                return !isActive;
              case ClientFilter.pendingData:
                return !hasDataSheet;
            }
          }).toList();

          return Column(
            children: [
              // 1. BARRA DE MÉTRICAS / KPIS RESUMEN
              _buildMetricsSummaryRow(
                total: allDocs.length,
                active: activeCount,
                expired: expiredCount,
                pending: pendingDataCount,
              ),

              const SizedBox(height: 10),

              // 2. BUSCADOR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre, apellido o correo...",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 3. CHIPS DE FILTRO RÁPIDO
              _buildFilterChips(
                total: allDocs.length,
                active: activeCount,
                expired: expiredCount,
                pending: pendingDataCount,
              ),

              const SizedBox(height: 6),

              // 4. LISTA DE CLIENTES
              Expanded(
                child: filteredDocs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data();
                          final firstName = data['firstName'] ?? '';
                          final lastName = data['lastName'] ?? '';
                          final fullName = "$firstName $lastName".trim();
                          final email = data['email'] ?? 'Sin correo';
                          final displayName = fullName.isNotEmpty ? fullName : email;
                          final isActive = _isClientActive(data);
                          final hasDataSheet = _isDataSheetComplete(data, doc.id);
                          final activeUntil = (data['activeUntil'] as Timestamp?)?.toDate();

                          return _buildClientCard(
                            clientId: doc.id,
                            fullName: fullName,
                            displayName: displayName,
                            email: email,
                            isActive: isActive,
                            hasDataSheet: hasDataSheet,
                            activeUntil: activeUntil,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildMetricsSummaryRow({
    required int total,
    required int active,
    required int expired,
    required int pending,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildKpiCard(
            title: "TOTAL",
            count: total,
            icon: Icons.people_alt_rounded,
            color: Colors.white,
            isSelected: _currentFilter == ClientFilter.all,
            onTap: () => setState(() => _currentFilter = ClientFilter.all),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: "ACTIVOS",
            count: active,
            icon: Icons.check_circle_outline_rounded,
            color: primaryColor,
            isSelected: _currentFilter == ClientFilter.active,
            onTap: () => setState(() => _currentFilter = ClientFilter.active),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: "EXPIRADOS",
            count: expired,
            icon: Icons.history_toggle_off_rounded,
            color: accentRed,
            isSelected: _currentFilter == ClientFilter.expired,
            onTap: () => setState(() => _currentFilter = ClientFilter.expired),
          ),
          const SizedBox(width: 8),
          _buildKpiCard(
            title: "FICHA PEND.",
            count: pending,
            icon: Icons.assignment_late_outlined,
            color: accentAmber,
            isSelected: _currentFilter == ClientFilter.pendingData,
            onTap: () => setState(() => _currentFilter = ClientFilter.pendingData),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "$count",
                    style: TextStyle(
                      color: isSelected ? color : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips({
    required int total,
    required int active,
    required int expired,
    required int pending,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(
            label: "Todos ($total)",
            isSelected: _currentFilter == ClientFilter.all,
            activeColor: Colors.white,
            onTap: () => setState(() => _currentFilter = ClientFilter.all),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: "Activos ($active)",
            isSelected: _currentFilter == ClientFilter.active,
            activeColor: primaryColor,
            onTap: () => setState(() => _currentFilter = ClientFilter.active),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: "Expirados ($expired)",
            isSelected: _currentFilter == ClientFilter.expired,
            activeColor: accentRed,
            onTap: () => setState(() => _currentFilter = ClientFilter.expired),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: "Ficha Pendiente ($pending)",
            isSelected: _currentFilter == ClientFilter.pendingData,
            activeColor: accentAmber,
            onTap: () => setState(() => _currentFilter = ClientFilter.pendingData),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? backgroundColor : Colors.white70,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: activeColor,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }

  Widget _buildClientCard({
    required String clientId,
    required String fullName,
    required String displayName,
    required String email,
    required bool isActive,
    required bool hasDataSheet,
    required DateTime? activeUntil,
  }) {
    final initials = _getInitials(fullName, email);
    final daysLeft = activeUntil == null
        ? 0
        : activeUntil.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? primaryColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openClientInfo(clientId, displayName, email),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Fila de Identidad y Menú
                Row(
                  children: [
                    // Avatar con iniciales
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isActive
                          ? primaryColor.withValues(alpha: 0.15)
                          : surfaceColor,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: isActive ? primaryColor : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Menú contextual
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: Colors.white.withValues(alpha: 0.6), size: 20),
                      color: surfaceColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (value) {
                        if (value == 'info') {
                          _openClientInfo(clientId, displayName, email);
                        } else if (value == 'routines') {
                          _openClientRoutines(clientId, displayName, email);
                        } else if (value == 'sheet') {
                          _openClientTrackingSheet(clientId, displayName, email);
                        } else if (value == 'cancel') {
                          _cancelSubscription(clientId, displayName);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'info',
                          child: Row(
                            children: [
                              Icon(Icons.accessibility_new_rounded, color: Colors.white70, size: 18),
                              SizedBox(width: 10),
                              Text("Ver Ficha & Esqueleto", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'routines',
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 18),
                              SizedBox(width: 10),
                              Text("Gestionar Rutinas", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'sheet',
                          child: Row(
                            children: [
                              Icon(Icons.table_chart_rounded, color: Color(0xFFF43F5E), size: 18),
                              SizedBox(width: 10),
                              Text("Tabla de Control & Series", style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        if (isActive)
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                                SizedBox(width: 10),
                                Text("Cancelar Suscripción", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Fila de Badges de Estado (Membresía + Ficha)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Badge Membresía
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? primaryColor.withValues(alpha: 0.12)
                            : accentRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? primaryColor.withValues(alpha: 0.3)
                              : accentRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.verified_rounded : Icons.cancel_outlined,
                            size: 12,
                            color: isActive ? primaryColor : accentRed,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isActive
                                ? 'ACTIVO (${daysLeft > 0 ? "$daysLeft días" : "Hoy"})'
                                : 'EXPIRADO',
                            style: TextStyle(
                              color: isActive ? primaryColor : accentRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge Ficha de Salud & Medidas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasDataSheet
                            ? secondaryColor.withValues(alpha: 0.15)
                            : accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasDataSheet
                              ? secondaryColor.withValues(alpha: 0.35)
                              : accentAmber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasDataSheet ? Icons.assignment_turned_in_rounded : Icons.assignment_late_outlined,
                            size: 12,
                            color: hasDataSheet ? secondaryColor : accentAmber,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasDataSheet ? 'FICHA COMPLETA' : 'FICHA PENDIENTE',
                            style: TextStyle(
                              color: hasDataSheet ? secondaryColor : accentAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vence el...
                    if (activeUntil != null && isActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          "Hasta ${_formatExpirationDate(activeUntil)}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Botones de Acción Rápida
                Row(
                  children: [
                    // Botón Ficha & Medidas
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openClientInfo(clientId, displayName, email),
                        icon: Icon(Icons.accessibility_new_rounded, color: primaryColor, size: 16),
                        label: Text(
                          "FICHA & MEDIDAS",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: primaryColor.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Botón Rutinas
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openClientRoutines(clientId, displayName, email),
                        icon: Icon(Icons.calendar_month_rounded, color: backgroundColor, size: 16),
                        label: Text(
                          "RUTINAS",
                          style: TextStyle(
                            color: backgroundColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 4. Botón Tabla de Registro & Contador Muscular (Plantilla Oficial)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openClientTrackingSheet(clientId, displayName, email),
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text(
                      "TABLA DE REGISTRO & CONTADOR MUSCULAR",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF881337),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search_rounded, color: primaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              "No se encontraron clientes",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No hay resultados para "$_searchQuery" con el filtro seleccionado.'
                  : 'No hay clientes en esta categoría actualmente.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty || _currentFilter != ClientFilter.all)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = "";
                    _searchController.clear();
                    _currentFilter = ClientFilter.all;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Restablecer Filtros"),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
          ],
        ),
      ),
    );
  }
}
