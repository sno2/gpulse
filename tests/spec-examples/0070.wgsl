// Declare the add_two function.
// It has two formal parameters, i and b.
// It has a return type of i32.
// It has a body with a return statement.
fn add_two(i: i32, b: f32) -> i32 {
  return i + 2;  // A formal parameter is available for use in the body.
}

// A compute shader entry point function, 'main'.
// It has no specified return type.
// It invokes the add_two function, and captures
// the resulting value in the named value 'six'.
@compute @workgroup_size(1)
fn main() {
   let six: i32 = add_two(4, 5.0);
}
