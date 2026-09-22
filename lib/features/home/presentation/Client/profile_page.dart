import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yamanis_fit/features/auth/auth_service.dart';
import 'package:yamanis_fit/features/home/presentation/Client/data_sheet_page.dart';
import 'package:yamanis_fit/features/home/presentation/Client/widgets/body_scan_widget.dart';
import 'package:yamanis_fit/features/home/presentation/Client/widgets/quick_weight_dialog.dart';
import 'package:yamanis_fit/models/user_data_sheet.dart';
import 'settings_page.dart';
import 'help_support_page.dart';
import 'privacy_policy_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _displayName = "Cargando...";
  String _email = "";
  String _initials = "YF";
  String _planName = "Plan Atleta";
  bool _isPro = true;
  bool _hasBiometrics = false;
  UserBiometrics? _biometrics;
  bool _isLoading = true;

  final Color backgroundColor = const Color(0xFF0F141D);
  final Color surfaceColor = const Color(0xFF161F2C);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color accentPink = const Color(0xFFE91E63);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email = user.email ?? "";
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          final first = data['firstName'] as String? ?? '';
          final last = data['lastName'] as String? ?? '';
          final fullName = "$first $last".trim();

          _displayName = fullName.isNotEmpty ? fullName : (user.displayName ?? "Usuario");

          // Compute initials
          final parts = _displayName.split(' ').where((p) => p.isNotEmpty).toList();
          if (parts.length >= 2) {
            _initials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
          } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
            _initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
          }

          final biometricsMap = data['biometrics'] as Map<String, dynamic>?;
          if (biometricsMap != null) {
            _biometrics = UserBiometrics.fromMap(biometricsMap);
            _hasBiometrics = _biometrics?.isComplete == true ||
                data['hasCompletedDataSheet'] == true ||
                data['hasCompletedBiometrics'] == true;
          } else {
            _hasBiometrics = false;
            _biometrics = null;
          }

          final role = data['role']?.toString();
          final isActive = data['isActive'] == true;
          _isPro = role == 'admin' || isActive;

          final customPlan = data['planName']?.toString();
          if (customPlan != null && customPlan.isNotEmpty) {
            _planName = customPlan;
          } else if (_isPro) {
            _planName = "Plan Anual Atleta";
          } else {
            _planName = "Sin Plan Activo";
          }

          setState(() => _isLoading = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _displayName = "Usuario";
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleSignOut(BuildContext context) async {
    final authService = AuthService();
    await authService.signOut();
  }

  Future<void> _openDataSheet() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const DataSheetPage(),
      ),
    );

    if (result == true && mounted) {
      _loadUserData();
    }
  }

  void _openQuickWeightDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuickWeightDialog.show(
      context,
      userId: user.uid,
      currentWeight: _biometrics?.weight,
      onSaved: _loadUserData,
    );
  }

  String _formatWeightDate(DateTime? date) {
    if (date == null) return "Sin registro reciente";
    final now = DateTime.now();
    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    final timeStr = DateFormat("hh:mm a").format(date);

    if (isToday) {
      return "· Hoy, $timeStr";
    }
    return "· ${DateFormat("d MMM, hh:mm a", "es").format(date)}";
  }

  @override
  Widget build(BuildContext context) {
    final b = _biometrics;
    final weightDelta = b?.weightDelta;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/logos/logo.png',
          height: 32,
          errorBuilder: (context, error, stackTrace) => Text(
            'YP FIT',
            style: TextStyle(
              color: accentPink,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 18,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: surfaceColor.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                if (mounted) _loadUserData();
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ==============================
                  // HEADER: AVATAR CON ARO NEÓN Y PRO
                  // ==============================
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Circular Glowing Halo & Avatar
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFF18231C),
                            child: Text(
                              _initials,
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Camera Icon Button
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _openDataSheet,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // User Name + Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _displayName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.verified, color: primaryColor, size: 20),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Email
                  Text(
                    _email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==============================
                  // SECCIÓN: MEDIDAS CORPORALES & BIOMETRÍA
                  // ==============================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.accessibility_new_rounded, color: primaryColor, size: 18),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                "MEDIDAS Y BIOMETRÍA",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openDataSheet,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "Nueva Medida",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ==============================
                  // TARJETA: PESO ACTUAL
                  // ==============================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        // Left Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF132219),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Icon(Icons.scale_rounded, color: primaryColor, size: 26),
                        ),

                        const SizedBox(width: 14),

                        // Center Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    "PESO ACTUAL",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  if (weightDelta != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (weightDelta <= 0 ? primaryColor : Colors.orangeAccent).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            weightDelta < 0
                                                ? Icons.arrow_downward_rounded
                                                : Icons.arrow_upward_rounded,
                                            size: 10,
                                            color: weightDelta <= 0 ? primaryColor : Colors.orangeAccent,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${weightDelta > 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg",
                                            style: TextStyle(
                                              color: weightDelta <= 0 ? primaryColor : Colors.orangeAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    b?.weight != null ? b!.weight!.toStringAsFixed(1) : "--",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "kg",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _formatWeightDate(b?.updatedAt),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Right Action Button "Registrar"
                        ElevatedButton.icon(
                          onPressed: _openQuickWeightDialog,
                          icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                          label: const Text(
                            "Registrar",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2636),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==============================
                  // TARJETA: ESCANEO CORPORAL (ESQUELETO CON MÚSCULOS Y PESO)
                  // ==============================
                  BodyScanWidget(
                    biometrics: _biometrics,
                    onUpdatePressed: _openDataSheet,
                    onQuickWeightPressed: _openQuickWeightDialog,
                  ),

                  const SizedBox(height: 24),

                  // ==============================
                  // MENÚ DE OPCIONES DE CUENTA
                  // ==============================
                  _buildProfileOption(
                    icon: Icons.assignment_outlined,
                    title: "Ver / Editar Planilla de Datos",
                    onTap: _openDataSheet,
                  ),
                  _buildProfileOption(
                    icon: Icons.settings_outlined,
                    title: "Configuración",
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                      if (mounted) _loadUserData();
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.help_outline_rounded,
                    title: "Ayuda y Soporte",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HelpSupportPage()),
                    ),
                  ),
                  _buildProfileOption(
                    icon: Icons.privacy_tip_outlined,
                    title: "Política de Privacidad",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleSignOut(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        "CERRAR SESIÓN",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileOption({required IconData icon, required String title, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
          leading: Icon(icon, color: primaryColor, size: 20),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white.withValues(alpha: 0.25)),
          onTap: onTap,
        ),
      ),
    );
  }
}
