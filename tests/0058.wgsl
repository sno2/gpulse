fn nested() -> i32 {
  var a: i32;
  {             // The start of a compound statement.
    a = 2;      // Behavior: {Next}
    return 1;   // Behavior: {Return}
  }             // The compound statement as a whole has behavior {Return}
  a = 1;        // Valid, statically unreachable code.
                //   Statement behavior: {Next}
                //   Overall behavior (due to sequential statements): {Return}
  return 2;     // Valid, statically unreachable code. Behavior: {Return}
}
