fn if_example() {
  var a: i32 = 0;
  loop {
    // if e1 s1 else if e2 s2 else s3
    // is identical to
    // if e1 else { if e2 s2 else s3 }
    if a == 5 {
      break;      // Behavior: {Break}
    } else if a == 42 {
      continue;   // Behavior: {Continue}
    } else {
      return;     // Behavior {Return}
    }             // Behavior of the whole if compound statement:
                  //   {Break, Continue, Return}
  }               // Behavior of the whole loop compound statement {Next, Return}
}                 // Behavior of the whole function {Next}
