@compute @workgroup_size(16,1,1)
fn main(@builtin(workgroup_id) wgid : vec3<u32>,
        @builtin(local_invocation_index) lid : u32) {
  // The uniformity analysis can now correctly determine this comparison is
  // always uniform.
  if wgid.x == 1 {
    // Valid barrier function call.
    workgroupBarrier();
  }
}
