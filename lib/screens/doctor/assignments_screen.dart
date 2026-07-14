import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../models/assignment.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
// ─── Submission model (inline – move to models/ if preferred) ────────────────
class AssignmentSubmission {
  final String submissionId;
  final String assignmentId;
  final String studentId;
  final String studentName;
  final String? pdfBase64;
  final String? pdfUrl;
  final String? comment;
  final double? grade;
  final String? feedback;
  final DateTime submittedAt;

  const AssignmentSubmission({
    required this.submissionId,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.pdfBase64,
    this.pdfUrl,
    this.comment,
    this.grade,
    this.feedback,
    required this.submittedAt,
  });

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmission(
      submissionId: json['submissionId'] ?? '',
      assignmentId: json['assignmentId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? 'Unknown',
      pdfBase64: json['pdfBase64'],
      pdfUrl: json['pdfUrl'],
      comment: json['comment'],
      grade: json['grade'] != null ? (json['grade'] as num).toDouble() : null,
      feedback: json['feedback'],
      submittedAt: DateTime.tryParse(json['submittedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class AssignmentsScreen extends StatefulWidget {
  final String courseId;
  final String classId;
  final String className;
  final String courseTitle;

  const AssignmentsScreen({
    super.key,
    required this.courseId,
    required this.classId,
    required this.className,
    required this.courseTitle,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  final ApiService _apiService = ApiService();
  List<Assignment> _assignments = [];
  bool _loading = true;
  String? _error;

  // Tracks which assignment card is expanded to show submissions
  final Set<String> _expandedAssignments = {};
  // Cache: assignmentId → submissions list
  final Map<String, List<AssignmentSubmission>> _submissionsCache = {};
  // Tracks which assignments are currently fetching submissions
  final Set<String> _loadingSubmissions = {};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _loadAssignments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assignments = await _apiService.getClassAssignments(
        widget.courseId,
        widget.classId,
      );
      if (mounted) {
        setState(() {
          _assignments = assignments;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  // ── Fetch submissions for one assignment ────────────────────────────────────
  Future<void> _loadSubmissions(String assignmentId) async {
    if (_submissionsCache.containsKey(assignmentId)) return; // already cached
    setState(() => _loadingSubmissions.add(assignmentId));
    try {
      // Adjust to your actual ApiService method name/signature
      final raw = await _apiService.getAssignmentSubmissions(assignmentId);
      final List<AssignmentSubmission> subs =
      (raw as List).map((j) => AssignmentSubmission.fromJson(j)).toList();
      if (mounted) {
        setState(() {
          _submissionsCache[assignmentId] = subs;
          _loadingSubmissions.remove(assignmentId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submissionsCache[assignmentId] = [];
          _loadingSubmissions.remove(assignmentId);
        });
      }
    }
  }

  // ── Toggle expand/collapse ──────────────────────────────────────────────────
  void _toggleExpand(String assignmentId) {
    setState(() {
      if (_expandedAssignments.contains(assignmentId)) {
        _expandedAssignments.remove(assignmentId);
      } else {
        _expandedAssignments.add(assignmentId);
        _loadSubmissions(assignmentId);
      }
    });
  }

  // ── Grade / feedback sheet ──────────────────────────────────────────────────
  void _showGradeSheet(AssignmentSubmission sub, double totalPoints) {


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3D1C7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      _avatarWidget(sub.studentName, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.studentName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              'Submitted ${_formatDate(sub.submittedAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF888780),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (sub.pdfBase64 != null)
                        GestureDetector(
                          onTap: () => _viewPdf(sub.pdfBase64!, sub.studentName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD85A30).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFFD85A30)),
                                SizedBox(width: 4),
                                Text(
                                  'View PDF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFD85A30),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (sub.comment != null && sub.comment!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sheetLabel("Student Comment"),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        sub.comment!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF2C2C2A)),
                      ),
                    ),
                  ],



                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  void _viewPdf(String base64Str, String title) async {
    try {
      final bytes = base64Decode(base64Str);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$title.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: PDFView(filePath: file.path),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: $e')),
      );
    }
  }

  Widget _avatarWidget(String name, {double size = 36}) {
    final initials = name
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final colors = [
      const Color(0xFF5B8DEF),
      const Color(0xFF1D9E75),
      const Color(0xFFEF9F27),
      const Color(0xFFD85A30),
      const Color(0xFF9B59B6),
    ];
    final color = colors[name.codeUnitAt(0) % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ADD / EDIT / DELETE sheets — unchanged from original
  // ─────────────────────────────────────────────────────────────────────────────

  void _showAddAssignmentSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '100');
    DateTime? dueDate;
    String? pdfBase64;
    String? pdfFileName;
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3D1C7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.add_task_rounded,
                          color: Color(0xFFEF9F27), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Add Assignment",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              "${widget.courseTitle} - ${widget.className} Class",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF888780),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sheetLabel("Assignment Title"),
                  const SizedBox(height: 8),
                  _sheetField(
                      titleCtrl, "e.g. Midterm Project", Icons.title),
                  const SizedBox(height: 16),
                  _sheetLabel("Description"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF2C2C2A)),
                    decoration: InputDecoration(
                      hintText: "Describe the assignment requirements...",
                      hintStyle: const TextStyle(
                          color: Color(0xFFB4B2A9), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF1EFE8),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1D9E75), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sheetLabel("Total Points"),
                  const SizedBox(height: 8),
                  _sheetField(pointsCtrl, "100", Icons.star,
                      type: TextInputType.number),
                  const SizedBox(height: 16),
                  _sheetLabel("Due Date (Optional)"),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate ??
                            DateTime.now()
                                .add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setLocal(() => dueDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 20, color: Color(0xFF888780)),
                          const SizedBox(width: 12),
                          Text(
                            dueDate != null
                                ? "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}"
                                : "Select due date",
                            style: TextStyle(
                              fontSize: 14,
                              color: dueDate != null
                                  ? const Color(0xFF2C2C2A)
                                  : const Color(0xFFB4B2A9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sheetLabel("Attach PDF (Optional)"),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result =
                        await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          final bytes = result.files.single.bytes!;
                          if (bytes.length > 5 * 1024 * 1024) {
                            setLocal(() => errorText =
                            "File too large. Please choose a PDF under 5MB.");
                            return;
                          }
                          final base64String = base64Encode(bytes);
                          setLocal(() {
                            pdfBase64 = base64String;
                            pdfFileName = result.files.single.name;
                            errorText = null;
                          });
                        }
                      } catch (e) {
                        setLocal(
                                () => errorText = "Failed to read file: $e");
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(12),
                        border: pdfBase64 != null
                            ? Border.all(
                            color: const Color(0xFF1D9E75), width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pdfBase64 != null
                                ? Icons.picture_as_pdf
                                : Icons.attach_file,
                            color: pdfBase64 != null
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFF888780),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pdfFileName ?? "Choose PDF file",
                              style: TextStyle(
                                fontSize: 14,
                                color: pdfBase64 != null
                                    ? const Color(0xFF1D9E75)
                                    : const Color(0xFFB4B2A9),
                              ),
                            ),
                          ),
                          if (pdfBase64 != null)
                            IconButton(
                              onPressed: () => setLocal(() {
                                pdfBase64 = null;
                                pdfFileName = null;
                              }),
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFD85A30)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(errorText!,
                        style: const TextStyle(
                            color: Color(0xFFD85A30),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          setLocal(() => errorText =
                          "Assignment title is required.");
                          return;
                        }
                        final points =
                            double.tryParse(pointsCtrl.text.trim()) ??
                                100;
                        setLocal(() {
                          isSaving = true;
                          errorText = null;
                        });
                        try {
                          await _apiService
                              .createAssignmentWithBase64(
                            courseId: widget.courseId,
                            classId: widget.classId,
                            title: title,
                            description:
                            descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            dueDate: dueDate,
                            pdfBase64: pdfBase64,
                            totalPoints: points,
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await _loadAssignments();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Assignment created successfully."),
                              backgroundColor: Color(0xFF1D9E75),
                            ),
                          );
                        } catch (e) {
                          setLocal(() {
                            isSaving = false;
                            errorText = e
                                .toString()
                                .replaceFirst('Exception: ', '');
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF9F27),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Text(
                        "Create Assignment",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignmentDetails(Assignment assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D1C7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFEF9F27).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.assignment_rounded,
                        color: Color(0xFFEF9F27), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Total Points: ${assignment.totalPoints}",
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888780)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (assignment.description != null) ...[
                const Text("Description",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444441))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(assignment.description!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF2C2C2A))),
                ),
                const SizedBox(height: 16),
              ],
              if (assignment.dueDate != null) ...[
                const Text("Due Date",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444441))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: Color(0xFFEF9F27)),
                      const SizedBox(width: 8),
                      Text(
                        "${assignment.dueDate!.day}/${assignment.dueDate!.month}/${assignment.dueDate!.year}",
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF2C2C2A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (assignment.pdfBase64 != null) ...[
                const Text("Attachment",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444441))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                        const Color(0xFFEF9F27).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.picture_as_pdf,
                          color: Color(0xFFD85A30), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text("PDF Attachment Available",
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF1D9E75))),
                      ),
                      Icon(Icons.download_rounded,
                          size: 16, color: Color(0xFF1D9E75)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showEditAssignmentSheet(assignment),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text("Edit"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5B8DEF),
                        side: const BorderSide(color: Color(0xFF5B8DEF)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _confirmDeleteAssignment(assignment),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD85A30),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditAssignmentSheet(Assignment assignment) {
    final titleCtrl =
    TextEditingController(text: assignment.title);
    final descCtrl =
    TextEditingController(text: assignment.description ?? '');
    final pointsCtrl = TextEditingController(
        text: assignment.totalPoints.toString());
    DateTime? dueDate = assignment.dueDate;
    String? pdfBase64 = assignment.pdfBase64;
    String? pdfFileName =
    assignment.pdfBase64 != null ? "Current PDF" : null;
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3D1C7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          color: Color(0xFF5B8DEF), size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Edit Assignment",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sheetLabel("Assignment Title"),
                  const SizedBox(height: 8),
                  _sheetField(
                      titleCtrl, "e.g. Midterm Project", Icons.title),
                  const SizedBox(height: 16),
                  _sheetLabel("Description"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF2C2C2A)),
                    decoration: InputDecoration(
                      hintText: "Describe the assignment requirements...",
                      hintStyle: const TextStyle(
                          color: Color(0xFFB4B2A9), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF1EFE8),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1D9E75), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sheetLabel("Total Points"),
                  const SizedBox(height: 8),
                  _sheetField(pointsCtrl, "100", Icons.star,
                      type: TextInputType.number),
                  const SizedBox(height: 16),
                  _sheetLabel("Due Date"),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate ??
                            DateTime.now()
                                .add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setLocal(() => dueDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 20, color: Color(0xFF888780)),
                          const SizedBox(width: 12),
                          Text(
                            dueDate != null
                                ? "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}"
                                : "Select due date",
                            style: TextStyle(
                              fontSize: 14,
                              color: dueDate != null
                                  ? const Color(0xFF2C2C2A)
                                  : const Color(0xFFB4B2A9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sheetLabel("Attach PDF (Optional)"),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result =
                        await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          final bytes = result.files.single.bytes!;
                          if (bytes.length > 5 * 1024 * 1024) {
                            setLocal(() => errorText =
                            "File too large. Please choose a PDF under 5MB.");
                            return;
                          }
                          final base64String = base64Encode(bytes);
                          setLocal(() {
                            pdfBase64 = base64String;
                            pdfFileName = result.files.single.name;
                            errorText = null;
                          });
                        }
                      } catch (e) {
                        setLocal(
                                () => errorText = "Failed to read file: $e");
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(12),
                        border: pdfBase64 != null
                            ? Border.all(
                            color: const Color(0xFF1D9E75), width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pdfBase64 != null
                                ? Icons.picture_as_pdf
                                : Icons.attach_file,
                            color: pdfBase64 != null
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFF888780),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pdfFileName ?? "Choose PDF file",
                              style: TextStyle(
                                fontSize: 14,
                                color: pdfBase64 != null
                                    ? const Color(0xFF1D9E75)
                                    : const Color(0xFFB4B2A9),
                              ),
                            ),
                          ),
                          if (pdfBase64 != null)
                            IconButton(
                              onPressed: () => setLocal(() {
                                pdfBase64 = null;
                                pdfFileName = null;
                              }),
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFD85A30)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(errorText!,
                        style: const TextStyle(
                            color: Color(0xFFD85A30),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          setLocal(() => errorText =
                          "Assignment title is required.");
                          return;
                        }
                        final points =
                            double.tryParse(pointsCtrl.text.trim()) ??
                                100;
                        setLocal(() {
                          isSaving = true;
                          errorText = null;
                        });
                        try {
                          await _apiService
                              .updateAssignmentWithBase64(
                            assignmentId: assignment.assignmentId,
                            title: title,
                            description:
                            descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            dueDate: dueDate,
                            pdfBase64: pdfBase64,
                            totalPoints: points,
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await _loadAssignments();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Assignment updated successfully."),
                              backgroundColor: Color(0xFF1D9E75),
                            ),
                          );
                        } catch (e) {
                          setLocal(() {
                            isSaving = false;
                            errorText = e
                                .toString()
                                .replaceFirst('Exception: ', '');
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B8DEF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Text(
                        "Save Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAssignment(Assignment assignment) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFD85A30), size: 22),
            SizedBox(width: 8),
            Text(
              "Delete Assignment",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${assignment.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(
                    color: Color(0xFF888780),
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService
                    .deleteAssignment(assignment.assignmentId);
                await _loadAssignments();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Assignment deleted successfully."),
                    backgroundColor: Color(0xFF1D9E75),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: const Color(0xFFD85A30),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD85A30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Shared field widgets ────────────────────────────────────────────────────
  Widget _sheetLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF444441),
      letterSpacing: 0.2,
    ),
  );

  Widget _sheetField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType type = TextInputType.text,
      }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
          prefixIcon:
          Icon(icon, size: 20, color: const Color(0xFF888780)),
          filled: true,
          fillColor: const Color(0xFFF1EFE8),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
          ),
        ),
      );

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
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
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.courseTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.className} Class · Assignments',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddAssignmentSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Add',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _loadAssignments,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.refresh_rounded,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Refresh',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(
                                top: 12, bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FadeTransition(
                            opacity: _fadeIn,
                            child: _buildBody(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child:
          CircularProgressIndicator(color: Color(0xFF1D9E75)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFD85A30), size: 42),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF5F5E5A), fontSize: 13)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _loadAssignments,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }
    if (_assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No assignments yet",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400)),
            const SizedBox(height: 6),
            Text('Tap "Add" to create your first assignment',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: _assignments.length,
      itemBuilder: (context, index) =>
          _assignmentCard(_assignments[index]),
    );
  }

  // ── Assignment card with expandable submissions ─────────────────────────────
  Widget _assignmentCard(Assignment assignment) {
    final isPastDue = assignment.dueDate != null &&
        assignment.dueDate!.isBefore(DateTime.now());
    final isExpanded =
    _expandedAssignments.contains(assignment.assignmentId);
    final isLoadingSubs =
    _loadingSubmissions.contains(assignment.assignmentId);
    final subs = _submissionsCache[assignment.assignmentId];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Main card row ────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom:
              isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            onTap: () => _showAssignmentDetails(assignment),
            child: Row(
              children: [
                // Coloured left bar
                Container(
                  width: 4,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isPastDue
                        ? const Color(0xFFD85A30)
                        : const Color(0xFFEF9F27),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                  ),
                ),
                const SizedBox(width: 16),
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFEF9F27).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_rounded,
                      color: Color(0xFFEF9F27), size: 24),
                ),
                const SizedBox(width: 14),
                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (assignment.dueDate != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 12,
                                color: isPastDue
                                    ? const Color(0xFFD85A30)
                                    : const Color(0xFF888780)),
                            const SizedBox(width: 4),
                            Text(
                              "Due: ${assignment.dueDate!.day}/${assignment.dueDate!.month}/${assignment.dueDate!.year}",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isPastDue
                                      ? const Color(0xFFD85A30)
                                      : const Color(0xFF888780)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      Text("Points: ${assignment.totalPoints}",
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888780))),
                    ],
                  ),
                ),
                // Submissions toggle button
                GestureDetector(
                  onTap: () => _toggleExpand(assignment.assignmentId),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? const Color(0xFF1D9E75).withOpacity(0.12)
                          : const Color(0xFFF1EFE8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: isExpanded
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFF888780),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          subs != null
                              ? '${subs.length}'
                              : 'Subs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isExpanded
                                ? const Color(0xFF1D9E75)
                                : const Color(0xFF888780),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: isExpanded
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFF888780),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Expandable submissions panel ─────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildSubmissionsPanel(
                assignment, isLoadingSubs, subs),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsPanel(
      Assignment assignment,
      bool isLoading,
      List<AssignmentSubmission>? subs,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F4),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(
              color: const Color(0xFFE8E6DF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    size: 14, color: Color(0xFF1D9E75)),
                const SizedBox(width: 6),
                Text(
                  isLoading
                      ? "Loading submissions…"
                      : subs == null || subs.isEmpty
                      ? "No submissions yet"
                      : "${subs.length} Submission${subs.length == 1 ? '' : 's'}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D9E75),
                  ),
                ),
                const Spacer(),
                // Refresh submissions
                GestureDetector(
                  onTap: () {
                    _submissionsCache.remove(assignment.assignmentId);
                    _loadSubmissions(assignment.assignmentId);
                  },
                  child: const Icon(Icons.refresh_rounded,
                      size: 16, color: Color(0xFF888780)),
                ),
              ],
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1D9E75),
                  ),
                ),
              ),
            )
          else if (subs == null || subs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 18, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  Text("No students have submitted yet.",
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: subs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) =>
                  _submissionRow(subs[i], assignment.totalPoints),
            ),
        ],
      ),
    );
  }

  Widget _submissionRow(
      AssignmentSubmission sub, double totalPoints) {
    final graded = sub.grade != null;

    return GestureDetector(
      onTap: () => _showGradeSheet(sub, totalPoints),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: graded
                ? const Color(0xFF1D9E75).withOpacity(0.25)
                : const Color(0xFFE8E6DF),
          ),
        ),
        child: Row(
          children: [
            _avatarWidget(sub.studentName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.studentName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(sub.submittedAt),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF888780)),
                  ),
                ],
              ),
            ),
            // PDF badge
            if (sub.pdfBase64 != null || sub.pdfUrl != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD85A30).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.picture_as_pdf,
                    size: 14, color: Color(0xFFD85A30)),
              ),
            // Grade chip
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: graded
                    ? const Color(0xFF1D9E75).withOpacity(0.12)
                    : const Color(0xFFEF9F27).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                graded
                    ? '${sub.grade!.toStringAsFixed(sub.grade! % 1 == 0 ? 0 : 1)} / $totalPoints'
                    : '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: graded
                      ? const Color(0xFF1D9E75)
                      : const Color(0xFFEF9F27),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}