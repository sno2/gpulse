fn if_example() {
  var a: i32 = 0;
  loop {
    if a == 5 {
      break;      // Behavior: {Break}
    }             // Behavior of the whole if compound statement: {Break, Next},
                  //   as the if has an implicit empty else
    a = a + 1;    // Valid, as the previous statement had "Next" in its behavior
  }
}
