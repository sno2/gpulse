// Declare a variable in the private address space, for storing an f32 value.
var<private> x: f32;

fn f() {
    // Declare a variable in the function address space, for storing an i32 value.
    var y: i32;

    // The name 'x' resolves to the module-scope variable 'x',
    // and has reference type ref<private,f32,read_write>.
    // Applying the unary '&' operator converts the reference to a pointer.
    // The access mode is the same as the access mode of the original variable, so
    // the fully specified type is ptr<private,f32,read_write>.  But read_write
    // is the default access mode for function address space, so read_write does not
    // have to be spelled in this case
    let x_ptr: ptr<private,f32> = &x;

    // The name 'y' resolves to the function-scope variable 'y',
    // and has reference type ref<private,i32,read_write>.
    // Applying the unary '&' operator converts the reference to a pointer.
    // The access mode defaults to 'read_write'.
    let y_ptr: ptr<function,i32> = &y;

    // A new variable, distinct from the variable declared at module scope.
    var x: u32;

    // Here, the name 'x' resolves to the function-scope variable 'x' declared in
    // the previous statement, and has type ref<function,u32,read_write>.
    // Applying the unary '&' operator converts the reference to a pointer.
    // The access mode defaults to 'read_write'.
    let inner_x_ptr: ptr<function,u32> = &x;
}
