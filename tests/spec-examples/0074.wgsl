@vertex
fn vert_main() -> @builtin(position) vec4<f32> {
  return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}

@fragment
fn frag_main(@builtin(position) coord_in: vec4<f32>) -> @location(0) vec4<f32> {
  return vec4<f32>(coord_in.x, coord_in.y, 0.0, 1.0);
}

@compute @workgroup_size(1)
fn comp_main() { }
