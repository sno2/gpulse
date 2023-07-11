@group(0) @binding(0) var t : texture_2d<f32>;
@group(0) @binding(1) var s : sampler;

@fragment
fn main(@builtin(position) pos : vec4<f32>) {
  if (pos.x < 0.5) {
    // Invalid textureSample function call.
    _ = textureSample(t, s, pos.xy);
  }
}
