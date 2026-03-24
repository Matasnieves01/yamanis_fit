import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_routines_page.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Clients"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getClients(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final clients = snapshot.data!.docs;

          if (clients.isEmpty) {
            return const Center(
              child: Text("No clients found", style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final data = client.data() as Map<String, dynamic>;
              final String firstName = data['firstName'] ?? '';
              final String lastName = data['lastName'] ?? '';
              final String fullName = "$firstName $lastName".trim();
              final String email = data['email'] ?? 'No email';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: surfaceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: surfaceColor.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: secondaryColor.withOpacity(0.2),
                    child: Icon(Icons.person, color: secondaryColor),
                  ),
                  title: Text(
                    fullName.isNotEmpty ? fullName : email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  trailing: ElevatedButton(
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
                    ),
                    child: const Text("VIEW", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
