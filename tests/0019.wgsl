// Runtime Array
alias RTArr = array<vec4<f32>>;
struct S {
  a: f32,
  b: f32,
  data: RTArr
}
@group(0) @binding(0) var<storage> buffer: S;
