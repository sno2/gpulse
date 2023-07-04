@compute @workgroup_size(8,4,1)
fn sorter() { }

@compute @workgroup_size(8u)
fn reverser() { }

// Using an pipeline-overridable constant.
@id(42) override block_width = 12u;
@compute @workgroup_size(block_width)
fn shuffler() { }

// Error: workgroup_size must be specified on compute shader
@compute
fn bad_shader() { }
