@compute @workgroup_size(1)
fn main() {
  // 'i' has reference type ref<function,i32,read_write>
  // The memory locations for 'i' store the i32 value 0.
  var i: i32 = 0;

  // 'i + 1' can only match a type rule where the 'i' subexpression is of type i32.
  // So the expression 'i + 1' has type i32, and at evaluation, the 'i' subexpression
  // evaluates to the i32 value stored in the memory locations for 'i' at the time
  // of evaluation.
  let one: i32 = i + 1;

  // Update the value in the locations referenced by 'i' so they hold the value 2.
  i = one + 1;

  // Update the value in the locations referenced by 'i' so they hold the value 5.
  // The evaluation of the right-hand-side occurs before the assignment takes effect.
  i = i + 3;
}
