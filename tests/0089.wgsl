fn foo(p : ptr<function, array<f32, 4>>, i : i32) -> f32 {
  let p1 = p;
  var x = i;
  let p2 = &((*p1)[x]);
  x = 0;
  *p2 = 5;
  return (*p1)[x];
}

// This is the equivalent version of foo for the analysis.
fn foo_for_analysis(p : ptr<function, array<f32, 4>>, i : i32) -> f32 {
  var p_var = *p;            // Introduce variable for p.
  let p1 = &p_var;           // Use the variable for p1
  var x = i;
  let x_tmp1 = x;            // Capture value of x
  let p2 = &(p_var[x_tmp1]); // Substitute p1’s initializer
  x = 0;
  *(&(p_var[x_tmp1])) = 5;   // Substitute p2’s initializer
  return (*(&p_var))[x];     // Substitute p1’s initializer
}
