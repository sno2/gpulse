fn scale(in1 : f32, in2 : f32) -> f32 {
  let v = in1 / in2;
  return v;
}

@group(0) @binding(0) var t : texture_2d<f32>;
@group(0) @binding(1) var s : sampler;

@fragment
fn main(@builtin(position) pos : vec4<f32>) {
  let tmp = scale(pos.x, 0.5);
  if tmp > 1.0 {
    _ = textureSample(t, s, pos.xy);
  }
}
