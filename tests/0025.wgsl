fn add_one(x: ptr<function,i32>) {
  /* Update the locations for 'x' to contain the next higher integer value,
     (or to wrap around to the largest negative i32 value).
     On the left-hand side, unary '*' converts the pointer to a reference that
     can then be assigned to. It has a read_write access mode, by default.
     /* On the right-hand side:
        - Unary '*' converts the pointer to a reference, with a read_write
          access mode.
        - The only matching type rule is for addition (+) and requires '*x' to
          have type i32, which is the store type for '*x'.  So the Load Rule
          applies and '*x' evaluates to the value stored in the memory for '*x'
          at the time of evaluation, which is the i32 value for 0.
        - Add 1 to 0, to produce a final value of 1 for the right-hand side. */
     Store 1 into the memory for '*x'. */
  *x = *x + 1;
}

@compute @workgroup_size(1)
fn main() {
  var i: i32 = 0;

  // Modify the contents of 'i' so it will contain 1.
  // Use unary '&' to get a pointer value for 'i'.
  // This is a clear signal that the called function has access to the memory
  // for 'i', and may modify it.
  add_one(&i);
  let one: i32 = i;  // 'one' has value 1.
}
