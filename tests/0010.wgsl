// Valid, user-defined variables can have the same name as a built-in function.
var<private> modf: f32 = 0.0;

// Valid, foo_1 is in scope for the entire program.
var<private> foo: f32 = 0.0; // foo_1

// Valid, bar_1 is in scope for the entire program.
var<private> bar: u32 = 0u; // bar_1

// Valid, my_func_1 is in scope for the entire program.
// Valid, foo_2 is in scope until the end of the function.
fn my_func(foo: f32) { // my_func_1, foo_2
  // Any reference to 'foo' resolves to the function parameter.

  // Invalid, modf resolves to the module-scope variable.
  let res = modf(foo);

  // Invalid, the scope of foo_2 ends at the of the function.
  var foo: f32; // foo_3

  // Valid, bar_2 is in scope until the end of the function.
  var bar: u32; // bar_2
  // References to 'bar' resolve to bar_2
  {
    // Valid, foo_4 is in scope until the end of the compound statement.
    var foo : f32; // foo_4

    // Valid, bar_3 is in scope until the end of the compound statement.
    var bar: u32; // bar_3
    // References to 'bar' resolve to bar_3

    // Invalid, bar_4 has the same end scope as bar_3.
    var bar: i32; // bar_4

    // Valid, i_1 is in scope until the end of the for loop
    for ( var i: i32 = 0; i < 10; i++ ) { // i_1
      // Invalid, i_2 has the same end scope as i_1.
      var i: i32 = 1; // i_2.
    }
  }

  // Invalid, bar_5 has the same end scope as bar_2.
  var bar: u32; // bar_5

  // Valid, later_def, a module scope declaration, is in scope for the entire program.
  var early_use : i32 = later_def;
}

// Invalid, bar_6 has the same scope as bar_1.
var<private> bar: u32 = 1u; // bar_6

// Invalid, my_func_2 has the same end scope as my_func_1.
fn my_func() { } // my_func_2

// Valid, my_foo_1 is in scope for the entire program.
fn my_foo( //my_foo_1
  // Valid, my_foo_2 is in scope until the end of the function.
  my_foo: i32 // my_foo_2
) { }

var<private> later_def : i32 = 1;
