var<private> next_item: i32 = 0;

fn advance_item() -> i32 {
   next_item += 1;   // Adds 1 to next_item.
   return next_item - 1;
}

fn bump_item() {
  var data: array<f32,10>;
  next_item = 0;
  // Adds 5.0 to data[0], calling advance_item() only once.
  data[advance_item()] += 5.0;
  // next_item will be 1 here.
}

fn precedence_example() {
  var value = 1;
  // The right-hand side of a compound assignment is its own expression.
  value *= 2 + 3; // Same as value = value * (2 + 3);
  // 'value' now holds 5.
}
