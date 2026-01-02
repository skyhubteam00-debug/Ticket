import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_tickets.dart';
import 'login.dart';

const Map<String, int> servicePriority = {
  'Computer Purchase': 1,
  'Repair': 2,
  'Software Installation': 3,
  'General Inquiry': 4,
};

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  String _selectedService = servicePriority.keys.first;

  User? get user => FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot<Map<String, dynamic>>> get ticketsStream =>
      FirebaseFirestore.instance
          .collection('tickets')
          .where('userId', isEqualTo: user?.uid)
          .snapshots();

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _bookTicket() async {
    final priority = servicePriority[_selectedService]!;

    await FirestoreTickets.instance.createTicket(
      userId: user!.uid,
      email: user!.email ?? '',
      service: _selectedService,
      priority: priority,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Ticket Booked 🎟️'),
        content: Text('Your queue position updates in real time'),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Computer Shop Queue'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ticketsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text('No tickets yet'));
            }

            /// Split tickets
            final todayTickets = <Map<String, dynamic>>[];
            final pastTickets = <Map<String, dynamic>>[];

            for (final doc in docs) {
              final data = doc.data();
              final created =
                  (data['createdAt'] as Timestamp?)?.toDate();

              final isToday = created != null && _isToday(created);
              final isDone = data['status'] == 'done';

              if (isToday && !isDone) {
                todayTickets.add(data);
              } else {
                pastTickets.add(data);
              }
            }

            /// Build live waiting queue (TODAY only)
            final waiting = todayTickets
                .where((e) => e['status'] == 'waiting')
                .toList()
              ..sort((a, b) {
                if (a['priority'] != b['priority']) {
                  return a['priority'].compareTo(b['priority']);
                }
                return (a['createdAt'] as Timestamp)
                    .toDate()
                    .compareTo(
                        (b['createdAt'] as Timestamp).toDate());
              });

            return ListView(
              children: [
                if (todayTickets.isNotEmpty) ...[
                  const Text(
                    'Today',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  /// TODAY CARDS
                  ...todayTickets.map((d) {
                    final ticket = d['ticketNumber'] as int;
                    final service = d['service'] as String;
                    final status = d['status'] as String;

                    int position = -1;
                    if (status == 'waiting') {
                      position = waiting.indexWhere(
                              (e) => e['ticketNumber'] == ticket) +
                          1;
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Ticket #$ticket',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                _StatusChip(status: status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              service,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              status == 'waiting'
                                  ? 'Position: $position • Ahead: ${position - 1}'
                                  : status == 'called'
                                      ? 'Now Serving'
                                      : 'Completed',
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                ],

                if (pastTickets.isNotEmpty) ...[
                  const Text(
                    'Past Tickets',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  /// PAST TICKETS
                  ...pastTickets.map((d) {
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                          'Ticket #${d['ticketNumber']} — ${d['service']}'),
                      subtitle: const Text('Completed'),
                    );
                  }).toList(),
                ],

                const Divider(height: 32),

                /// BOOK NEW
                const Text(
                  'Book New Ticket',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _selectedService,
                  items: servicePriority.keys
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedService = v!),
                  decoration: const InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _bookTicket,
                    child: const Text('Take Ticket'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- STATUS CHIP ---------------- */

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case 'waiting':
        color = Colors.orange;
        text = 'Waiting';
        break;
      case 'called':
        color = Colors.green;
        text = 'Now Serving';
        break;
      default:
        color = Colors.grey;
        text = 'Completed';
    }

    return Chip(
      label: Text(text),
   
      labelStyle: TextStyle(color: color),
    );
  }
}
