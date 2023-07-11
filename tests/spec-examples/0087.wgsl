struct small_stride {
  a: array<f32,8> // stride 4
}
// Invalid, stride must be a multiple of 16
@group(0) @binding(0) var<uniform> invalid: small_stride;

struct wrapped_f32 {
  @size(16) elem: f32
}
struct big_stride {
  a: array<wrapped_f32,8> // stride 16
}
@group(0) @binding(1) var<uniform> valid: big_stride;     // Valid
