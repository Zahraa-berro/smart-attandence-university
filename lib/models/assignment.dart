class Assignment {
  final String id;
  final String assignmentId;
  final String courseId;
  final String classId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? pdfBase64;
  final double totalPoints;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.id,
    required this.assignmentId,
    required this.courseId,
    required this.classId,
    required this.title,
    this.description,
    this.dueDate,
    this.pdfBase64,
    required this.totalPoints,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['_id']?.toString() ?? '',
      assignmentId: json['assignmentId']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      classId: json['classId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      pdfBase64: json['pdfBase64']?.toString(),
      totalPoints: (json['totalPoints'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'assignmentId': assignmentId,
      'courseId': courseId,
      'classId': classId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'pdfBase64': pdfBase64,
      'totalPoints': totalPoints,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}