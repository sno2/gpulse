fn switch_example() {
  var a: i32 = 0;
  switch a {
    default: {
      break;   // Behavior: {Break}
    }
  }            // Behavior: {Next}, as switch replaces Break by Next
  a = 5;       // Valid, as the previous statement had Next in its behavior
}
