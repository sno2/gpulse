fn continue_out_of_loop () {
  var a: i32 = 0;
  if a > 0  {
    continue;       // Behavior: {Continue}
  }                 // Behavior: {Next, Continue}
}                   // Error: Continue is invalid in the body of a function
