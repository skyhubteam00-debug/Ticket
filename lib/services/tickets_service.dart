class TicketsService {
  TicketsService._();
  static final TicketsService instance = TicketsService._();

  int _nextTicket = 1000;
  final List<int> _bookings = [];

  int bookTicket() {
    final t = _nextTicket++;
    _bookings.add(t);
    return t;
  }

  /// Book [count] tickets and return the generated ticket numbers.
  List<int> bookTickets(int count) {
    final List<int> result = [];
    for (var i = 0; i < count; i++) {
      result.add(bookTicket());
    }
    return result;
  }

  List<int> getBookings() => List.unmodifiable(_bookings);
}
