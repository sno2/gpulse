struct A {
  @location(0) x: f32,
  // Invalid, x and y cannot share a location.
  @location(0) y: f32
}

struct B {
  @location(0) x: f32
}

struct C {
  // Invalid, structures with user-defined IO cannot be nested.
  b: B
}

struct D {
  x: vec4<f32>
}

@fragment
// Invalid, location cannot be applied to a structure type.
fn fragShader1(@location(0) in1: D) {
  // ...
}

@fragment
// Invalid, in1 and in2 cannot share a location.
fn fragShader2(@location(0) in1: f32, @location(0) in2: f32) {
  // ...
}

@fragment
// Invalid, location cannot be applied to a structure.
fn fragShader3(@location(0) in1: vec4<f32>) -> @location(0) D {
  // ...
}
