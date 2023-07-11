fn simple() -> i32 {
  var a: i32;
  return 0;  // Behavior: {Return}
  a = 1;     // Valid, statically unreachable code.
             //   Statement behavior: {Next}
             //   Overall behavior (due to sequential statements): {Return}
  return 2;  // Valid, statically unreachable code. Behavior: {Return}
} // Function behavior: {Return}
