var<private> age: i32;
fn get_age() -> i32 {
  // The type of the expression in the return statement must be 'i32' since it
  // must match the declared return type of the function.
  // The 'age' expression is of type ref<private,i32,read_write>.
  // Apply the Load Rule, since the store type of the reference matches the
  // required type of the expression, and no other type rule applies.
  // The evaluation of 'age' in this context is the i32 value loaded from the
  // memory locations referenced by 'age' at the time the return statement is
  // executed.
  return age;
}

fn caller() {
  age = 21;
  // The copy_age constant will get the i32 value 21.
  let copy_age: i32 = get_age();
}
