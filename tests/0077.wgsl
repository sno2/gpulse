struct A {
  @location(0) x: f32,
  // Despite locations being 16-bytes, x and y cannot share a location
  @location(1) y: f32
}

// in1 occupies locations 0 and 1.
// in2 occupies location 2.
// The return value occupies location 0.
@fragment
fn fragShader(in1: A, @location(2) in2: f32) -> @location(0) vec4<f32> {
 // ...
}
