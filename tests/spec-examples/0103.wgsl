@group(0) @binding(0) var dt: texture_depth_2d;
@group(0) @binding(1) var s: sampler;

fn gather_depth_compare(c: vec2<f32>, depth_ref: f32) -> vec4<f32> {
  return textureGatherCompare(dt,s,c,depth_ref);
}
