import 'package:flutter/material.dart';

void main() {
  runApp(const TicketAdminApp());
}

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

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int currentTicket = 42;
  final List<int> queue = List.generate(12, (i) => 43 + i);

  void nextTicket() {
    if (queue.isEmpty) return;
    setState(() => currentTicket = queue.removeAt(0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Admin Panel'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _NowServing(ticket: currentTicket),
              const SizedBox(height: 16),
              _StatsRow(
                currentTicket: currentTicket,
                queueLength: queue.length,
              ),
              const SizedBox(height: 16),
              Expanded(child: _QueueList(queue: queue)),
              const SizedBox(height: 16),
              _NextButton(onPressed: nextTicket),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- SURFACE -------------------- */

class _Surface extends StatelessWidget {
  final Widget child;

  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

/* -------------------- NOW SERVING -------------------- */

class _NowServing extends StatelessWidget {
  final int ticket;

  const _NowServing({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        children: [
          const Text(
            'NOW SERVING',
            style: TextStyle(letterSpacing: 1.2, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              '#$ticket',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- STATS -------------------- */

class _StatsRow extends StatelessWidget {
  final int currentTicket;
  final int queueLength;

  const _StatsRow({
    required this.currentTicket,
    required this.queueLength,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatItem(
            label: 'Current',
            icon: Icons.confirmation_number,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            label: 'Waiting',
            icon: Icons.people,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatItem(
            label: 'Status',
            icon: Icons.circle,
            color: Colors.green,
          ),
        ),
      ].asMap().entries.map((entry) {
        final index = entry.key;
        final widget = entry.value;

        if (widget is _StatItem) {
          return Expanded(
            child: _StatItem(
              label: widget.label,
              value: widget.label == 'Current'
                  ? '#$currentTicket'
                  : widget.label == 'Waiting'
                      ? queueLength.toString()
                      : 'Open',
              icon: widget.icon,
              color: widget.color,
            ),
          );
        }
        return widget;
      }).toList(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    this.value = '',
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.white70),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ],
      ),
    );
  }
}

/* -------------------- QUEUE LIST -------------------- */

class _QueueList extends StatelessWidget {
  final List<int> queue;

  const _QueueList({required this.queue});

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming Tickets', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: queue.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.withOpacity(0.25),
                  child: Text(queue[i].toString()),
                ),
                title: Text('Ticket #${queue[i]}'),
                subtitle: const Text('Normal priority'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- ACTION -------------------- */

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
        label: const Text('NEXT TICKET', style: TextStyle(fontSize: 18)),
        onPressed: onPressed,
      ),
    );
  }
}
