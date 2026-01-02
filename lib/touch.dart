import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/* ================== FIRESTORE SERVICE ================== */

class FirestoreTickets {
  static final instance = FirestoreTickets._();
  FirestoreTickets._();

  final CollectionReference _tickets =
      FirebaseFirestore.instance.collection('tickets');

  /// Stream tickets in real-time
  Stream<QuerySnapshot> watchTickets() {
    return _tickets.orderBy('createdAt').snapshots();
  }

  /// Get next waiting ticket (priority → FIFO)
  Future<QueryDocumentSnapshot?> getNextWaiting() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _tickets
        .where('status', isEqualTo: 'waiting')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('createdAt')
        .orderBy('priority')
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  /// Call ticket, mark previous called as completed
  Future<void> callTicket(String docId, {required String calledBy}) async {
    final batch = FirebaseFirestore.instance.batch();

    // Complete current called tickets
    final active = await _tickets.where('status', isEqualTo: 'called').get();
    for (final d in active.docs) {
      batch.update(d.reference, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    // Call new ticket
    batch.update(_tickets.doc(docId), {
      'status': 'called',
      'calledAt': FieldValue.serverTimestamp(),
      'calledBy': calledBy,
    });

    await batch.commit();
  }
}

/* ================== APP ================== */

class TicketAdminApp extends StatelessWidget {
  const TicketAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      home: const AdminDashboard(),
    );
  }
}

/* ================== DASHBOARD ================== */

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  /// Call the next ticket in queue
  Future<void> _callNext() async {
    final next = await FirestoreTickets.instance.getNextWaiting();
    if (next != null) {
      await FirestoreTickets.instance.callTicket(next.id, calledBy: 'admin');
    }
  }

  /// Admin custom call
  Future<void> _callTicket(String docId) async {
    await FirestoreTickets.instance.callTicket(docId, calledBy: 'admin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Queue Control'),
        centerTitle: true,automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreTickets.instance.watchTickets(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final docs = snapshot.data!.docs;

          // Filter: only waiting tickets created today
          final waitingToday = docs.where((d) {
            final ts = d['createdAt'] as Timestamp?;
            if (ts == null) return false;
            final dt = ts.toDate();
            return d['status'] == 'waiting' &&
                dt.isAfter(startOfDay) &&
                dt.isBefore(startOfDay.add(const Duration(days: 1)));
          }).toList()
            ..sort(_queueSort);

          // Currently called ticket
          final called = docs.where((d) => d['status'] == 'called').toList()
            ..sort(_calledSort);

          final nowServing = called.isNotEmpty ? called.first['ticketNumber'] as int : null;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _NowServingCard(ticket: nowServing),
                const SizedBox(height: 20),
                _StatsBar(current: nowServing, waitingCount: waitingToday.length),
                const SizedBox(height: 20),
                Expanded(
                  child: _QueueList(docs: waitingToday, onCall: _callTicket),
                ),
                const SizedBox(height: 16),
                _NextButton(onPressed: _callNext),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _queueSort(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final pa = a['priority'] as int;
    final pb = b['priority'] as int;
    if (pa != pb) return pa.compareTo(pb);
    return (a['createdAt'] as Timestamp).toDate().compareTo((b['createdAt'] as Timestamp).toDate());
  }

  static int _calledSort(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    return (b['calledAt'] as Timestamp).toDate().compareTo((a['calledAt'] as Timestamp).toDate());
  }
}

/* ================== NOW SERVING ================== */

class _NowServingCard extends StatelessWidget {
  final int? ticket;

  const _NowServingCard({this.ticket});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        children: [
          const Text('NOW SERVING', style: TextStyle(letterSpacing: 1.4, color: Color.fromARGB(179, 255, 255, 255))),
          const SizedBox(height: 12),
          Text(ticket == null ? '--' : '#$ticket',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

/* ================== STATS ================== */

class _StatsBar extends StatelessWidget {
  final int? current;
  final int waitingCount;

  const _StatsBar({required this.current, required this.waitingCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Current', value: current == null ? '--' : '#$current', icon: Icons.confirmation_number),
        const SizedBox(width: 12),
        const SizedBox(width: 12),
        _StatCard(label: 'Status', value: 'Open', icon: Icons.circle, color: Colors.green),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _Surface(
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.white70),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style:TextStyle(color: Colors.white)    ),
                Text(value, style: TextStyle(color: Colors.white) ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ================== QUEUE ================== */

class _QueueList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final void Function(String) onCall;

  const _QueueList({required this.docs, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today\'s Waiting Queue', style: TextStyle(fontSize: 18, color: Color( 0xFFFFFFFF))),
          const SizedBox(height: 12),
          Expanded(
            child: docs.isEmpty
                ? const Center(child: Text('No waiting tickets today'))
                : ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i];
                      return _QueueTile(
                        index: i,
                        ticket: d['ticketNumber'],
                        service: d['service'],
                        priority: d['priority'],
                        onCall: () => onCall(d.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final int index;
  final int ticket;
  final String service;
  final int priority;
  final VoidCallback onCall;

  const _QueueTile({required this.index, required this.ticket, required this.service, required this.priority, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.indigo.withOpacity(0.25), child: Text(ticket.toString())),
      title: Text(service ,style: TextStyle(color: Colors.white),),
      subtitle: Text('Priority $priority • Position ${index + 1}'),
      trailing: FilledButton(onPressed: onCall, child: const Text('Call')),
    );
  }
}

/* ================== NEXT BUTTON ================== */

class _NextButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NextButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.skip_next_rounded),
        label: const Text('CALL NEXT', style: TextStyle(fontSize: 18)),
        onPressed: onPressed,
      ),
    );
  }
}

/* ================== SURFACE CARD ================== */

class _Surface extends StatelessWidget {
  final Widget child;

  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
