@compute @workgroup_size(16,1,1)
fn main(@builtin(local_invocation_index) lid : u32) {
  for (var i = 0u; i < 10; i++) {
    workgroupBarrier();
    if (lid + i) > 7 {
      break;
    }
  }
}
