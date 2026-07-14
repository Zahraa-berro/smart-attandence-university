class StudentGrade {
  String studentId;
  String studentName;
  double midterm;
  double finalExam;
  double project;

  StudentGrade({
    required this.studentId,
    required this.studentName,
    this.midterm = 0,
    this.finalExam = 0,
    this.project = 0,
  });

  double get total => midterm + finalExam + project;
}