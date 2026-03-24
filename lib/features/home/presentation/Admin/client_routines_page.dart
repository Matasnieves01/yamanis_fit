import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_routine_page.dart';

class ClientRoutinesPage extends StatelessWidget {
  final String clientId;
  final String clientName;
  final String clientEmail;

  const ClientRoutinesPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
  });

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color secondaryColor = const Color(0xFF89AC76);
  final Color primaryColor = const Color(0xFFAEE084);

  Stream<QuerySnapshot> getClientRoutines() {
    return FirebaseFirestore.instance
        .collection('routines')
        .where('clientId', isEqualTo: clientId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(clientName),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getClientRoutines(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white70)));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final routines = snapshot.data!.docs;
          routines.sort((a, b) {
            final DateTime dateA = (a['date'] as Timestamp).toDate();
            final DateTime dateB = (b['date'] as Timestamp).toDate();
            return dateB.compareTo(dateA);
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateRoutinePage(
                            clientId: clientId,
                            clientEmail: clientEmail,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("CREATE NEW ROUTINE", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: routines.isEmpty
                    ? const Center(child: Text("No routines assigned", style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: routines.length,
                        itemBuilder: (context, index) {
                          final routine = routines[index];
                          final data = routine.data() as Map<String, dynamic>;
                          final DateTime date = (data['date'] as Timestamp).toDate();
                          final String formattedDate = DateFormat('EEEE, MMM dd').format(date);
                          final List workouts = data['workouts'] ?? [];
                          final List<dynamic> muscleFocus = data['muscleFocus'] ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: surfaceColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: surfaceColor.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                data['name']?.toString().toUpperCase() ?? 'UNTITLED',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(formattedDate, style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  if (muscleFocus.isNotEmpty)
                                    Wrap(
                                      spacing: 4,
                                      children: muscleFocus.map((m) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: secondaryColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: secondaryColor.withOpacity(0.3)),
                                        ),
                                        child: Text(m.toString().toUpperCase(), style: TextStyle(color: secondaryColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                    ),
                                  const SizedBox(height: 8),
                                  Text("${workouts.length} Workouts", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.edit_note, color: primaryColor, size: 28),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateRoutinePage(
                                        clientId: clientId,
                                        clientEmail: clientEmail,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
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
}
