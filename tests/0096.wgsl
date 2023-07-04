struct Student {
  grade: i32,
  GPA: f32,
  attendance: array<bool,4>
}

fn func() {
  var s: Student;

  // The zero value for Student
  s = Student();

  // The same value, written explicitly.
  s = Student(0, 0.0, array<bool,4>(false, false, false, false));

  // The same value, written with zero-valued members.
  s = Student(i32(), f32(), array<bool,4>());
}
