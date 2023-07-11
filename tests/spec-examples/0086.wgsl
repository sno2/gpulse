struct S {
  x: f32
}
struct Invalid {
  a: S,
  b: f32 // invalid: offset between a and b is 4 bytes, but must be at least 16
}
@group(0) @binding(0) var<uniform> invalid: Invalid;

struct Valid {
  a: S,
  @align(16) b: f32 // valid: offset between a and b is 16 bytes
}
@group(0) @binding(1) var<uniform> valid: Valid;
