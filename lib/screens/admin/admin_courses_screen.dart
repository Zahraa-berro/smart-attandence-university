import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_classroom_new/models/course.dart';
import 'package:smart_classroom_new/screens/admin/admin_course_detail_screen.dart';
import 'package:smart_classroom_new/services/api_service.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  final ApiService _apiService = ApiService();
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Design tokens (reusing from admin_dashboard for consistency)
  static const Color _brand = Color(0xFF1D9E75);
  static const Color _danger = Color(0xFFD85A30);
  static const Color _surface = Color(0xFFF8F7F4);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _inkMuted = Color(0xFF888780);

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final coursesData = await _apiService.getCourses();
      if (!mounted) return;
      setState(() {
        _courses = coursesData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Manual date formatting to avoid intl dependency
  String _formatDate(DateTime? d) {
    if (d == null) return "Not set";
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return "${d.day} ${months[d.month]} ${d.year}";
  }

  // Helper for text field display
  String _formatISODate(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _danger : _brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEditCourse({Course? course}) async {
    // Mirror doctor's add/edit course sheet with validation, preview, and error handling
    final titleCtrl = TextEditingController(text: course?.courseName);
    final studentsCtrl = TextEditingController(text: course?.studentsCount.toString());
    final doctorCtrl = TextEditingController(text: course?.doctorId ?? '');
    DateTime? startDate = course?.startDate;
    DateTime? endDate = course?.endDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          bool isSaving = false;
          String? errorText;

          Widget errorBox(String text) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF5C6C0)),
                ),
                child: Text(text, style: const TextStyle(color: Color(0xFFD85A30))),
              );

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2))),
                Text(course == null ? 'Add New Course' : 'Edit Course', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Course Title', border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        TextField(controller: studentsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of Students', border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        // Allow admin to assign a doctor to the course
                        TextField(controller: doctorCtrl, decoration: const InputDecoration(labelText: 'Doctor ID (optional)', border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        ListTile(title: Text(startDate == null ? 'Select Start Date' : 'Start Date: ${_formatISODate(startDate!)}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setLocal(() => startDate = picked);
                        }),
                        ListTile(title: Text(endDate == null ? 'Select End Date' : 'End Date: ${_formatISODate(endDate!)}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (picked != null) setLocal(() => endDate = picked);
                        }),
                        if (startDate != null && endDate != null) ...[
                          const SizedBox(height: 8),
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withOpacity(0.08))), child: Text('Semester: ${_formatISODate(startDate!)} → ${_formatISODate(endDate!)}')),
                        ],
                        const SizedBox(height: 12),
                        if (errorText != null) ...[const SizedBox(height: 8), SizedBox(width: double.infinity, child: errorBox(errorText!))],
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (isSaving) return;
                      final title = titleCtrl.text.trim();
                      final students = int.tryParse(studentsCtrl.text.trim()) ?? 0;
                      if (title.isEmpty) {
                        setLocal(() => errorText = 'Course title is required.');
                        return;
                      }
                      if (startDate == null || endDate == null) {
                        setLocal(() => errorText = 'Start and end dates are required.');
                        return;
                      }
                      if (endDate!.isBefore(startDate!)) {
                        setLocal(() => errorText = 'End date must be after start date.');
                        return;
                      }

                      // Prevent duplicate course name
                      final exists = _courses.any((c) => c.courseName.toLowerCase() == title.toLowerCase() && c.courseId != course?.courseId);
                      if (exists) {
                        setLocal(() => errorText = 'A course with this title already exists.');
                        return;
                      }

                      setLocal(() {
                        isSaving = true;
                        errorText = null;
                      });

                      try {
                        if (course == null) {
                          await _apiService.createCourse(
                            courseName: title,
                            studentsCount: students,
                            startDate: startDate,
                            endDate: endDate,
                            doctorId: doctorCtrl.text.trim().isEmpty ? null : doctorCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                          _showSnack('Course created successfully!');
                        } else {
                          await _apiService.updateCourse(
                            courseId: course.courseId,
                            courseName: title,
                            studentsCount: students,
                            startDate: startDate,
                            endDate: endDate,
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                          _showSnack('Course updated successfully!');
                        }
                        await _loadCourses();
                      } catch (e) {
                        setLocal(() {
                          isSaving = false;
                          errorText = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(course == null ? 'Create Course' : 'Update Course'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteCourse(String courseId) async {
    // Find course object for nicer confirmation (safe nullable lookup)
    final idx = _courses.indexWhere((c) => c.courseId == courseId);
    final Course? course = idx >= 0 ? _courses[idx] : null;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD85A30), size: 22),
            SizedBox(width: 8),
            Text("Delete Course", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          ],
        ),
        content: Text(
          (course != null && course.courseName.isNotEmpty)
              ? 'Are you sure you want to delete "${course.courseName}"? This action cannot be undone.'
              : 'Are you sure you want to delete this course? This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF888780), fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteCourse(courseId);
                if (!mounted) return;
                await _loadCourses();
                if (!mounted) return;
                _showSnack('Course deleted successfully!');
              } catch (e) {
                if (!mounted) return;
                _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: _danger),
                  ),
                )
              : Stack(
                  children: [
                    Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF5DCAA5), Color(0xFF9FE1CB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Text('Manage Courses', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                                  onPressed: () => _addEditCourse(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                                  onPressed: _loadCourses,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                              ),
                              child: Column(
                                children: [
                                  Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2))),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                      child: _courses.isEmpty
                                          ? const Center(child: Text('No courses available'))
                                          : ListView.separated(
                                              itemCount: _courses.length,
                                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                                              itemBuilder: (context, index) {
                                                final course = _courses[index];
                                                return GestureDetector(
                                                  onTap: () => _openCourseDetail(course),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(14),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(14),
                                                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(course.courseName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                                                              const SizedBox(height: 6),
                                                              Text('Code: ${course.courseCode ?? 'N/A'}', style: const TextStyle(color: Color(0xFF7D7D7D))),
                                                              const SizedBox(height: 6),
                                                              Text('Students: ${course.studentsCount}', style: const TextStyle(color: Color(0xFF7D7D7D))),
                                                            ],
                                                          ),
                                                        ),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF1D9E75)),
                                                              onPressed: () => _addEditCourse(course: course),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.delete_rounded, color: Color(0xFFD85A30)),
                                                              onPressed: () => _deleteCourse(course.courseId),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF1D9E75)),
                                                              onPressed: () => _openCourseDetail(course),
                                                            ),
                                                          ],
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
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
                  ],
                ),
    );
  }

  void _openCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCourseDetailScreen(courseId: course.courseId),
      ),
    );
  }
}