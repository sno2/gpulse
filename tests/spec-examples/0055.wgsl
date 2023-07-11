@group(0) @binding(0)
var<storage, read_write> will_emit_color : u32;

fn discard_if_shallow(pos: vec4<f32>) {
  if pos.z < 0.001 {
    // If this is executed, then the will_emit_color variable will
    // never be set to 1 because helper invocations will not write
    // to shared memory.
    discard;
  }
  will_emit_color = 1;
}

@fragment
fn main(@builtin(position) coord_in: vec4<f32>)
  -> @location(0) vec4<f32>
{
  discard_if_shallow(coord_in);

  // Set the value to 1 and emit red, but only if the helper function
  // did not execute the discard statement.
  will_emit_color = 1;
  return vec4<f32>(1.0, 0.0, 0.0, 1.0);
}
