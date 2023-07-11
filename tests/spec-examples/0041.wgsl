var<private> counter: i32;

fn increment_and_yield_previous() -> i32 {
  let previous = counter;
  counter = counter + 1;
  return previous;
}

fn user() {
  // Increment the counter, but don’t use the result.
  _ = increment_and_yield_previous();
}
