class SeatManager {
  SeatManager._private();

  static final SeatManager instance = SeatManager._private();

  // Stores active student seats
  final List<String> activeSeats = [];

  // Called when student scans card
  void markStudentDetected(String studentId) {
    if (!activeSeats.contains(studentId)) {
      activeSeats.add(studentId);
    }
  }
  bool isSeatActive(String seatId) {
    return activeSeats.contains(seatId);
  }
  // Optional: turn off seat
  void clearSeat(String studentId) {
    activeSeats.remove(studentId);
  }
}