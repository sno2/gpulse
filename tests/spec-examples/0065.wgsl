fn conditional_continue() {
  var a: i32;
  loop {
    if a == 5 { break; } // Behavior: {Break, Next}
    if a % 2 == 1 {      // Valid, as the previous statement has Next in its behavior
      continue;          // Behavior: {Continue}
    }                    // Behavior: {Continue, Next}
    a = a * 2;           // Valid, as the previous statement has Next in its behavior
    continuing {         // Valid as the continuing statement has behavior {Next}
                         //  which does not include any of:
                         //  {Break, Continue, Return}
      a = a + 1;
    }
  }                      // The loop as a whole has behavior {Next},
                         //  as it absorbs "Continue" and "Next",
                         //  then replaces "Break" with "Next"
}
