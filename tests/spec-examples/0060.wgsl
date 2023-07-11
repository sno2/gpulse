fn if_example() {
  var a: i32 = 0;
  loop {
    if a == 5 {
      break;      // Behavior: {Break}
    } else {
      continue;   // Behavior: {Continue}
    }             // Behavior of the whole if compound statement: {Break, Continue}
    a = a + 1;    // Valid, statically unreachable code.
                  //   Statement behavior: {Next}
                  //   Overall behavior: {Break, Continue}
  }
}
