import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticket/services/localnotification.dart';

const Map<String, int> servicePriority = {
  'Computer Purchase': 1,
  'Repair': 2,
  'Software Installation': 3,
  'General Inquiry': 4,
};

class TicketTab extends StatefulWidget {
  const TicketTab({super.key});

  @override
  State<TicketTab> createState() => _TicketTabState();
}

class _TicketTabState extends State<TicketTab> {
  String _selectedService = servicePriority.keys.first;
  User? get user => FirebaseAuth.instance.currentUser;

  // Store previous ticket statuses to detect changes
  Map<int, String> previousStatuses = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> get ticketsStream =>
      FirebaseFirestore.instance
          .collection('tickets')
          .orderBy('createdAt', descending: true)
          .snapshots();

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _bookTicket() async {
    if (user == null) return;

    final priority = servicePriority[_selectedService]!;

    await FirebaseFirestore.instance.collection('tickets').add({
      'userId': user!.uid,
      'email': user!.email ?? '',
      'service': _selectedService,
      'priority': priority,
      'ticketNumber': DateTime.now().millisecondsSinceEpoch % 10000,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Ticket Booked 🎟️'),
        content: Text('Your queue position updates in real time'),
      ),
    );
  }

  /// Build tickets list for TODAY
  Widget _todayTicketsWidget(List<Map<String, dynamic>> allTickets) {
    final waitingToday = allTickets.where((t) {
      final created = (t['createdAt'] as Timestamp?)?.toDate();
      return created != null &&
          _isToday(created) &&
          t['status'] == 'waiting';
    }).toList();

    waitingToday.sort((a, b) =>
        (a['createdAt'] as Timestamp).toDate().compareTo(
            (b['createdAt'] as Timestamp).toDate()));

    final userTodayTickets = allTickets.where((t) {
      final created = (t['createdAt'] as Timestamp?)?.toDate();
      return created != null &&
          _isToday(created) &&
          t['userId'] == user?.uid;
    }).toList();

    if (userTodayTickets.isEmpty) {
      return const Center(child: Text('No tickets today'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: userTodayTickets.map((d) {
        final ticket = d['ticketNumber'] as int;
        final service = d['service'] as String;
        final status = d['status'] as String;

        int position = -1;
        int aheadCount = 0;

        if (status == 'waiting') {
          position = waitingToday.indexWhere((e) => e['ticketNumber'] == ticket) + 1;
          aheadCount = position - 1;
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
                    Text('Ticket #$ticket',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _StatusChip(status: status, priority: d['priority']),
                  ],
                ),
                const SizedBox(height: 8),
                Text(service, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(status == 'waiting'
                    ? 'Position: $position • Ahead: $aheadCount total'
                    : status == 'called'
                        ? 'Now Serving'
                        : 'Completed'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Listen to ticket status changes to send notifications
  void _handleTicketNotifications(List<Map<String, dynamic>> tickets) {
    for (final ticket in tickets) {
      final ticketNumber = ticket['ticketNumber'] as int;
      final status = ticket['status'] as String;

      final prevStatus = previousStatuses[ticketNumber];

      // Trigger notification only if status changed to "called"
      if (prevStatus != 'called' && status == 'called') {
        TicketNotificationService.instance.notifyTicketCalled(ticketNumber: ticketNumber);
      }

      previousStatuses[ticketNumber] = status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final allTickets = docs.map((d) => d.data()).toList();

        // Check for ticket notifications
        _handleTicketNotifications(allTickets);

        return Column(
          children: [
            Expanded(child: _todayTicketsWidget(allTickets)),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Book New Ticket',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedService,
                    items: servicePriority.keys
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedService = v!),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final int? priority;

  const _StatusChip({required this.status, this.priority});

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

    final displayText = priority != null ? '$text • Priority: $priority' : text;

    return Chip(label: Text(displayText), labelStyle: TextStyle(color: color));
  }
}
