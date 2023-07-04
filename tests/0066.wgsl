fn redundant_continue_with_continuing() {
  var a: i32;
  loop {
    if a == 5 { break; }
    continue;   // Valid. This is redundant, branching to the next statement.
    continuing {
      a = a + 1;
    }
  }
}
