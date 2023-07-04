fn f() {
   var<function> count: u32;  // A variable in function address space.
   var delta: i32;            // Another variable in the function address space.
   var sum: f32 = 0.0;        // A function address space variable with initializer.
   var pi = 3.14159;          // Infer the f32 store type from the initializer.
}
