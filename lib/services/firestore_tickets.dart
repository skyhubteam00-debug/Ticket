import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTickets {
  FirestoreTickets._();
  static final instance = FirestoreTickets._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /* -------------------- USER SIDE -------------------- */

  Future<int> _nextTicketNumber() async {
    final snap = await _db
        .collection('tickets')
        .orderBy('ticketNumber', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 1;
    return (snap.docs.first['ticketNumber'] as int) + 1;
  }

  Future<int> createTicket({
    required String userId,
    required String email,
    required String service,
    required int priority,
  }) async {
    final ticketNumber = await _nextTicketNumber();

    await _db.collection('tickets').add({
      'ticketNumber': ticketNumber,
      'userId': userId,
      'email': email,
      'service': service,
      'priority': priority,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ticketNumber;
  }

  Future<int> peopleAhead({
    required int myTicket,
    required int myPriority,
  }) async {
    final snap = await _db
        .collection('tickets')
        .where('status', isEqualTo: 'waiting')
        .get();

    int count = 0;

    for (final d in snap.docs) {
      final p = d['priority'] as int;
      final t = d['ticketNumber'] as int;

      if (p < myPriority || (p == myPriority && t < myTicket)) {
        count++;
      }
    }

    return count;
  }

  /* -------------------- ADMIN SIDE -------------------- */

  /// Live stream of ALL tickets
  Stream<QuerySnapshot> watchTickets() {
    return _db
        .collection('tickets')
        .orderBy('priority')
        .orderBy('createdAt')
        .snapshots();
  }

  /// Get next ticket to be served
  Future<QueryDocumentSnapshot?> getNextWaiting() async {
    final snap = await _db
        .collection('tickets')
        .where('status', isEqualTo: 'waiting')
        .orderBy('priority')
        .orderBy('createdAt')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  /// Call a ticket (mark as serving)
  Future<void> callTicket(
    String docId, {
    required String calledBy,
  }) async {
    // mark all currently called tickets as done
    final current = await _db
        .collection('tickets')
        .where('status', isEqualTo: 'called')
        .get();

    for (final d in current.docs) {
      await d.reference.update({
        'status': 'done',
        'doneAt': FieldValue.serverTimestamp(),
      });
    }

    // mark selected ticket as called
    await _db.collection('tickets').doc(docId).update({
      'status': 'called',
      'calledAt': FieldValue.serverTimestamp(),
      'calledBy': calledBy,
    });
  }
}
