struct Inputs {
  // workgroup_id is a uniform built-in value.
  @builtin(workgroup_id) wgid : vec3<u32>,
  // local_invocation_index is a non-uniform built-in value.
  @builtin(local_invocation_index) lid : u32
}

@compute @workgroup_size(16,1,1)
fn main(inputs : Inputs) {
  // This comparison is always uniform,
  // but the analysis cannot determine that.
  if inputs.wgid.x == 1 {
    workgroupBarrier();
  }
}
