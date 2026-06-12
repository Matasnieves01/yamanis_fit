import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_routines_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  Stream<QuerySnapshot> getClients() {
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

  Future<void> _cancelSubscription(String userId, String userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text("CANCELAR SUSCRIPCIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("¿Estás seguro de que deseas cancelar la suscripción de $userName? El usuario perderá el acceso premium de inmediato."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("VOLVER", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("CANCELAR AHORA", style: TextStyle(color: Colors.white)),
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
            const SnackBar(content: Text('Suscripción cancelada correctamente'), behavior: SnackBarBehavior.floating),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("CLIENTES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o correo...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: surfaceColor.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getClients(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }

                final allClients = snapshot.data!.docs;
                final filteredClients = allClients.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final firstName = (data['firstName'] ?? '').toString().toLowerCase();
                  final lastName = (data['lastName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final fullName = "$firstName $lastName";

                  return firstName.contains(_searchQuery) || 
                         lastName.contains(_searchQuery) || 
                         fullName.contains(_searchQuery) || 
                         email.contains(_searchQuery);
                }).toList();

                if (filteredClients.isEmpty) {
                  return const Center(
                    child: Text("Sin clientes encontrados", style: TextStyle(color: Colors.white70)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = filteredClients[index];
                    final data = client.data() as Map<String, dynamic>;
                    final String firstName = data['firstName'] ?? '';
                    final String lastName = data['lastName'] ?? '';
                    final String fullName = "$firstName $lastName".trim();
                    final String email = data['email'] ?? 'Sin correo';
                    final bool isEnabled = data['isActive'] == true;
                    final DateTime? activeUntil = (data['activeUntil'] as Timestamp?)?.toDate();
                    final bool isActiveNow = isEnabled && activeUntil != null && activeUntil.isAfter(DateTime.now());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: secondaryColor.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: secondaryColor),
                        ),
                        title: Text(
                          fullName.isNotEmpty ? fullName : email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActiveNow
                                    ? secondaryColor.withValues(alpha: 0.2)
                                    : Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActiveNow
                                      ? secondaryColor.withValues(alpha: 0.45)
                                      : Colors.redAccent.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                isActiveNow ? 'ACTIVO' : 'EXPIRADO',
                                style: TextStyle(
                                  color: isActiveNow ? secondaryColor : Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActiveNow)
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22),
                                tooltip: "Cancelar Suscripción",
                                onPressed: () => _cancelSubscription(client.id, fullName.isNotEmpty ? fullName : email),
                              ),
                            const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClientRoutinesPage(
                                      clientId: client.id,
                                      clientName: fullName.isNotEmpty ? fullName : email,
                                      clientEmail: email,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: backgroundColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text("VER", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
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
