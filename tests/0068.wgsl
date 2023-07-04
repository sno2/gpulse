fn missing_return () -> i32 {
  var a: i32 = 0;
  if a == 42 {
    return a;       // Behavior: {Return}
  }                 // Behavior: {Next, Return}
}                   // Error: Next is invalid in the body of a
                    //   function with a return type
