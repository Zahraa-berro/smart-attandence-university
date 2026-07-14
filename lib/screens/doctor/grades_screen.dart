import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class GradesScreen extends StatefulWidget {
  final String courseTitle;
  final String courseId;
  final String section;

  const GradesScreen({
    super.key,
    required this.courseTitle,
    required this.courseId,
    required this.section,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _components = [];
  bool _saving = false;
  bool _loadingGrades = true;
  bool _loadingComponents = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    for (final map in _controllers.values) {
      for (final ctrl in map.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loadingGrades = true;
      _loadingComponents = true;
    });

    await _loadComponents();
    await _loadStudentsAndGrades();
  }

  Future<void> _loadComponents() async {
    try {
      final components = await _apiService.getGradeComponents(widget.courseId);
      if (mounted) {
        setState(() {
          _components = components;
          _loadingComponents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingComponents = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load grade components: $e'),
            backgroundColor: const Color(0xFFEF9F27),
          ),
        );
      }
    }
  }

  Future<void> _loadStudentsAndGrades() async {
    try {
      final apiStudents = await _apiService.getCourseStudents(widget.courseId);

      final normalized = apiStudents
          .map((s) => {'id': s.id, 'name': s.name})
          .toList();

      for (final s in normalized) {
        final id = s['id'] as String;
        if (!_controllers.containsKey(id)) {
          _controllers[id] = {};
          for (final comp in _components) {
            _controllers[id]![comp['name']] = TextEditingController();
          }
        }
      }

      try {
        final grades = await _apiService.getCourseGrades(widget.courseId);
        for (final g in grades) {
          final id = g['studentId'] as String;
          if (_controllers.containsKey(id)) {
            final scores = g['componentScores'] as Map<String, dynamic>? ?? {};
            for (final comp in _components) {
              final compName = comp['name'] as String;
              final score = scores[compName] ?? 0;
              if (_controllers[id]!.containsKey(compName)) {
                _controllers[id]![compName]!.text = score == 0 ? '' : score.toString();
              }
            }
          }
        }
      } catch (_) {}

      if (mounted) setState(() => _students = normalized);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load students: $e'),
            backgroundColor: const Color(0xFFD85A30),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGrades = false);
    }
  }

  Future<void> _saveGrades() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students to save grades for'),
          backgroundColor: Color(0xFFEF9F27),
        ),
      );
      return;
    }

    final gradesList = _students.map((s) {
      final id = s['id'] as String;
      final ctrls = _controllers[id];
      if (ctrls == null) return null;
      
      final componentScores = <String, double>{};
      for (final comp in _components) {
        final compName = comp['name'] as String;
        final ctrl = ctrls[compName];
        if (ctrl != null) {
          componentScores[compName] = double.tryParse(ctrl.text) ?? 0;
        }
      }
      return {
        'studentId': id,
        'studentName': s['name'] as String,
        'courseId': widget.courseId,
        'componentScores': componentScores,
      };
    }).where((g) => g != null).toList().cast<Map<String, dynamic>>();

    setState(() => _saving = true);

    try {
      await _apiService.saveGradesBulk(widget.courseId, gradesList);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Grades saved successfully'),
            ],
          ),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFD85A30),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateComponents() async {
    final components = [..._components];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final controllers = <TextEditingController>[];
          for (int i = 0; i < components.length; i++) {
            controllers.add(TextEditingController(text: components[i]['percentage'].toString()));
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                const Text(
                  "Grade Components",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Set the percentage weight for each component (must sum to 100%)",
                  style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                ),
                const SizedBox(height: 20),
                ...components.asMap().entries.map((entry) {
                  final index = entry.key;
                  final comp = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            comp['name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controllers[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '%',
                              filled: true,
                              fillColor: const Color(0xFFF1EFE8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              suffixText: '%',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      int total = 0;
                      for (int i = 0; i < components.length; i++) {
                        total += int.tryParse(controllers[i].text) ?? 0;
                      }
                      if (total != 100) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Percentages must sum to 100%'),
                            backgroundColor: Color(0xFFD85A30),
                          ),
                        );
                        return;
                      }
                      
                      final updatedComponents = <Map<String, dynamic>>[];
                      for (int i = 0; i < components.length; i++) {
                        updatedComponents.add({
                          'name': components[i]['name'],
                          'percentage': int.tryParse(controllers[i].text) ?? 0,
                        });
                      }
                      
                      try {
                        await _apiService.setGradeComponents(
                          widget.courseId,
                          updatedComponents,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _loadAllData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Grade components updated'),
                            backgroundColor: Color(0xFF1D9E75),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update: $e'),
                            backgroundColor: const Color(0xFFD85A30),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Save Components",
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
          );
        },
      ),
    );
  }

  double _parseGrade(String text) => double.tryParse(text) ?? 0;

  double _calculateTotal(Map<String, double> scores) {
    double total = 0;
    for (final comp in _components) {
      final percentage = (comp['percentage'] as num).toDouble();
      final score = scores[comp['name']] ?? 0;
      total += (score * percentage / 100);
    }
    return total;
  }

  Color _gradeColor(double g) {
    if (g >= 85) return const Color(0xFF1D9E75);
    if (g >= 70) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

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
                              'Section ${widget.section}  ·  ${_students.length} Students',
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
                        onTap: _updateComponents,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.settings_rounded, size: 12, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Components',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _saving ? null : _saveGrades,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  children: [
                                    Icon(Icons.save_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (_loadingComponents || _loadingGrades)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
                            ),
                          )
                        else if (_students.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No students yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Add students from the attendance screen',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Student',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        ..._components.map((comp) => Expanded(
                                          child: Text(
                                            comp['name'],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        )),
                                        const Expanded(
                                          child: Text(
                                            'Total',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                                    itemCount: _students.length,
                                    itemBuilder: (context, index) {
                                      final s = _students[index];
                                      final id = s['id'] as String;
                                      final name = s['name'] as String;
                                      final ctrls = _controllers[id];
                                      
                                      if (ctrls == null) {
                                        return const SizedBox.shrink();
                                      }

                                      return StatefulBuilder(
                                        builder: (context, setRow) {
                                          void onChange() => setRow(() {});

                                          for (final comp in _components) {
                                            final compName = comp['name'] as String;
                                            final ctrl = ctrls[compName];
                                            if (ctrl != null) {
                                              ctrl.removeListener(onChange);
                                              ctrl.addListener(onChange);
                                            }
                                          }

                                          final scores = <String, double>{};
                                          for (final comp in _components) {
                                            final compName = comp['name'] as String;
                                            final ctrl = ctrls[compName];
                                            if (ctrl != null) {
                                              scores[compName] = _parseGrade(ctrl.text);
                                            }
                                          }
                                          final total = _calculateTotal(scores);
                                          final hasGrades = scores.values.any((v) => v > 0);

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.05),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 18,
                                                        backgroundColor: const Color(0xFF1D9E75).withOpacity(0.15),
                                                        child: Text(
                                                          name.isNotEmpty ? name[0] : '?',
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w700,
                                                            color: Color(0xFF1D9E75),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              name,
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                                color: Color(0xFF1A1A2E),
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Text(
                                                              'ID: $id',
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Color(0xFF888780),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                ..._components.map((comp) {
                                                  final compName = comp['name'] as String;
                                                  final ctrl = ctrls[compName];
                                                  return Expanded(
                                                    child: TextField(
                                                      controller: ctrl,
                                                      keyboardType: TextInputType.number,
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF1A1A2E),
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: '0',
                                                        hintStyle: const TextStyle(
                                                          color: Color(0xFFD3D1C7),
                                                          fontSize: 12,
                                                        ),
                                                        filled: true,
                                                        fillColor: const Color(0xFFF1EFE8),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          borderSide: BorderSide.none,
                                                        ),
                                                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                                Expanded(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: hasGrades
                                                          ? _gradeColor(total).withOpacity(0.10)
                                                          : const Color(0xFFF1EFE8),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      hasGrades ? total.toStringAsFixed(1) : '—',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                        color: hasGrades
                                                            ? _gradeColor(total)
                                                            : const Color(0xFFD3D1C7),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
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
}