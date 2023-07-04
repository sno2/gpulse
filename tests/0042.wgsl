struct BufferContents {
    counter: atomic<u32>,
    data: array<vec4<f32>>
}
@group(0) @binding(0) var<storage> buf: BufferContents;
@group(0) @binding(1) var t: texture_2d<f32>;
@group(0) @binding(2) var s: sampler;

@fragment
fn shade_it() -> @location(0) vec4<f32> {
  // Declare that buf, t, and s are part of the shader interface, without
  // using them for anything.
  _ = &buf;
  _ = t;
  _ = s;
  return vec4<f32>();
}
