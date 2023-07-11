@group(0) @binding(0) var<storage, read_write> a : i32;
@group(0) @binding(1) var<uniform> b : i32;

@compute @workgroup_size(16,1,1)
fn main() {
  var x : i32;
  x = a;
  if x > 0 {
    // Invalid barrier function call.
    workgroupBarrier();
  }
  x = b;
  if x < 0 {
    // Valid barrier function call.
    storageBarrier();
  }
}
