import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yamanis_fit/features/home/presentation/Admin/create_routine_page.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  Stream<QuerySnapshot> getClients() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Clients")),

      body: StreamBuilder<QuerySnapshot>(
        stream: getClients(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final clients = snapshot.data!.docs;

          if (clients.isEmpty) {
            return const Center(child: Text("No clients found"));
          }

          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(client['email'] ?? 'No email'),

                trailing: ElevatedButton(
                  child: const Text("Create Routine"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateRoutinePage(
                          clientId: client.id,
                          clientEmail: client['email'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}