import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../models/course.dart';

class StudentSeatMapScreen extends StatefulWidget {
  final String userId;
  final String courseId;
  final String classId;
  final String courseTitle;
  final String courseCode;
  final Color accentColor;

  // Pass the live seat data from your seat leed page
  // Key = seat id (e.g. "A1"), Value = true if occupied by someone else
  final Map<String, bool> occupiedSeats;

  const StudentSeatMapScreen({
    super.key,
    required this.userId,
    required this.courseId,
    required this.classId,
    required this.courseTitle,
    required this.courseCode,
    required this.accentColor,
    required this.occupiedSeats,
  });

  @override
  State<StudentSeatMapScreen> createState() => _StudentSeatMapScreenState();
}

class _StudentSeatMapScreenState extends State<StudentSeatMapScreen>
    with SingleTickerProviderStateMixin {
  static const Color _surface = Color(0xFFF8F7F4);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _inkMuted = Color(0xFF888780);
  static const Color _green = Color(0xFF1D9E75);
  static const Color _greenLight = Color(0xFF5DCAA5);

  final List<String> _allSeats = [
    "A1",
    "A2",
    "A3",
    "A4",
    "A5",
    "B1",
    "B2",
    "B3",
    "B4",
    "B5",
    "C1",
    "C2",
    "C3",
    "C4",
    "C5",
    "D1",
    "D2",
    "D3",
    "D4",
    "D5",
    "E1",
    "E2",
    "E3",
    "E4",
    "E5",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
  ];

  // Seats occupied by OTHER students (from the seat leed system)
  late Map<String, bool> _occupiedSeats;

  String? _myBookedSeat; // this student's booked seat
  String? _pendingSeat; // tapped but not yet confirmed
  String? _reservationId;
  String? _resolvedClassId; // cached classId when widget.classId is not provided
  Future<void> _loadOccupiedSeats() async {
    try {
      final reservations = await _apiService.getStudentSeats(
        userId: widget.userId,
      );
      // This only loads current student's seats — we need all seats for the class
      // So call the class seats endpoint instead
      final response = await _apiService.getClassSeats(
        classId: widget.classId,
      );
      if (!mounted) return;
      final Map<String, bool> occupied = {};
      for (final r in response) {
        final seat = r['seatNumber']?.toString();
        final status = r['status']?.toString();
        if (seat != null && status != 'cancelled') {
          occupied[seat] = true;
        }
      }
      setState(() => _occupiedSeats = occupied);
    } catch (_) {}
  }
  final ApiService _apiService = ApiService();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _occupiedSeats = Map.from(widget.occupiedSeats);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadCurrentReservation();
    _loadOccupiedSeats();
    // Prepare resolved classId: prefer widget.classId when provided
    if (widget.classId.isNotEmpty) {
      _resolvedClassId = widget.classId;
    } else {
      // fetch in background; cached for future bookings
      _fetchAndStoreResolvedClassId();
    }
  }

  Future<void> _fetchAndStoreResolvedClassId() async {
    try {
      final Course course = await _apiService.getCourse(widget.courseId);
      if (course.classes.isNotEmpty) {
        final cid = course.classes.first.classId;
        if (cid != null && cid.isNotEmpty) {
          setState(() => _resolvedClassId = cid);
        }
      }
    } catch (_) {
      // ignore fetch errors — we'll attempt again when booking
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Seat state helpers ─────────────────────────────────────────────────────

  bool _isOccupied(String id) =>
      _occupiedSeats[id] == true && id != _myBookedSeat;

  bool _isMine(String id) => id == _myBookedSeat;

  bool _isPending(String id) => id == _pendingSeat;

  int get _emptyCount =>
      _allSeats.where((s) => !_isOccupied(s) && !_isMine(s)).length;

  int get _occupiedCount => _allSeats.where((s) => _occupiedSeats[s] == true).length;

  // ── Tap a seat ─────────────────────────────────────────────────────────────

  void _onSeatTap(String id) {
    if (_isOccupied(id)) {
      // Already taken — show message
      HapticFeedback.heavyImpact();
      _showTakenMessage(id);
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      if (_pendingSeat == id) {
        // Deselect
        _pendingSeat = null;
      } else {
        _pendingSeat = id;
      }
    });
  }

  void _showTakenMessage(String id) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Seat $id is already taken. Please choose another seat.",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD85A30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Confirm booking ────────────────────────────────────────────────────────

  void _confirmBooking() {
    if (_pendingSeat == null) return;
    HapticFeedback.mediumImpact();
    final seat = _pendingSeat!;
    final isCancelling = seat == _myBookedSeat;
    final isChanging = !isCancelling && _myBookedSeat != null && _myBookedSeat!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        seatId: seat,
        courseTitle: widget.courseTitle,
        isCancelling: isCancelling,
        isChanging: isChanging,
        onConfirm: () async {
          Navigator.pop(context);
          await _processBooking(seat, isCancelling);
        },
        onCancel: () {
          setState(() => _pendingSeat = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Gradient header (matches your app style)
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5DCAA5),
                  Color(0xFF9FE1CB),
                  Color(0xFFF0997B),
                  Color(0xFFD85A30),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),

          // Decorative blobs
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  // ── Header ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.courseTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.courseCode,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Stats pills ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _statPill(
                          Icons.event_seat_rounded,
                          "$_occupiedCount",
                          "Active",
                          _green,
                        ),
                        const SizedBox(width: 10),
                        _statPill(
                          Icons.chair_outlined,
                          "$_emptyCount",
                          "Empty",
                          Colors.white.withOpacity(0.80),
                        ),
                        if (_myBookedSeat != null) ...[
                          const SizedBox(width: 10),
                          _statPill(
                            Icons.person_pin_rounded,
                            _myBookedSeat!,
                            "My Seat",
                            const Color(0xFFFFE066),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── White sheet ───────────────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Drag pill
                          Container(
                            width: 30,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12, bottom: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // Title
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: Row(
                              children: [
                                Text(
                                  "Classroom Layout",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Seat grid ─────────────────────────────────
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                120,
                              ),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: _allSeats.length,
                                itemBuilder: (_, i) =>
                                    _buildSeatTile(_allSeats[i]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Legend bar (bottom) ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
              child: _pendingSeat != null
                  ? _buildConfirmButton()
                  : _buildLegend(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seat tile (matches your seat leed style exactly) ──────────────────────

  Widget _buildSeatTile(String id) {
    final bool occupied = _isOccupied(id);
    final bool mine = _isMine(id);
    final bool pending = _isPending(id);

    Color bgColor;
    Color iconColor;
    Color textColor;
    Color borderColor;
    String label;

    if (mine) {
      bgColor = _green;
      iconColor = Colors.white;
      textColor = Colors.white;
      borderColor = _green;
      label = "MINE";
    } else if (pending) {
      bgColor = _greenLight.withOpacity(0.25);
      iconColor = _green;
      textColor = _green;
      borderColor = _green;
      label = "SELECT";
    } else if (occupied) {
      bgColor = const Color(0xFFF1EFE8);
      iconColor = const Color(0xFFB4B2A9);
      textColor = const Color(0xFFB4B2A9);
      borderColor = const Color(0xFFE0DDD6);
      label = "TAKEN";
    } else {
      bgColor = const Color(0xFFF1EFE8);
      iconColor = const Color(0xFF888780);
      textColor = const Color(0xFF888780);
      borderColor = const Color(0xFFE0DDD6);
      label = "EMPTY";
    }

    return GestureDetector(
      onTap: () => _onSeatTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: (mine || pending)
              ? [
            BoxShadow(
              color: _green.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              occupied && !mine
                  ? Icons.person_rounded
                  : Icons.event_seat_rounded,
              size: 28,
              color: iconColor,
            ),
            const SizedBox(height: 4),
            Text(
              id,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: mine ? Colors.white : _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _legendItem(
          _green,
          Colors.white,
          Icons.person_rounded,
          "Student Detected",
        ),
        _legendItem(
          const Color(0xFFF1EFE8),
          _inkMuted,
          Icons.event_seat_rounded,
          "Empty Seat",
        ),
        _legendItem(
          _greenLight.withOpacity(0.25),
          _green,
          Icons.event_seat_rounded,
          "Selected",
        ),
      ],
    );
  }

  Widget _legendItem(Color bg, Color iconColor, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: iconColor.withOpacity(0.30)),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _inkMuted,
          ),
        ),
      ],
    );
  }

  Widget _statPill(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.80),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCurrentReservation() async {
    try {
      final reservations = await _apiService.getStudentSeats(
        userId: widget.userId,
      );
      if (!mounted) return;

      final active = reservations.firstWhere(
            (res) {
          final statusOk = (res["status"] == null || res["status"] != "cancelled");
          if (widget.classId.isNotEmpty) {
            return res["classId"] == widget.classId && statusOk;
          }
          // Fallback: match by courseId when classId was not provided
          return res["courseId"] == widget.courseId && statusOk;
        },
        orElse: () => <String, dynamic>{},
      );

      if (active.isNotEmpty) {
        setState(() {
          _myBookedSeat = active["seatNumber"]?.toString();
          _reservationId = active["reservationId"]?.toString();
        });
      } else {
        // No active reservation found on server — clear local reservation state
        setState(() {
          _myBookedSeat = null;
          _reservationId = null;
        });
      }
    } catch (_) {
      // ignore errors; keep local seat state functional
    }
  }

  Future<String> _resolveClassId() async {
    // Prefer widget.classId when available
    if (widget.classId.isNotEmpty) return widget.classId;

    // Use cached resolved classId if available
    if (_resolvedClassId != null && _resolvedClassId!.isNotEmpty) return _resolvedClassId!;

    // Otherwise fetch once and cache
    try {
      final Course course = await _apiService.getCourse(widget.courseId);
      if (course.classes.isNotEmpty) {
        final cid = course.classes.first.classId;
        if (cid != null && cid.isNotEmpty) {
          setState(() => _resolvedClassId = cid);
          return cid;
        }
      }
    } catch (_) {
      // ignore network/parse errors here — caller will handle empty result
    }
    return '';
  }
  Future<void> _processBooking(String seat, bool isCancelling) async {
    try {
      if (isCancelling) {
        if (_reservationId == null) {
          throw Exception('Reservation ID missing');
        }
        await _apiService.cancelStudentSeat(
          userId: widget.userId,
          reservationId: _reservationId!,
        );
        await _loadCurrentReservation();
        await _loadOccupiedSeats();
        setState(() {
          _pendingSeat = null;
        });
        _showSuccessSnackbar('Booking for seat $seat cancelled.');
        return;
      }

      if (_myBookedSeat == null) {
        if (widget.courseId.isEmpty) {
          _showErrorSnackbar('Course ID is missing');
          return;
        }

        final classIdToUse = await _resolveClassId();
        if (classIdToUse.isEmpty) {
          _showErrorSnackbar('Class ID not available for this course');
          return;
        }

        debugPrint('POST reserve -> courseId: ${widget.courseId}, classId: $classIdToUse, seatNumber: $seat');
        final reservation = await _apiService.createStudentSeat(
          userId: widget.userId,
          courseId: widget.courseId,
          classId: classIdToUse,
          seatNumber: seat,
        );
        await _loadOccupiedSeats();
        setState(() {
          _myBookedSeat = seat;
          _pendingSeat = null;
          _reservationId = reservation['reservationId']?.toString();
        });
        _showSuccessSnackbar('Seat $seat booked! ✓');
        return;
      }

      if (_reservationId == null) {
        throw Exception('Reservation ID missing');
      }
      await _apiService.updateStudentSeat(
        userId: widget.userId,
        reservationId: _reservationId!,
        seatNumber: seat,
      );
      await _loadCurrentReservation();
      await _loadOccupiedSeats();
      setState(() {
        _pendingSeat = null;
      });
      _showSuccessSnackbar('Seat changed to $seat.');
    } catch (error) {
      _showErrorSnackbar(error.toString());
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD85A30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Confirm booking button ─────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final isCancelling = _pendingSeat == _myBookedSeat;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isCancelling
              ? const LinearGradient(
            colors: [Color(0xFFD85A30), Color(0xFFEF9F27)],
          )
              : const LinearGradient(
            colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _confirmBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCancelling ? Icons.cancel_outlined : Icons.event_seat_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                isCancelling
                    ? "Cancel booking for seat $_pendingSeat"
                    : "Book seat $_pendingSeat",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confirm sheet ─────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  final String seatId;
  final String courseTitle;
  final bool isCancelling;
  final bool isChanging;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmSheet({
    required this.seatId,
    required this.courseTitle,
    required this.isCancelling,
    this.isChanging = false,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFF1D9E75);
    const Color danger = Color(0xFFD85A30);
    const Color ink = Color(0xFF1A1A2E);
    const Color muted = Color(0xFF888780);
    const Color surface = Color(0xFFF8F7F4);

    final Color actionColor = isCancelling ? danger : green;

    return Container(
      decoration: const BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag pill
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFD3D1C7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCancelling ? Icons.cancel_outlined : Icons.event_seat_rounded,
              color: actionColor,
              size: 30,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            isCancelling ? "Cancel Booking?" : (isChanging ? "Change Seat?" : "Confirm Seat Booking"),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            isCancelling
                ? "Release seat $seatId in $courseTitle?"
                : (isChanging
                ? "Change your seat to $seatId in $courseTitle?"
                : "Book seat $seatId in $courseTitle?\nYou can change it at any time."),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: muted, height: 1.6),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: const BorderSide(color: Color(0xFFD3D1C7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Go Back",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isCancelling ? "Cancel Booking" : (isChanging ? "Change Seat" : "Confirm"),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
