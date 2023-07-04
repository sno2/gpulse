// A structure with three members.
struct Data {
  a: i32,
  b: vec2<f32>,
  c: array<i32,10>, // last comma is optional
}

// Declare a variable storing a value of type Data.
var<private> some_data: Data;
