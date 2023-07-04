struct S {
    age: i32,
    weight: f32
}
var<private> person: S;

fn f() {
    var a: i32 = 20;
    a = 30;           // Replace the contents of 'a' with 30.

    person.age = 31;  // Write 31 into the age field of the person variable.

    var uv: vec2<f32>;
    uv.y = 1.25;      // Place 1.25 into the second component of uv.

    let uv_x_ptr: ptr<function,f32> = &uv.x;
    *uv_x_ptr = 2.5;  // Place 2.5 into the first component of uv.

    var sibling: S;
    // Copy the contents of the 'person' variable into the 'sivling' variable.
    sibling = person;
}
