class Student {
  final String id;
  final String studentId;
  final String name;
  final String email;
  final String imageUrl;
  final String phoneNumber;

  int absentCount;
  int presentCount;
  bool isPresent;

  List<String> enrolledCourses;

  Student({
    required this.id,
    String? studentId,
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.phoneNumber,
    this.absentCount = 0,
    this.presentCount = 0,
    this.isPresent = false,
    this.enrolledCourses = const [],
  }) : studentId = studentId ?? id;

  factory Student.fromJson(Map<String, dynamic> json) {
    final studentId =
        json['studentId']?.toString() ?? json['id']?.toString() ?? '';
    return Student(
      id: studentId,
      studentId: studentId,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      imageUrl:
          json['image']?.toString() ??
          json['imageUrl']?.toString() ??
          'assets/students/default.jpg',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      absentCount: (json['absentCount'] as num?)?.toInt() ?? 0,
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      isPresent: json['isPresent'] == true,
      enrolledCourses: json['enrolledCourses'] is List
          ? (json['enrolledCourses'] as List)
                .map((item) => item.toString())
                .toList()
          : const [],
    );
  }
}
